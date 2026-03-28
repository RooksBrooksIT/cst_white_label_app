import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class ManagerSiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  const ManagerSiteEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<ManagerSiteEntryPage> createState() => _ManagerSiteEntryPageState();
}

class _ManagerSiteEntryPageState extends State<ManagerSiteEntryPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> labours = [];
  String? selectedMaterial;
  final materialQtyController = TextEditingController(text: '0');
  String? selectedLabour;
  final labourQtyController = TextEditingController(text: '0');
  final foodCost = TextEditingController(text: '0');
  final transportCost = TextEditingController(text: '0');
  final fuelCost = TextEditingController(text: '0');
  DateTime? selectedDate = DateTime.now();
  List<String> materialOptions = [];
  List<String> labourOptions = [];
  bool isLoadingMaterials = true;
  bool isLoadingLabours = true;
  String? supervisorId;
  String siteCode = '';
  List<Map<String, String>> siteList = [];
  String? selectedSiteId;
  String? supervisorName;
  String? siteLocation;
  String? projectStage;
  bool isLoadingSites = true;
  bool isSaving = false;
  Map<String, num> materialPrices = {};
  Map<String, num> labourSalaries = {};

  bool _showCustomMaterialFields = false;
  final _customMaterialNameController = TextEditingController();
  final _customMaterialQtyController = TextEditingController(text: '0');
  final _customMaterialPriceController = TextEditingController(text: '0');

  bool _showCustomLabourFields = false;
  final _customLabourNameController = TextEditingController();
  final _customLabourSalaryController = TextEditingController(text: '0');

  bool isUpdateMode = false;
  String? _updateDocId;

  @override
  void initState() {
    super.initState();
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSites();
  }

  @override
  void dispose() {
    materialQtyController.dispose();
    labourQtyController.dispose();
    foodCost.dispose();
    transportCost.dispose();
    fuelCost.dispose();
    _customMaterialNameController.dispose();
    _customMaterialQtyController.dispose();
    _customMaterialPriceController.dispose();
    _customLabourNameController.dispose();
    _customLabourSalaryController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    setState(() => isLoadingSites = true);
    try {
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      siteList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'siteId': data['site']?.toString() ?? '',
          'supervisor': data['supervisor']?.toString() ?? '',
          'supervisorId': data['Supervisor ID']?.toString() ?? '',
          'location': data['location']?.toString() ?? '',
          'projectStage': data['projectStage']?.toString() ?? '',
        };
      }).where((site) => site['siteId']!.isNotEmpty).toList();

      if (siteList.isNotEmpty && selectedSiteId == null) {
        selectedSiteId = siteList.first['siteId'];
        _onSiteSelected(selectedSiteId!);
      }
    } finally {
      setState(() => isLoadingSites = false);
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere((s) => s['siteId'] == siteId, orElse: () => {'siteId': '', 'supervisor': '', 'supervisorId': '', 'location': '', 'projectStage': ''});
    setState(() {
      selectedSiteId = siteId;
      siteCode = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId']?.isNotEmpty == true ? site['supervisorId'] : 'N/A';
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      isUpdateMode = false;
      _updateDocId = null;
    });
  }

  Future<void> _fetchMaterialOptions() async {
    setState(() => isLoadingMaterials = true);
    try {
      final snapshot = await FirestoreService.getCollection('materials').get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['materialName']?.toString();
        if (name != null) {
          options.add(name);
          prices[name] = num.tryParse(data['materialPrice']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0') ?? 0;
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial = options.isNotEmpty ? options.first : null;
      });
    } finally {
      setState(() => isLoadingMaterials = false);
    }
  }

  Future<void> _fetchLabourOptions() async {
    setState(() => isLoadingLabours = true);
    try {
      final snapshot = await FirestoreService.getCollection('labours').get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final des = data['designation']?.toString();
        if (des != null) {
          options.add(des);
          salaries[des] = num.tryParse(data['salary']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0') ?? 0;
        }
      }
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        selectedLabour = options.isNotEmpty ? options.first : null;
      });
    } finally {
      setState(() => isLoadingLabours = false);
    }
  }

  void _addMaterial() {
    int qty = int.tryParse(materialQtyController.text) ?? 0;
    if (selectedMaterial != null && qty > 0) {
      setState(() {
        materials.add({'type': selectedMaterial!, 'quantity': qty});
        materialQtyController.text = '0';
      });
    }
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(_customMaterialPriceController.text) ?? 0;
    if (name.isNotEmpty && qty > 0) {
      setState(() {
        materials.add({'type': name, 'quantity': qty});
        materialPrices[name] = price;
        _showCustomMaterialFields = false;
        _customMaterialNameController.clear();
        _customMaterialQtyController.text = '0';
        _customMaterialPriceController.text = '0';
      });
    }
  }

  void _addLabour() {
    int qty = int.tryParse(labourQtyController.text) ?? 0;
    if (selectedLabour != null && qty > 0) {
      setState(() {
        labours.add({'type': selectedLabour!, 'count': qty});
        labourQtyController.text = '0';
      });
    }
  }

  void _addCustomLabour() {
    final name = _customLabourNameController.text.trim();
    final qty = int.tryParse(labourQtyController.text) ?? 0;
    final salary = num.tryParse(_customLabourSalaryController.text) ?? 0;
    if (name.isNotEmpty && qty > 0) {
      setState(() {
        labours.add({'type': name, 'count': qty});
        labourSalaries[name] = salary;
        _showCustomLabourFields = false;
        _customLabourNameController.clear();
        labourQtyController.text = '0';
        _customLabourSalaryController.text = '0';
      });
    }
  }

  int _getTotalAmount() {
    num total = 0;
    for (var m in materials) total += (materialPrices[m['type']] ?? 0) * (m['quantity'] ?? 0);
    for (var l in labours) total += (labourSalaries[l['type']] ?? 0) * (l['count'] ?? 0);
    total += int.tryParse(foodCost.text) ?? 0;
    total += int.tryParse(transportCost.text) ?? 0;
    total += int.tryParse(fuelCost.text) ?? 0;
    return total.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: isUpdateMode ? 'Update Site Entry' : 'Daily Site Entry',
      actions: [
        IconButton(icon: const Icon(Icons.history_outlined), onPressed: _openHistory),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            _buildSiteInfoSection(theme),
            const SizedBox(height: 16),
            _buildMaterialSection(theme),
            const SizedBox(height: 16),
            _buildLabourSection(theme),
            const SizedBox(height: 16),
            _buildMiscSection(theme),
            const SizedBox(height: 16),
            _buildSummarySection(theme),
            const SizedBox(height: 32),
            GlassButton(
              label: isUpdateMode ? 'UPDATE ENTRY' : 'SAVE ENTRY',
              onPressed: isSaving ? null : (isUpdateMode ? _updateEntry : _saveEntry),
              isLoading: isSaving,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteInfoSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Site Selection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDropdown('Select Site', siteList.map((s) => s['siteId']!).toList(), selectedSiteId, (v) => _onSiteSelected(v!)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(child: Text(supervisorName ?? 'Select Site', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(siteLocation ?? 'N/A', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Materials', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => setState(() => _showCustomMaterialFields = !_showCustomMaterialFields),
                icon: Icon(_showCustomMaterialFields ? Icons.list_alt : Icons.add_circle_outline, color: theme.primaryColor),
                tooltip: _showCustomMaterialFields ? 'Show Standard' : 'Add Custom',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showCustomMaterialFields) ...[
            GlassTextField(controller: _customMaterialNameController, label: 'Material Name', icon: Icons.edit_note),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GlassTextField(controller: _customMaterialQtyController, label: 'Qty', icon: Icons.numbers, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: GlassTextField(controller: _customMaterialPriceController, label: 'Price', icon: Icons.currency_rupee, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: _addCustomMaterial, icon: const Icon(Icons.add)),
              ],
            ),
          ] else ...[
            _buildDropdown('Select Material', materialOptions, selectedMaterial, (v) => setState(() => selectedMaterial = v)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GlassTextField(controller: materialQtyController, label: 'Quantity', icon: Icons.numbers, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                GlassButton(label: 'ADD', onPressed: _addMaterial, isSecondary: true),
              ],
            ),
          ],
          if (materials.isNotEmpty) _buildAddedList(materials, 'quantity', materialPrices, theme, (i) => setState(() => materials.removeAt(i))),
        ],
      ),
    );
  }

  Widget _buildLabourSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Labour', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => setState(() => _showCustomLabourFields = !_showCustomLabourFields),
                icon: Icon(_showCustomLabourFields ? Icons.list_alt : Icons.person_add_alt_1_outlined, color: theme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showCustomLabourFields) ...[
            GlassTextField(controller: _customLabourNameController, label: 'Designation', icon: Icons.engineering_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GlassTextField(controller: labourQtyController, label: 'Count', icon: Icons.groups_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: GlassTextField(controller: _customLabourSalaryController, label: 'Salary', icon: Icons.payments_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: _addCustomLabour, icon: const Icon(Icons.add)),
              ],
            ),
          ] else ...[
            _buildDropdown('Designation', labourOptions, selectedLabour, (v) => setState(() => selectedLabour = v)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GlassTextField(controller: labourQtyController, label: 'Count', icon: Icons.groups_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                GlassButton(label: 'ADD', onPressed: _addLabour, isSecondary: true),
              ],
            ),
          ],
          if (labours.isNotEmpty) _buildAddedList(labours, 'count', labourSalaries, theme, (i) => setState(() => labours.removeAt(i))),
        ],
      ),
    );
  }

  Widget _buildMiscSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Other Expenses', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: GlassTextField(controller: foodCost, label: 'Food', icon: Icons.restaurant, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: GlassTextField(controller: transportCost, label: 'Travel', icon: Icons.local_shipping, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          GlassTextField(controller: fuelCost, label: 'Fuel Cost', icon: Icons.local_gas_station, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Daily Cost', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('₹ ${_getTotalAmount()}', style: theme.textTheme.headlineSmall?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAddedList(List<Map<String, dynamic>> items, String qtyKey, Map<String, num> priceMap, ThemeData theme, Function(int) onRemove) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final price = priceMap[item['type']] ?? 0;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item['type'], style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text('${item[qtyKey]} units @ ₹$price'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${(item[qtyKey] * price).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error, size: 20), onPressed: () => onRemove(i)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.cardColor,
      ),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _saveEntry() async {
    if (siteCode.isEmpty || selectedDate == null) return;
    setState(() => isSaving = true);
    try {
      final dateId = DateFormat('ddMMyyyy').format(selectedDate!);
      final docId = '${siteCode}_$dateId';
      await FirestoreService.siteSupervisorEntries.doc(docId).set({
        "date": selectedDate!.toIso8601String(),
        "food": int.tryParse(foodCost.text) ?? 0,
        "fuel": int.tryParse(fuelCost.text) ?? 0,
        "labours": labours.map((l) => {"type": l['type'], "count": l['count'], "unitSalary": labourSalaries[l['type']] ?? 0, "amount": (labourSalaries[l['type']] ?? 0) * (l['count'] ?? 0)}).toList(),
        "materials": materials.map((m) => {"type": m['type'], "quantity": m['quantity'], "unitPrice": materialPrices[m['type']] ?? 0, "amount": (materialPrices[m['type']] ?? 0) * (m['quantity'] ?? 0)}).toList(),
        "Supervisor ID": supervisorId,
        "transport": int.tryParse(transportCost.text) ?? 0,
        "totalAmount": _getTotalAmount(),
        "siteId": siteCode,
        "supervisorName": supervisorName,
        "projectStage": projectStage,
      });
      await ExpenseService.updateTotalSiteExpense(siteCode);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully'), backgroundColor: Colors.green));
      _resetForm();
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _updateEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);
    try {
      await FirestoreService.siteSupervisorEntries.doc(_updateDocId).update({
        "food": int.tryParse(foodCost.text) ?? 0,
        "fuel": int.tryParse(fuelCost.text) ?? 0,
        "labours": labours.map((l) => {"type": l['type'], "count": l['count'], "unitSalary": labourSalaries[l['type']] ?? 0, "amount": (labourSalaries[l['type']] ?? 0) * (l['count'] ?? 0)}).toList(),
        "materials": materials.map((m) => {"type": m['type'], "quantity": m['quantity'], "unitPrice": materialPrices[m['type']] ?? 0, "amount": (materialPrices[m['type']] ?? 0) * (m['quantity'] ?? 0)}).toList(),
        "transport": int.tryParse(transportCost.text) ?? 0,
        "totalAmount": _getTotalAmount(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully'), backgroundColor: Colors.green));
      _resetForm();
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      isUpdateMode = false;
      _updateDocId = null;
    });
  }

  void _openHistory() async {
    final query = await FirestoreService.siteSupervisorEntries.where('siteId', isEqualTo: siteCode).get();
    if (query.docs.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entries found')));
      return;
    }
    
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: 24,
        child: ListView.builder(
          itemCount: query.docs.length,
          itemBuilder: (c, i) {
            final doc = query.docs[i];
            final data = doc.data();
            final date = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();
            return ListTile(
              title: Text(DateFormat('dd MMM yyyy').format(date)),
              subtitle: Text('Total: ₹${data['totalAmount']}'),
              onTap: () {
                Navigator.pop(ctx);
                _loadEntry(doc.id, data);
              },
            );
          },
        ),
      ),
    );
  }

  void _loadEntry(String id, Map<String, dynamic> data) {
    setState(() {
      _updateDocId = id;
      isUpdateMode = true;
      materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
      labours = List<Map<String, dynamic>>.from(data['labours'] ?? []);
      foodCost.text = data['food']?.toString() ?? '0';
      transportCost.text = data['transport']?.toString() ?? '0';
      fuelCost.text = data['fuel']?.toString() ?? '0';
    });
  }
}