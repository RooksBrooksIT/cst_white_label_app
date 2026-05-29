import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
  String? selectedSupervisorName;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingBills = false;
  bool isSubmitting = false;
  bool isUploadingImage = false;

  final billNoController = TextEditingController();
  final billDateController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  final supervisorIdController = TextEditingController();
  final projectPhaseController = TextEditingController();
  final projectNameController = TextEditingController();

  String? managerId;
  List<Map<String, dynamic>> bills = [];
  List<Map<String, dynamic>> initialBills = [];
  Map<String, String> siteNameMap = {};
  double existingDailyTotal = 0.0;
  File? _selectedBillImage;
  final ImagePicker _picker = ImagePicker();

  /// Generation counter to prevent stale async responses from overwriting
  /// current data when the user switches sites quickly.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadManagerData();
    _loadSiteIds();
    billDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
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
    billDateController.dispose();
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
    String? supervisorName;
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

      // 1.5 Fetch supervisor name if supervisorId exists
      if (supervisorId != null && supervisorId.isNotEmpty) {
        final supervisorSnap = await FirestoreService.supervisors
            .doc(supervisorId)
            .get();
        if (supervisorSnap.exists) {
          final sData = supervisorSnap.data();
          supervisorName =
              sData?['supervisorName']?.toString() ??
              sData?['name']?.toString() ??
              supervisorId;
        } else {
          supervisorName = supervisorId;
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
        selectedSupervisorName = supervisorName;
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
        if (data != null) {
          if (data['bills'] != null) {
            final List<dynamic> loadedBills = data['bills'];
            double loadedTotal = 0.0;
            for (var bill in loadedBills) {
              final amount = bill['billAmount'];
              double parsed = 0.0;
              if (amount is num) {
                parsed = amount.toDouble();
              } else if (amount is String) {
                parsed =
                    double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ??
                    0.0;
              }
              loadedTotal += parsed;
            }
            setState(() {
              bills = loadedBills
                  .map((b) => Map<String, dynamic>.from(b))
                  .toList();
              initialBills = loadedBills
                  .map((b) => Map<String, dynamic>.from(b))
                  .toList();
              existingDailyTotal = loadedTotal;
            });
          } else if (data['totalAmount'] != null) {
            // Document exists but no bills array, use top-level total
            final amount = data['totalAmount'];
            if (amount is num) {
              existingDailyTotal = amount.toDouble();
            }
          }
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
      setState(() {
        selectedDate = picked;
        billDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _loadExistingExpenses();
    }
  }

  Future<void> _pickBillImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _selectedBillImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadBillImage(File image, String billNo) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('organisation')
          .child(FirestoreService.currentOrgId)
          .child('expenses')
          .child(
            '${selectedSiteId}_${DateFormat('ddMMyyyy').format(selectedDate)}',
          )
          .child('bill_$billNo.jpg');

      final uploadTask = await storageRef.putFile(image);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addBill() async {
    if (billNoController.text.isEmpty ||
        billVendorController.text.isEmpty ||
        billAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all bill fields')),
      );
      return;
    }

    if (selectedSiteId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select Site first')));
      return;
    }

    setState(() => isUploadingImage = true);

    try {
      String billUrl = "billURL"; // Default as per user's structure
      if (_selectedBillImage != null) {
        final uploadedUrl = await _uploadBillImage(
          _selectedBillImage!,
          billNoController.text,
        );
        if (uploadedUrl != null) {
          billUrl = uploadedUrl;
        }
      }

      final amount = double.tryParse(billAmountController.text) ?? 0.0;

      setState(() {
        bills.add({
          'billAmount': amount,
          'billCopy': billUrl,
          'billDate': Timestamp.fromDate(selectedDate),
          'billNo': billNoController.text,
          'billVendor': billVendorController.text,
        });

        billNoController.clear();
        billVendorController.clear();
        billAmountController.clear();
        _selectedBillImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding bill: $e')));
    } finally {
      setState(() => isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Manager Expenses',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
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
            label: 'Supervisor',
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
          _buildImagePicker(theme),
          const SizedBox(height: 12),
          GlassTextField(
            controller: billNoController,
            label: 'Bill Number',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: billDateController,
            label: 'Bill Date',
            icon: Icons.calendar_today_outlined,
            readOnly: true,
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
              onPressed: isUploadingImage ? null : _addBill,
              isLoading: isUploadingImage,
              isSecondary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: _pickBillImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: _selectedBillImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedBillImage!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () =>
                              setState(() => _selectedBillImage = null),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload Bill Copy (Optional)',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
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
              rows: bills.asMap().entries.map((entry) {
                final bill = entry.value;
                final amount = bill['billAmount'];
                String amountStr = '0.00';
                if (amount is num) {
                  amountStr = amount.toStringAsFixed(2);
                } else if (amount is String) {
                  amountStr = amount.replaceAll(RegExp(r'[^\d.]'), '');
                }

                return DataRow(
                  cells: [
                    DataCell(Text(bill['billNo']?.toString() ?? '')),
                    DataCell(Text(bill['billVendor']?.toString() ?? '')),
                    DataCell(Text('₹ $amountStr')),
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
                );
              }).toList(),
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
      isExpanded: true,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select Site')));
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final formattedDate = DateFormat('ddMMyyyy').format(selectedDate);
      final docId = '${selectedSiteId}_$formattedDate';

      // 1. Fetch existing bills from Firestore to merge and preserve other fields if needed
      final docSnap = await FirestoreService.managerExpenses.doc(docId).get();
      List<Map<String, dynamic>> mergedBills = [];
      List<Map<String, dynamic>> newBills = [];

      final Map<String, dynamic> docData = {
        'siteId': selectedSiteId,
        'projectName': selectedProjectName,
        'projectStage': selectedProjectPhase ?? 'N/A',
        'supervisorName': selectedSupervisorName ?? managerId ?? 'demo',
        'entryDate': Timestamp.now(),
        'totalAmount': 0.0, // Will be updated below
        'expenseId': docId,
        'managerId': managerId ?? 'UNKNOWN_MANAGER',
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (docSnap.exists) {
        final existingData = docSnap.data();
        if (existingData != null) {
          if (existingData['bills'] != null) {
            final List<dynamic> dbBills = existingData['bills'];
            mergedBills = dbBills
                .map((b) => Map<String, dynamic>.from(b))
                .toList();
          }
          docData['status'] = existingData['status'] ?? 'Pending';
          docData['entryDate'] =
              existingData['entryDate'] ?? docData['entryDate'];
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
        mergedBills = List<Map<String, dynamic>>.from(bills);
        newBills = List<Map<String, dynamic>>.from(bills);
      }

      docData['bills'] = mergedBills;

      // Robustly calculate the sum total of all bills inside the list
      double totalAmount = 0.0;
      for (var bill in mergedBills) {
        final amount = bill['billAmount'];
        if (amount is num) {
          totalAmount += amount.toDouble();
        } else if (amount is String) {
          totalAmount +=
              double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        }
      }
      docData['totalAmount'] = totalAmount;

      // Calculate increment from new bills only
      double increment = 0.0;
      for (var bill in newBills) {
        final amount = bill['billAmount'];
        if (amount is num) {
          increment += amount.toDouble();
        } else if (amount is String) {
          increment +=
              double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
