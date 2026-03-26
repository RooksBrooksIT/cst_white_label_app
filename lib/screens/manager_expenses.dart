import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
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
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  List<Map<String, String>> bills = [];

  @override
  void initState() {
    super.initState();
    _loadSiteIds();
  }

  Future<void> _loadSiteIds() async {
    setState(() => isLoadingSites = true);
    try {
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      setState(() {
        siteIds = snapshot.docs
            .map((doc) => doc.data()['site'] as String?)
            .where((site) => site != null && site.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();
        isLoadingSites = false;
      });
    } catch (e) {
      setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    setState(() => isLoadingSiteDetails = true);
    try {
      final snapshot = await FirestoreService.siteSupervisorMap
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          selectedSupervisorId = data['supervisor'] as String?;
          selectedProjectPhase = data['projectStage'] as String?;
          selectedProjectName = data['projectName'] as String?;
        });
      }
    } finally {
      setState(() => isLoadingSiteDetails = false);
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
    return GlassScaffold(
      title: 'Manager Expenses',
      onBack: () => Navigator.pop(context),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoSection(context),
          const SizedBox(height: 24),
          _buildBillSection(context),
          const SizedBox(height: 24),
          _buildBillsListSection(context),
          const SizedBox(height: 32),
          _buildSubmitButton(context),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return GlassCard(
      title: 'Site & Project Info',
      child: Column(
        children: [
          isLoadingSites
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown('Site ID', siteIds, selectedSiteId, (value) {
                  setState(() => selectedSiteId = value);
                  if (value != null) _loadSiteDetails(value);
                }),
          const SizedBox(height: 16),
          _buildReadOnlyField('Supervisor ID', selectedSupervisorId ?? ''),
          const SizedBox(height: 16),
          _buildReadOnlyField('Project Phase', selectedProjectPhase ?? ''),
          const SizedBox(height: 16),
          _buildDatePicker(context),
        ],
      ),
    );
  }

  Widget _buildBillSection(BuildContext context) {
    return GlassCard(
      title: 'Add Bill',
      child: Column(
        children: [
          _buildLabeledTextField('Bill No', billNoController),
          _buildReadOnlyField('Bill Date', DateFormat('dd/MM/yy').format(selectedDate)),
          _buildLabeledTextField('Bill Vendor', billVendorController),
          _buildLabeledTextField('Bill Amount', billAmountController),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _addBill,
                icon: const Icon(Icons.add),
                label: const Text('Add Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillsListSection(BuildContext context) {
    return GlassCard(
      title: 'Bills List',
      child: _buildBillTable(),
    );
  }

  Widget _buildBillTable() {
    if (bills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No bills added yet.', style: TextStyle(color: Colors.white54)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Bill No', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('Bill Date', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('Bill Vendor', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('Delete', style: TextStyle(color: Colors.white70))),
        ],
        rows: bills.asMap().entries.map((entry) => DataRow(
          cells: [
            DataCell(Text(entry.value['billNo']!, style: const TextStyle(color: Colors.white))),
            DataCell(Text(entry.value['billDate']!, style: const TextStyle(color: Colors.white))),
            DataCell(Text(entry.value['billVendor']!, style: const TextStyle(color: Colors.white))),
            DataCell(Text(entry.value['billAmount']!, style: const TextStyle(color: Colors.white))),
            DataCell(IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
              onPressed: () => setState(() => bills.removeAt(entry.key)),
            )),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isSubmitting
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Submit Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1A1F2E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
    );
  }

  Widget _buildLabeledTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: _inputDecoration('Date'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd/MM/yy').format(selectedDate), style: const TextStyle(color: Colors.white)),
            const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
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
        'managerId': 'TODO_MANAGER_ID',
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
