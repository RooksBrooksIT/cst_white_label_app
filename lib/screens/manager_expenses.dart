import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class ManagerExpenses extends StatefulWidget {
  const ManagerExpenses({super.key});

  @override
  State<ManagerExpenses> createState() => _ManagerExpensesState();
}

class _ManagerExpensesState extends State<ManagerExpenses> {
  String? selectedSiteId;
  String? selectedProjectName;
  String? selectedSupervisorId;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingBills = false;
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  final supervisorIdController = TextEditingController();
  final projectPhaseController = TextEditingController();
  final projectNameController = TextEditingController();

  String? managerId;
  List<Map<String, String>> bills = [];
  List<Map<String, String>> initialBills = [];
  Map<String, String> siteNameMap = {};
  double existingDailyTotal = 0.0;

  /// Generation counter to prevent stale async responses from overwriting
  /// current data when the user switches sites quickly.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadManagerData();
    _loadSiteIds();
  }

  void _loadManagerData() {
    final userData = AuthService().userData;
    setState(() {
      managerId =
          userData['username'] ?? userData['UserName'] ?? 'UNKNOWN_MANAGER';
    });
  }

  @override
  void dispose() {
    billNoController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorIdController.dispose();
    projectPhaseController.dispose();
    projectNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteIds() async {
    setState(() => isLoadingSites = true);
    try {
      // 1. Fetch site names from the master Site collection
      final sitesSnapshot = await FirestoreService.sites.get();
      final Map<String, String> names = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };

      final fetchedSiteIds = sitesSnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .toList();

      setState(() {
        siteNameMap = names;
        siteIds = fetchedSiteIds..sort();
        isLoadingSites = false;

        // Auto-select if only one site ID exists
        if (siteIds.length == 1) {
          selectedSiteId = siteIds.first;
          _loadSiteDetails(selectedSiteId!);
          // Don't load existing expenses — bill list starts empty
        }
      });
    } catch (e) {
      debugPrint('Error loading site IDs: $e');
      setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    String? supervisorId;
    String? projectPhase;
    String? projectName;

    try {
      // 1. Try to fetch from siteSupervisorMap (by document ID first, then by field)
      final docRef = FirestoreService.siteSupervisorMap.doc(siteId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        supervisorId = data['supervisor']?.toString();
        projectPhase = data['projectStage']?.toString();
        projectName = (data['projectName'] ?? data['project_name'])?.toString();
      } else {
        // Fallback: search by 'site' field
        final mapSnapshot = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: siteId)
            .limit(1)
            .get();
        if (mapSnapshot.docs.isNotEmpty) {
          final data = mapSnapshot.docs.first.data();
          supervisorId = data['supervisor']?.toString();
          projectPhase = data['projectStage']?.toString();
          projectName = (data['projectName'] ?? data['project_name'])
              ?.toString();
        }
      }

      // 2. Fetch from projects collection (high priority for name)
      final projectSnapshot = await FirestoreService.projects
          .where('siteId', isEqualTo: siteId.trim())
          .limit(1)
          .get();

      if (projectSnapshot.docs.isNotEmpty) {
        final pData = projectSnapshot.docs.first.data();
        final pName = pData['projectName']?.toString();
        if (pName != null && pName.trim().isNotEmpty) {
          projectName = pName;
        }
        // Also get phase if missing
        if (projectPhase == null || projectPhase.isEmpty) {
          projectPhase = (pData['projectStage'] ?? pData['status'])?.toString();
        }
      }

      // 3. Last fallback to Site Name from master list
      if (projectName == null || projectName.trim().isEmpty) {
        projectName = siteNameMap[siteId] ?? 'Project $siteId';
      }

      if (!mounted) return;
      setState(() {
        selectedSupervisorId = supervisorId;
        selectedProjectPhase = projectPhase;
        selectedProjectName = projectName;

        supervisorIdController.text = supervisorId ?? 'Not Assigned';
        projectPhaseController.text = projectPhase ?? 'N/A';
        projectNameController.text = projectName ?? 'Unknown Project';
      });
    } catch (e) {
      debugPrint('Error loading site details: $e');
      if (mounted) {
        setState(() {
          projectNameController.text = siteNameMap[siteId] ?? siteId;
        });
      }
    }
  }

  Future<void> _loadExistingExpenses() async {
    if (selectedSiteId == null) return;

    // Increment generation so any in-flight request from a previous site
    // selection will be discarded when it completes.
    final thisGeneration = ++_loadGeneration;

    setState(() {
      isLoadingBills = true;
      // Clear immediately so stale data is never visible
      bills = [];
      initialBills = [];
      existingDailyTotal = 0.0;
    });

    final formattedDate = DateFormat('ddMMyyyy').format(selectedDate);
    final docId = '${selectedSiteId}_$formattedDate';

    try {
      final docSnap = await FirestoreService.managerExpenses.doc(docId).get();

      // If the user switched site while we were fetching, discard this result.
      if (!mounted || _loadGeneration != thisGeneration) return;

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data['bills'] != null) {
          final List<dynamic> loadedBills = data['bills'];
          double loadedTotal = 0.0;
          for (var bill in loadedBills) {
            final amountStr = bill['billAmount'] ?? '0';
            final parsed =
                double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ??
                0.0;
            loadedTotal += parsed;
          }
          setState(() {
            bills = loadedBills
                .map((b) => Map<String, String>.from(b))
                .toList();
            initialBills = loadedBills
                .map((b) => Map<String, String>.from(b))
                .toList();
            existingDailyTotal = loadedTotal;
          });
        }
      }
      // If no document exists, bills stay empty (already cleared above)
    } catch (e) {
      debugPrint('Error loading existing expenses: $e');
    } finally {
      if (mounted && _loadGeneration == thisGeneration) {
        setState(() => isLoadingBills = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadExistingExpenses();
    }
  }

  void _addBill() {
    if (billNoController.text.isNotEmpty &&
        billVendorController.text.isNotEmpty &&
        billAmountController.text.isNotEmpty) {
      setState(() {
        bills.add({
          'billNo': billNoController.text,
          'billDate': DateFormat('dd/MM/yy').format(selectedDate),
          'billVendor': billVendorController.text,
          'billAmount': '₹ ${billAmountController.text}',
        });
        billNoController.clear();
        billVendorController.clear();
        billAmountController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Manager Expenses',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoSection(theme),
            const SizedBox(height: 24),
            _buildBillFormSection(theme),
            const SizedBox(height: 24),
            _buildBillsListSection(theme),
            const SizedBox(height: 32),
            GlassButton(
              label: 'SUBMIT EXPENSES',
              onPressed: isSubmitting || bills.isEmpty ? null : _handleSubmit,
              isLoading: isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Site & Project Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          isLoadingSites
              ? const LinearProgressIndicator()
              : _buildDropdown('Select Site ID', siteIds, selectedSiteId, (v) {
                  setState(() {
                    selectedSiteId = v;
                    // Clear site detail fields immediately
                    selectedSupervisorId = null;
                    selectedProjectPhase = null;
                    selectedProjectName = null;
                    supervisorIdController.clear();
                    projectPhaseController.clear();
                    projectNameController.clear();
                    // Reset bill list — start fresh for new site
                    bills = [];
                    initialBills = [];
                    existingDailyTotal = 0.0;
                  });
                  if (v != null) {
                    _loadSiteDetails(v);
                    // Don't auto-load existing expenses;
                    // bill list starts empty for new entry session
                  }
                }),
          const SizedBox(height: 12),
          GlassTextField(
            controller: supervisorIdController,
            label: 'Supervisor ID',
            icon: Icons.person_outline,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: projectPhaseController,
            label: 'Project Phase',
            icon: Icons.timeline_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: projectNameController,
            label: 'Project Name',
            icon: Icons.assignment_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(theme),
        ],
      ),
    );
  }

  Widget _buildBillFormSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Bill',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GlassTextField(
            controller: billNoController,
            label: 'Bill Number',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: billVendorController,
            label: 'Vendor Name',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: billAmountController,
            label: 'Amount (₹)',
            icon: Icons.currency_rupee_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: GlassButton(
              label: 'ADD BILL',
              onPressed: _addBill,
              isSecondary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsListSection(ThemeData theme) {
    if (isLoadingBills) {
      return const GlassCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (bills.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bills List',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 0,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Bill No')),
                DataColumn(label: Text('Vendor')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Action')),
              ],
              rows: bills
                  .asMap()
                  .entries
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text(entry.value['billNo']!)),
                        DataCell(Text(entry.value['billVendor']!)),
                        DataCell(Text(entry.value['billAmount']!)),
                        DataCell(
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => bills.removeAt(entry.key)),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(
          Icons.location_on_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: theme.cardColor,
      ),
      dropdownColor: theme.cardColor,
      style: TextStyle(color: colorScheme.onSurface),
      items: items.map((id) {
        final name = siteNameMap[id] ?? 'Unnamed Site';
        return DropdownMenuItem(
          value: id,
          child: Text(
            '$id - $name',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          filled: true,
          fillColor: theme.cardColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(selectedDate),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            Icon(
              Icons.edit_calendar_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (selectedSiteId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Site and Project')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final formattedDate = DateFormat('ddMMyyyy').format(selectedDate);
      final docId = '${selectedSiteId}_$formattedDate';

      // 1. Fetch existing bills from Firestore to merge and preserve other fields if needed
      final docSnap = await FirestoreService.managerExpenses.doc(docId).get();
      List<Map<String, String>> mergedBills = [];
      List<Map<String, String>> newBills = [];

      final Map<String, dynamic> docData = {
        'expenseId': docId,
        'managerId': managerId ?? 'UNKNOWN_MANAGER',
        'siteId': selectedSiteId,
        'projectName': selectedProjectName,
        'date': DateFormat('dd/MM/yy').format(selectedDate),
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (docSnap.exists) {
        final existingData = docSnap.data();
        if (existingData != null) {
          if (existingData['bills'] != null) {
            final List<dynamic> dbBills = existingData['bills'];
            mergedBills = dbBills
                .map((b) => Map<String, String>.from(b))
                .toList();
          }
          docData['status'] = existingData['status'] ?? 'Pending';
          if (existingData['timestamp'] != null) {
            docData['timestamp'] = existingData['timestamp'];
          }
        }

        // Identify new bills not present in the initially loaded list
        for (final bill in bills) {
          final isExisting = initialBills.any(
            (b) =>
                b['billNo'] == bill['billNo'] &&
                b['billVendor'] == bill['billVendor'] &&
                b['billAmount'] == bill['billAmount'],
          );
          if (!isExisting) {
            newBills.add(bill);
          }
        }
        mergedBills.addAll(newBills);
      } else {
        mergedBills = List<Map<String, String>>.from(bills);
        newBills = List<Map<String, String>>.from(bills);
      }

      docData['bills'] = mergedBills;

      // Robustly calculate the sum total of all bills inside the list
      double totalAmount = 0.0;
      for (var bill in mergedBills) {
        final amountStr = bill['billAmount'] ?? '0';
        final parsed =
            double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        totalAmount += parsed;
      }

      // Calculate increment from new bills only
      double increment = 0.0;
      for (var bill in newBills) {
        final amountStr = bill['billAmount'] ?? '0';
        final parsed =
            double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        increment += parsed;
      }

      // 2. Save manager expense document
      await FirestoreService.managerExpenses.doc(docId).set(docData);

      // 3. Save corresponding summary in managerExpenseSummary
      final summary = {
        'date': selectedDate.toIso8601String(),
        'mgrExpenseTotalAmount': totalAmount,
        'projectName': selectedProjectName,
        'projectStage': selectedProjectPhase ?? '',
        'siteId': selectedSiteId ?? '',
      };
      await FirestoreService.managerExpenseSummary.doc(docId).set(summary);

      // 4. Atomically update totalMgrExpense and totalAllExpenses in totalSiteExpensesPerDay collection
      try {
        final totalsRef = FirestoreService.getCollection(
          'totalSiteExpensesPerDay',
        ).doc(selectedSiteId!);
        await FirebaseFirestore.instance.runTransaction((txn) async {
          final snap = await txn.get(totalsRef);
          double existingMgr = 0.0;
          double existingAll = 0.0;
          if (snap.exists) {
            final Map<String, dynamic>? d = snap.data();
            if (d != null) {
              final v1 = d['totalMgrExpense'];
              final v2 = d['totalAllExpenses'];
              if (v1 is num) existingMgr = v1.toDouble();
              if (v2 is num) existingAll = v2.toDouble();
            }
          }
          txn.set(totalsRef, {
            'siteId': selectedSiteId,
            'totalMgrExpense': existingMgr + increment,
            'totalAllExpenses': existingAll + increment,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      } catch (e) {
        debugPrint('Failed to increment totals: $e');
      }

      // 5. Update totalMgrExpense in totalSiteExpensesPerDay and sync project document
      await ExpenseService.updateTotalMgrExpenseForSite(selectedSiteId!);

      if (mounted) {
        setState(() {
          bills = [];
          initialBills = [];
          existingDailyTotal = 0.0;
          billNoController.clear();
          billVendorController.clear();
          billAmountController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expenses submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
