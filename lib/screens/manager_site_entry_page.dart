import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../utils/responsive.dart';
import 'supervisor_dashboard.dart';

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
  int materialQty = 0;
  final materialQtyController = TextEditingController(text: '0');
  String? selectedLabour;
  int labourQty = 0;
  final labourQtyController = TextEditingController(text: '0');
  final foodCost = TextEditingController(text: '0');
  final transportCost = TextEditingController(text: '0');
  final fuelCost = TextEditingController(text: '0');
  DateTime? selectedDate = DateTime.now();
  List<String> materialOptions = [];
  List<String> labourOptions = [];
  List<String>? _filteredMaterialOptions;
  List<String>? _filteredLabourOptions;
  bool isLoadingMaterials = true;
  bool isLoadingLabours = true;
  String? materialError;
  String? labourError;
  String? supervisorId;
  String? projectName;
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

  // Custom material fields
  bool _showCustomMaterialFields = false;
  final _customMaterialNameController = TextEditingController();
  final _customMaterialQtyController = TextEditingController(text: '0');
  final _customMaterialPriceController = TextEditingController(text: '0');

  // Custom labour fields
  bool _showCustomLabourFields = false;
  final _customLabourNameController = TextEditingController();
  final _customLabourSalaryController = TextEditingController(text: '0');

  // Update Entry state
  bool isUpdateMode = false;
  String? _updateDocId;
  bool isLoadingEntryDates = false;
  DateTime? _selectedUpdateDate;

  // Theme support
  late Color primaryColor;
  late Color accentColor;
  final Color textColor = Colors.white;
  final Color successColor = const Color(0xFF27ae60);
  final Color warningColor = const Color(0xFFe67e22);
  final Color errorColor = const Color(0xFFe74c3c);

  @override
  void initState() {
    super.initState();
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    primaryColor = Theme.of(context).colorScheme.primary;
    accentColor = Theme.of(context).colorScheme.secondary;
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _fetchSites() async {
    setState(() => isLoadingSites = true);
    try {
      final snapshot = await FirestoreService.siteSupervisorMap
          .get();

      siteList = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'siteId': data['site']?.toString() ?? '',
              'supervisor': data['supervisor']?.toString() ?? '',
              'supervisorId': data['Supervisor ID']?.toString() ?? '',
              'location': data['location']?.toString() ?? '',
              'projectStage': data['projectStage']?.toString() ?? '',
            };
          })
          .where((site) => site['siteId']!.isNotEmpty)
          .toList();

      if (siteList.isNotEmpty) {
        selectedSiteId = siteList.first['siteId'];
        _onSiteSelected(selectedSiteId!);
      }
    } finally {
      setState(() => isLoadingSites = false);
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere((s) => s['siteId'] == siteId,
        orElse: () => {
              'siteId': '',
              'supervisor': '',
              'supervisorId': '',
              'location': '',
              'projectStage': ''
            });
    setState(() {
      selectedSiteId = siteId;
      siteCode = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId']?.isNotEmpty == true
          ? site['supervisorId']
          : 'Not Available';
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _fetchMaterialOptions() async {
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot = await FirestoreService.getCollection('materials').get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('materialName')) {
          final name = data['materialName']?.toString() ?? '';
          if (name.isNotEmpty) {
            options.add(name);
            final priceRaw = data['materialPrice'];
            num price = 0;
            if (priceRaw is num) {
              price = priceRaw;
            } else if (priceRaw is String) {
              price = num.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            }
            prices[name] = price;
          }
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial = materialOptions.isNotEmpty ? materialOptions.first : null;
        isLoadingMaterials = false;
      });
    } catch (e) {
      setState(() {
        materialError = 'Failed to load materials';
        isLoadingMaterials = false;
      });
    }
  }

  Future<void> _fetchLabourOptions() async {
    setState(() {
      isLoadingLabours = true;
      labourError = null;
    });
    try {
      final snapshot = await FirestoreService.getCollection('labours').get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('designation')) {
          final designation = data['designation']?.toString() ?? '';
          if (designation.isNotEmpty) {
            options.add(designation);
            final salaryRaw = data['salary'];
            num salary = 0;
            if (salaryRaw is num) {
              salary = salaryRaw;
            } else if (salaryRaw is String) {
              salary = num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            }
            salaries[designation] = salary;
          }
        }
      }
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    } catch (e) {
      setState(() {
        labourError = 'Failed to load labours';
        isLoadingLabours = false;
      });
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
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
    final price = int.tryParse(_customMaterialPriceController.text) ?? 0;

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
    final salary = int.tryParse(_customLabourSalaryController.text) ?? 0;

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

  void _removeMaterial(int index) => setState(() => materials.removeAt(index));
  void _removeLabour(int index) => setState(() => labours.removeAt(index));

  String _calculateMaterialAmount(String material, int qty) {
    final price = materialPrices[material] ?? 0;
    return '₹${(price * qty).toStringAsFixed(0)}';
  }

  String _calculateLabourAmount(String labour, int qty) {
    final salary = labourSalaries[labour] ?? 0;
    return '₹${(salary * qty).toStringAsFixed(0)}';
  }

  int _getMaterialsTotal() {
    int total = 0;
    for (var m in materials) {
      final price = materialPrices[m['type'] ?? ''] ?? 0;
      total += (price * (m['quantity'] ?? 0)).toInt();
    }
    return total;
  }

  int _getLabourTotal() {
    int total = 0;
    for (var l in labours) {
      final salary = labourSalaries[l['type'] ?? ''] ?? 0;
      total += (salary * (l['count'] ?? 0)).toInt();
    }
    return total;
  }

  int _getMiscTotal() {
    int total = 0;
    total += int.tryParse(foodCost.text) ?? 0;
    total += int.tryParse(transportCost.text) ?? 0;
    total += int.tryParse(fuelCost.text) ?? 0;
    return total;
  }

  int _getTotalAmount() => _getMaterialsTotal() + _getLabourTotal() + _getMiscTotal();

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      materialQtyController.text = '0';
      labourQtyController.text = '0';
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _saveToFirestore() async {
    if (siteCode.isEmpty || selectedDate == null || supervisorName == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Missing required fields'), backgroundColor: errorColor));
      return;
    }
    setState(() => isSaving = true);
    final dateForId = DateFormat('ddMMyyyy').format(selectedDate!);
    final docId = '${siteCode}_$dateForId';
    final data = {
      "date": selectedDate!.toIso8601String(),
      "food": int.tryParse(foodCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "labours": labours.map((l) => {"type": l['type'], "count": l['count'], "unitSalary": labourSalaries[l['type']] ?? 0, "amount": (labourSalaries[l['type']] ?? 0) * (l['count'] ?? 0)}).toList(),
      "materials": materials.map((m) => {"type": m['type'], "quantity": m['quantity'], "unitPrice": materialPrices[m['type']] ?? 0, "amount": (materialPrices[m['type']] ?? 0) * (m['quantity'] ?? 0)}).toList(),
      "Supervisor ID": supervisorId,
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
      "siteLocation": siteLocation,
      "siteId": siteCode,
      "supervisorName": supervisorName,
      "projectStage": projectStage,
    };
    try {
      await FirestoreService.siteSupervisorEntries.doc(docId).set(data);
      await ExpenseService.updateTotalSiteExpense(siteCode);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Saved successfully!'), backgroundColor: successColor));
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: errorColor));
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _updateExistingEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);
    final data = {
      "food": int.tryParse(foodCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "labours": labours.map((l) => {"type": l['type'], "count": l['count'], "unitSalary": labourSalaries[l['type']] ?? 0, "amount": (labourSalaries[l['type']] ?? 0) * (l['count'] ?? 0)}).toList(),
      "materials": materials.map((m) => {"type": m['type'], "quantity": m['quantity'], "unitPrice": materialPrices[m['type']] ?? 0, "amount": (materialPrices[m['type']] ?? 0) * (m['quantity'] ?? 0)}).toList(),
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
    };
    try {
      await FirestoreService.siteSupervisorEntries.doc(_updateDocId).update(data);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Updated successfully!'), backgroundColor: successColor));
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: errorColor));
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _openUpdateEntrySelector() async {
    setState(() => isLoadingEntryDates = true);
    try {
      final query = await FirestoreService.siteSupervisorEntries.where('siteId', isEqualTo: siteCode).get();
      final entries = query.docs.map((doc) => {'docId': doc.id, 'date': (doc.data()['date'] is Timestamp) ? (doc.data()['date'] as Timestamp).toDate() : DateTime.tryParse(doc.data()['date'] ?? '') ?? DateTime.now()}).toList();
      entries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      if (entries.isEmpty) return;

      String selectedDocId = entries.first['docId'] as String;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Entry'),
          content: DropdownButtonFormField<String>(
            value: selectedDocId,
            items: entries.map((e) => DropdownMenuItem(value: e['docId'] as String, child: Text(DateFormat('yyyy-MM-dd').format(e['date'] as DateTime)))).toList(),
            onChanged: (val) => selectedDocId = val!,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () { Navigator.pop(context); _loadEntryByDocId(selectedDocId); }, child: const Text('Load')),
          ],
        ),
      );
    } finally {
      setState(() => isLoadingEntryDates = false);
    }
  }

  Future<void> _loadEntryByDocId(String docId) async {
    final doc = await FirestoreService.siteSupervisorEntries.doc(docId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
      labours = List<Map<String, dynamic>>.from(data['labours'] ?? []);
      foodCost.text = data['food']?.toString() ?? '0';
      transportCost.text = data['transport']?.toString() ?? '0';
      fuelCost.text = data['fuel']?.toString() ?? '0';
      isUpdateMode = true;
      _updateDocId = docId;
      _selectedUpdateDate = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : DateTime.tryParse(data['date'] ?? '');
    });
  }

  Widget _buildMaterialSection(bool isSmallScreen) {
    return GlassCard(
      title: 'Material Details',
      child: Column(
        children: [
          _buildMaterialInputs(),
          if (materials.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 32),
            _buildAddedItemsList(materials, 'Materials', _removeMaterial),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialInputs() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Custom Material', style: TextStyle(color: Colors.white, fontSize: 14)),
          value: _showCustomMaterialFields,
          onChanged: (val) => setState(() => _showCustomMaterialFields = val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (!_showCustomMaterialFields)
          DropdownButtonFormField<String>(
            value: selectedMaterial,
            dropdownColor: const Color(0xFF1A1A1A),
            decoration: _inputDecoration('Select Material', Icons.category),
            items: materialOptions.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
            onChanged: (val) => setState(() => selectedMaterial = val),
          )
        else
          GlassTextField(controller: _customMaterialNameController, label: 'Material Name', icon: Icons.edit),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: GlassTextField(controller: _showCustomMaterialFields ? _customMaterialQtyController : materialQtyController, label: 'Qty', icon: Icons.numbers, keyboardType: TextInputType.number)),
            if (_showCustomMaterialFields) ...[
              const SizedBox(width: 12),
              Expanded(child: GlassTextField(controller: _customMaterialPriceController, label: 'Price', icon: Icons.payments, keyboardType: TextInputType.number)),
            ],
            IconButton(onPressed: _showCustomMaterialFields ? _addCustomMaterial : _addMaterial, icon: Icon(Icons.add_circle, color: primaryColor, size: 32)),
          ],
        ),
      ],
    );
  }

  Widget _buildLabourSection(bool isSmallScreen) {
    return GlassCard(
      title: 'Labour Details',
      child: Column(
        children: [
          _buildLabourInputs(),
          if (labours.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 32),
            _buildAddedItemsList(labours, 'Labour', _removeLabour),
          ],
        ],
      ),
    );
  }

  Widget _buildLabourInputs() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Custom Designation', style: TextStyle(color: Colors.white, fontSize: 14)),
          value: _showCustomLabourFields,
          onChanged: (val) => setState(() => _showCustomLabourFields = val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (!_showCustomLabourFields)
          DropdownButtonFormField<String>(
            value: selectedLabour,
            dropdownColor: const Color(0xFF1A1A1A),
            decoration: _inputDecoration('Select Designation', Icons.engineering),
            items: labourOptions.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
            onChanged: (val) => setState(() => selectedLabour = val),
          )
        else
          Column(
            children: [
              GlassTextField(controller: _customLabourNameController, label: 'Designation', icon: Icons.edit),
              const SizedBox(height: 16),
              GlassTextField(controller: _customLabourSalaryController, label: 'Salary', icon: Icons.payments, keyboardType: TextInputType.number),
            ],
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: GlassTextField(controller: labourQtyController, label: 'Count', icon: Icons.people, keyboardType: TextInputType.number)),
            IconButton(onPressed: _showCustomLabourFields ? _addCustomLabour : _addLabour, icon: Icon(Icons.add_circle, color: primaryColor, size: 32)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiscellaneousExpenses(bool isSmallScreen) {
    return GlassCard(
      title: 'Miscellaneous',
      child: Column(
        children: [
          GlassTextField(controller: foodCost, label: 'Food', icon: Icons.restaurant, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          GlassTextField(controller: transportCost, label: 'Transport', icon: Icons.local_shipping, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          GlassTextField(controller: fuelCost, label: 'Fuel', icon: Icons.local_gas_station, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isSmallScreen) {
    return GlassCard(
      title: 'Entry Summary',
      child: Column(
        children: [
          _buildSummaryRow('Materials', _getMaterialsTotal()),
          _buildSummaryRow('Labour', _getLabourTotal()),
          _buildSummaryRow('Misc', _getMiscTotal()),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('₹${_getTotalAmount()}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text('₹$amount', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAddedItemsList(List<Map<String, dynamic>> items, String type, Function(int) onRemove) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final qty = item['quantity'] ?? item['count'] ?? 0;
        final amount = type == 'Materials' ? _calculateMaterialAmount(item['type'], qty) : _calculateLabourAmount(item['type'], qty);
        return ListTile(
          dense: true,
          title: Text(item['type'], style: const TextStyle(color: Colors.white)),
          subtitle: Text('$qty units • $amount', style: const TextStyle(color: Colors.white54)),
          trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => onRemove(entry.key)),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = Responsive.isMobile(context);
    return GlassScaffold(
      title: isUpdateMode ? 'Update Site Entry' : 'Daily Site Entry',
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: _openUpdateEntrySelector,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassCard(
              title: 'Site Information',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSiteId,
                    dropdownColor: const Color(0xFF1A1A1A),
                    decoration: _inputDecoration('Select Site', Icons.construction),
                    items: siteList.map((s) => DropdownMenuItem(value: s['siteId'], child: Text(s['siteId']!, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (val) => _onSiteSelected(val!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(supervisorName ?? 'No Supervisor', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(siteLocation ?? 'No Location', style: const TextStyle(color: Colors.white54)),
                    leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.2), child: Icon(Icons.person, color: primaryColor)),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    title: Text(DateFormat('yyyy-MM-dd').format(selectedDate!), style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                    onTap: isUpdateMode ? null : _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildMaterialSection(isSmallScreen),
            const SizedBox(height: 16),
            _buildLabourSection(isSmallScreen),
            const SizedBox(height: 16),
            _buildMiscellaneousExpenses(isSmallScreen),
            const SizedBox(height: 16),
            _buildSummaryCard(isSmallScreen),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isSaving ? null : (isUpdateMode ? _updateExistingEntry : _saveToFirestore),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isUpdateMode ? 'UPDATE ENTRY' : 'SAVE ENTRY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if (isUpdateMode) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetForm,
                child: const Text('CANCEL UPDATE', style: TextStyle(color: Colors.white70)),
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}