import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/expense_service.dart';
import 'supervisor_dashboard.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

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
  final morningStatusController = TextEditingController();
  final afternoonStatusController = TextEditingController();
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

  // Update mode state
  bool isUpdateMode = false;
  String? _updateDocId;
  bool isLoadingEntryDates = false;
  List<Map<String, dynamic>> _existingEntries = [];
  DateTime? _selectedUpdateDate;

  Color get primaryColor => Theme.of(context).primaryColor;
  Color get successColor => const Color(0xFF27ae60);
  Color get warningColor => const Color(0xFFe67e22);
  Color get errorColor => Theme.of(context).colorScheme.error;

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
    morningStatusController.dispose();
    afternoonStatusController.dispose();
    _customMaterialNameController.dispose();
    _customMaterialQtyController.dispose();
    _customMaterialPriceController.dispose();
    _customLabourNameController.dispose();
    _customLabourSalaryController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    if (!mounted) return;
    setState(() => isLoadingSites = true);
    try {
      final sitesSnapshot = await FirestoreService.sites.get();
      final Map<String, String> siteNames = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      siteList = snapshot.docs.map((doc) {
        final data = doc.data();
        final sId = data['site']?.toString() ?? '';
        return {
          'siteId': sId,
          'siteName': siteNames[sId] ?? 'Unnamed Site',
          'supervisor': data['supervisor']?.toString() ?? 'Not Available',
          'supervisorId': (data['Supervisor ID'] ?? data['supervisorId'])?.toString() ?? 'Not Available',
          'location': data['location']?.toString() ?? 'Not Available',
          'projectStage': data['projectStage']?.toString() ?? 'Not Available',
        };
      }).where((site) => site['siteId']!.isNotEmpty).toList();

      if (siteList.isNotEmpty) {
        selectedSiteId = siteList.first['siteId'];
        _onSiteSelected(selectedSiteId!);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere((s) => s['siteId'] == siteId, orElse: () => {});
    setState(() {
      selectedSiteId = siteId;
      siteCode = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId'] ?? 'Not Available';
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _fetchMaterialOptions() async {
    if (!mounted) return;
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot = await FirestoreService.materials.get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
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
      if (!mounted) return;
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial = materialOptions.isNotEmpty ? materialOptions.first : null;
        isLoadingMaterials = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingMaterials = false);
    }
  }

  Future<void> _fetchLabourOptions() async {
    if (!mounted) return;
    setState(() {
      isLoadingLabours = true;
      labourError = null;
    });
    try {
      final snapshot = await FirestoreService.labours.get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final des = data['designation']?.toString() ?? '';
        if (des.isNotEmpty) {
          options.add(des);
          final salaryRaw = data['salary'];
          num salary = 0;
          if (salaryRaw is num) {
            salary = salaryRaw;
          } else if (salaryRaw is String) {
            salary = num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          salaries[des] = salary;
        }
      }
      if (!mounted) return;
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingLabours = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => selectedDate = picked);
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

  void _removeMaterial(int index) {
    setState(() => materials.removeAt(index));
  }

  void _removeLabour(int index) {
    setState(() => labours.removeAt(index));
  }

  String _calculateMaterialAmount(String material, int qty) {
    final price = materialPrices[material] ?? 0;
    return '₹${(price * qty).toStringAsFixed(0)}';
  }

  String _calculateLabourAmount(String labour, int qty) {
    final salary = labourSalaries[labour] ?? 0;
    return '₹${(salary * qty).toStringAsFixed(0)}';
  }

  int _getTotalAmount() {
    int total = 0;
    for (var m in materials) {
      final price = materialPrices[m['type'] ?? ''] ?? 0;
      total += (price * (m['quantity'] ?? 0)).toInt();
    }
    for (var l in labours) {
      final salary = labourSalaries[l['type'] ?? ''] ?? 0;
      total += (salary * (l['count'] ?? 0)).toInt();
    }
    total += int.tryParse(foodCost.text) ?? 0;
    total += int.tryParse(transportCost.text) ?? 0;
    total += int.tryParse(fuelCost.text) ?? 0;
    return total;
  }

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      materialQtyController.text = '0';
      labourQtyController.text = '0';
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      morningStatusController.clear();
      afternoonStatusController.clear();
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _customLabourNameController.clear();
      _customLabourSalaryController.text = '0';
      _showCustomMaterialFields = false;
      _showCustomLabourFields = false;
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Entry'),
        content: Text('Total Amount: ₹${_getTotalAmount()}\nAre you sure you want to save?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveToFirestore();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToFirestore() async {
    if (siteCode.isEmpty) return;
    setState(() => isSaving = true);
    final docId = '${siteCode}_${DateFormat('ddMMyyyy').format(selectedDate!)}';
    final data = {
      "date": selectedDate!.toIso8601String(),
      "siteId": siteCode,
      "totalAmount": _getTotalAmount(),
      "materials": materials,
      "labours": labours,
      "food": int.tryParse(foodCost.text) ?? 0,
      "transport": int.tryParse(transportCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "supervisorId": supervisorId,
      "supervisorName": supervisorName,
      "projectName": projectName,
      "siteLocation": siteLocation,
      "projectStage": projectStage,
      "morningStatus": morningStatusController.text,
      "afternoonStatus": afternoonStatusController.text,
    };
    try {
      await FirebaseFirestore.instance.collection('siteSupervisorEntries').doc(docId).set(data);
      await ExpenseService.updateTotalSiteExpense(siteCode);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
      _resetForm();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _openUpdateEntrySelector() async {
    if (siteCode.isEmpty) return;
    setState(() => isLoadingEntryDates = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .where('siteId', isEqualTo: siteCode)
          .get();

      final entries = <Map<String, dynamic>>[];
      for (var doc in query.docs) {
        final data = doc.data();
        final rawDate = data['date'];
        DateTime? dt;
        if (rawDate is String) dt = DateTime.tryParse(rawDate);
        else if (rawDate is Timestamp) dt = rawDate.toDate();
        if (dt != null) entries.add({'docId': doc.id, 'date': dt});
      }
      entries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      if (entries.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entries found.')));
        return;
      }

      String selectedDocId = entries.first['docId'];
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Entry'),
          content: DropdownButtonFormField<String>(
            value: selectedDocId,
            items: entries.map((e) => DropdownMenuItem(value: e['docId'] as String, child: Text(DateFormat('yyyy-MM-dd').format(e['date'] as DateTime)))).toList(),
            onChanged: (v) => selectedDocId = v ?? selectedDocId,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () { Navigator.pop(context); _loadEntryByDocId(selectedDocId); }, child: const Text('Load')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => isLoadingEntryDates = false);
    }
  }

  Future<void> _loadEntryByDocId(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('siteSupervisorEntries').doc(docId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        materials = (data['materials'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        labours = (data['labours'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        foodCost.text = (data['food'] ?? 0).toString();
        transportCost.text = (data['transport'] ?? 0).toString();
        fuelCost.text = (data['fuel'] ?? 0).toString();
        morningStatusController.text = data['morningStatus'] ?? '';
        afternoonStatusController.text = data['afternoonStatus'] ?? '';
        isUpdateMode = true;
        _updateDocId = docId;
        final rawDate = data['date'];
        if (rawDate is String) selectedDate = DateTime.tryParse(rawDate);
        _selectedUpdateDate = selectedDate;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<void> _updateExistingEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('siteSupervisorEntries').doc(_updateDocId).update({
        "materials": materials,
        "labours": labours,
        "food": int.tryParse(foodCost.text) ?? 0,
        "transport": int.tryParse(transportCost.text) ?? 0,
        "fuel": int.tryParse(fuelCost.text) ?? 0,
        "morningStatus": morningStatusController.text,
        "afternoonStatus": afternoonStatusController.text,
        "totalAmount": _getTotalAmount(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated!')));
      _resetForm();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Manager Daily Site Entry',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SupervisorDashboard(username: widget.userName, supervisorId: '', supervisorName: '')),
              (route) => false,
            );
          },
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600, minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      title: 'Site Selection',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isLoadingSites
                              ? const Center(child: CircularProgressIndicator())
                              : DropdownButtonFormField<String>(
                                  value: selectedSiteId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Site ID',
                                    prefixIcon: Icon(Icons.construction, color: primaryColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                  items: siteList.map((site) => DropdownMenuItem(value: site['siteId'], child: Text('${site['siteId']} - ${site['siteName']}', overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (value) => value != null ? _onSiteSelected(value) : null,
                                ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Supervisor', supervisorName ?? '-', Icons.person),
                          _buildInfoRow('Supervisor ID', supervisorId ?? '-', Icons.badge_outlined),
                          _buildInfoRow('Location', siteLocation ?? '-', Icons.location_on),
                          _buildInfoRow('Project Stage', projectStage ?? '-', Icons.timeline),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: primaryColor),
                              const SizedBox(width: 8),
                              Text('Date: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                              Text(selectedDate != null ? DateFormat('dd MMM yyyy').format(selectedDate!) : 'Not set', style: const TextStyle(color: Colors.white)),
                              const Spacer(),
                              TextButton(onPressed: _pickDate, child: const Text('Change')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GlassButton(
                            label: isUpdateMode ? 'Loaded: ${DateFormat('yyyy-MM-dd').format(_selectedUpdateDate!)}' : 'SELECT EXISTING ENTRY',
                            icon: Icons.history,
                            onPressed: _openUpdateEntrySelector,
                            isSecondary: true,
                          ),
                          if (isUpdateMode)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GlassButton(label: 'EXIT UPDATE MODE', icon: Icons.close, onPressed: _resetForm, isSecondary: true),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Work Updates',
                      child: Column(
                        children: [
                          _buildTextArea('Morning Updates', morningStatusController, Icons.wb_sunny_outlined),
                          const SizedBox(height: 12),
                          _buildTextArea('Afternoon Updates', afternoonStatusController, Icons.wb_twilight_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Material Details',
                      child: Column(
                        children: [
                          isLoadingMaterials
                              ? const CircularProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  value: selectedMaterial,
                                  decoration: const InputDecoration(labelText: 'Select Material', border: OutlineInputBorder()),
                                  items: materialOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                  onChanged: (v) => setState(() => selectedMaterial = v),
                                ),
                          const SizedBox(height: 12),
                          _buildQtyField('Quantity', materialQtyController),
                          const SizedBox(height: 12),
                          GlassButton(label: 'ADD MATERIAL', icon: Icons.add, onPressed: _addMaterial, isSecondary: true),
                          TextButton(onPressed: () => setState(() => _showCustomMaterialFields = !_showCustomMaterialFields), child: Text(_showCustomMaterialFields ? 'Hide Custom' : 'Add Custom Material')),
                          if (_showCustomMaterialFields) ...[
                            _buildTextField('Material Name', _customMaterialNameController),
                            const SizedBox(height: 8),
                            _buildQtyField('Qty', _customMaterialQtyController),
                            const SizedBox(height: 8),
                            _buildQtyField('Price', _customMaterialPriceController),
                            const SizedBox(height: 8),
                            GlassButton(label: 'ADD CUSTOM', icon: Icons.check, onPressed: _addCustomMaterial, isSecondary: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Labour Details',
                      child: Column(
                        children: [
                          isLoadingLabours
                              ? const CircularProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  value: selectedLabour,
                                  decoration: const InputDecoration(labelText: 'Select Labour', border: OutlineInputBorder()),
                                  items: labourOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                                  onChanged: (v) => setState(() => selectedLabour = v),
                                ),
                          const SizedBox(height: 12),
                          _buildQtyField('Count', labourQtyController),
                          const SizedBox(height: 12),
                          GlassButton(label: 'ADD LABOUR', icon: Icons.person_add, onPressed: _addLabour, isSecondary: true),
                          TextButton(onPressed: () => setState(() => _showCustomLabourFields = !_showCustomLabourFields), child: Text(_showCustomLabourFields ? 'Hide Custom' : 'Add Custom Labour')),
                          if (_showCustomLabourFields) ...[
                            _buildTextField('Labour Type', _customLabourNameController),
                            const SizedBox(height: 8),
                            _buildQtyField('Salary', _customLabourSalaryController),
                            const SizedBox(height: 8),
                            GlassButton(label: 'ADD CUSTOM', icon: Icons.check, onPressed: _addCustomLabour, isSecondary: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Other Expenses',
                      child: Column(
                        children: [
                          _buildQtyField('Food (₹)', foodCost, icon: Icons.fastfood),
                          const SizedBox(height: 8),
                          _buildQtyField('Transport (₹)', transportCost, icon: Icons.directions_car),
                          const SizedBox(height: 8),
                          _buildQtyField('Fuel (₹)', fuelCost, icon: Icons.local_gas_station),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (materials.isNotEmpty || labours.isNotEmpty)
                      GlassCard(
                        title: 'Today\'s Summary (Total: ₹${_getTotalAmount()})',
                        child: _buildSummaryTable(),
                      ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(child: GlassButton(label: isUpdateMode ? 'UPDATE' : 'SAVE', icon: isUpdateMode ? Icons.update : Icons.save, onPressed: isUpdateMode ? _updateExistingEntry : _showConfirmationDialog, isLoading: isSaving)),
                        const SizedBox(width: 12),
                        Expanded(child: GlassButton(label: 'RESET', icon: Icons.refresh, onPressed: _resetForm, isSecondary: true)),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: const OutlineInputBorder()),
    );
  }

  Widget _buildQtyField(String label, TextEditingController ctrl, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null, labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: const OutlineInputBorder()),
    );
  }

  Widget _buildTextArea(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      maxLines: 2,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(prefixIcon: Icon(icon, color: primaryColor), labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: const OutlineInputBorder()),
    );
  }

  Widget _buildSummaryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [DataColumn(label: Text('Item', style: TextStyle(color: Colors.white70))), DataColumn(label: Text('Qty', style: TextStyle(color: Colors.white70))), DataColumn(label: Text('Amt', style: TextStyle(color: Colors.white70))), DataColumn(label: Text('', style: TextStyle(color: Colors.white70)))],
        rows: [
          ...materials.asMap().entries.map((e) => DataRow(cells: [DataCell(Text(e.value['type'], style: const TextStyle(color: Colors.white))), DataCell(Text('${e.value['quantity']}', style: const TextStyle(color: Colors.white))), DataCell(Text(_calculateMaterialAmount(e.value['type'], e.value['quantity']), style: const TextStyle(color: Colors.white))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _removeMaterial(e.key)))]))
          , ...labours.asMap().entries.map((e) => DataRow(cells: [DataCell(Text(e.value['type'], style: const TextStyle(color: Colors.white))), DataCell(Text('${e.value['count']}', style: const TextStyle(color: Colors.white))), DataCell(Text(_calculateLabourAmount(e.value['type'], e.value['count']), style: const TextStyle(color: Colors.white))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _removeLabour(e.key)))]))
        ],
      ),
    );
  }
}
