import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
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
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  final supervisorIdController = TextEditingController();
  final projectPhaseController = TextEditingController();
  final projectNameController = TextEditingController();

  String? managerId;
  List<Map<String, String>> bills = [];
  Map<String, String> siteNameMap = {};

  @override
  void initState() {
    super.initState();
    _loadManagerData();
    _loadSiteIds();
  }

  void _loadManagerData() {
    final userData = AuthService().userData;
    setState(() {
      managerId = userData['username'] ?? userData['UserName'] ?? 'UNKNOWN_MANAGER';
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
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site'
      };

      // 2. Fetch sites from mapping
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      final fetchedSiteIds = snapshot.docs
          .map((doc) => doc.data()['site'] as String?)
          .where((site) => site != null && site.isNotEmpty)
          .toSet()
          .cast<String>()
          .toList();

      setState(() {
        siteNameMap = names;
        siteIds = fetchedSiteIds;
        isLoadingSites = false;

        // Auto-select if only one site ID exists
        if (siteIds.length == 1) {
          selectedSiteId = siteIds.first;
          _loadSiteDetails(selectedSiteId!);
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
          projectName = (data['projectName'] ?? data['project_name'])?.toString();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
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
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: colorScheme.onPrimary,
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
          Text('Site & Project Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          isLoadingSites
              ? const LinearProgressIndicator()
              : _buildDropdown('Select Site ID', siteIds, selectedSiteId, (v) {
                  setState(() => selectedSiteId = v);
                  if (v != null) _loadSiteDetails(v);
                }),
          const SizedBox(height: 12),
          GlassTextField(controller: supervisorIdController, label: 'Supervisor ID', icon: Icons.person_outline, readOnly: true),
          const SizedBox(height: 12),
          GlassTextField(controller: projectPhaseController, label: 'Project Phase', icon: Icons.timeline_outlined, readOnly: true),
          const SizedBox(height: 12),
          GlassTextField(controller: projectNameController, label: 'Project Name', icon: Icons.assignment_outlined, readOnly: true),
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
          Text('Add Bill', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GlassTextField(controller: billNoController, label: 'Bill Number', icon: Icons.receipt_long_outlined),
          const SizedBox(height: 12),
          GlassTextField(controller: billVendorController, label: 'Vendor Name', icon: Icons.storefront_outlined),
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
    if (bills.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bills List', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              rows: bills.asMap().entries.map((entry) => DataRow(
                cells: [
                  DataCell(Text(entry.value['billNo']!)),
                  DataCell(Text(entry.value['billVendor']!)),
                  DataCell(Text(entry.value['billAmount']!)),
                  DataCell(IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                    onPressed: () => setState(() => bills.removeAt(entry.key)),
                  )),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: colorScheme.primary),
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
          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20, color: colorScheme.primary),
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
            Icon(Icons.edit_calendar_outlined, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (selectedSiteId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Site and Project')));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final docId = 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      await FirestoreService.managerExpenses.doc(docId).set({
        'expenseId': docId,
        'managerId': managerId ?? 'UNKNOWN_MANAGER',
        'siteId': selectedSiteId,
        'projectName': selectedProjectName,
        'date': DateFormat('dd/MM/yy').format(selectedDate),
        'bills': bills,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expenses submitted successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
