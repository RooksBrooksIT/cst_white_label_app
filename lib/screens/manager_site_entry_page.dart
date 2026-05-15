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
  final _customLabourQtyController = TextEditingController(text: '0');

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
    _customLabourQtyController.dispose();
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
      siteList = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final sId = data['site']?.toString() ?? '';
            return {
              'siteId': sId,
              'siteName': siteNames[sId] ?? 'Unnamed Site',
              'supervisor': data['supervisor']?.toString() ?? 'Not Available',
              'supervisorId':
                  (data['Supervisor ID'] ?? data['supervisorId'])?.toString() ??
                  'Not Available',
              'location': data['location']?.toString() ?? 'Not Available',
              'projectStage':
                  data['projectStage']?.toString() ?? 'Not Available',
            };
          })
          .where((site) => site['siteId']!.isNotEmpty)
          .toList();

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
    final site = siteList.firstWhere(
      (s) => s['siteId'] == siteId,
      orElse: () => {},
    );
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
            price =
                num.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          prices[name] = price;
        }
      }
      if (!mounted) return;
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial = materialOptions.isNotEmpty
            ? materialOptions.first
            : null;
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
            salary =
                num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
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
    final qty = int.tryParse(_customLabourQtyController.text) ?? 0;
    final salary = int.tryParse(_customLabourSalaryController.text) ?? 0;

    if (name.isNotEmpty && qty > 0) {
      setState(() {
        labours.add({'type': name, 'count': qty});
        labourSalaries[name] = salary;
        _showCustomLabourFields = false;
        _customLabourNameController.clear();
        _customLabourQtyController.text = '0';
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
      _customLabourQtyController.text = '0';
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
        content: Text(
          'Total Amount: ₹${_getTotalAmount()}\nAre you sure you want to save?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
      await FirestoreService.siteSupervisorEntries
          .doc(docId)
          .set(data);
      await ExpenseService.updateTotalSiteExpense(siteCode);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved!')));
      _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _openUpdateEntrySelector() async {
    if (siteCode.isEmpty) return;
    setState(() => isLoadingEntryDates = true);
    try {
      final query = await FirestoreService.siteSupervisorEntries
          .where('siteId', isEqualTo: siteCode)
          .get();

      final entries = <Map<String, dynamic>>[];
      for (var doc in query.docs) {
        final data = doc.data();
        final rawDate = data['date'];
        DateTime? dt;
        if (rawDate is String)
          dt = DateTime.tryParse(rawDate);
        else if (rawDate is Timestamp)
          dt = rawDate.toDate();
        if (dt != null) entries.add({'docId': doc.id, 'date': dt});
      }
      entries.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      if (entries.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No entries found.')));
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
            items: entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e['docId'] as String,
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(e['date'] as DateTime),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => selectedDocId = v ?? selectedDocId,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadEntryByDocId(selectedDocId);
              },
              child: const Text('Load'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => isLoadingEntryDates = false);
    }
  }

  Future<void> _loadEntryByDocId(String docId) async {
    try {
      final doc = await FirestoreService.siteSupervisorEntries
          .doc(docId)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        materials = (data['materials'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        labours = (data['labours'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<void> _updateExistingEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);
    try {
      await FirestoreService.siteSupervisorEntries
          .doc(_updateDocId)
          .update({
            "materials": materials,
            "labours": labours,
            "food": int.tryParse(foodCost.text) ?? 0,
            "transport": int.tryParse(transportCost.text) ?? 0,
            "fuel": int.tryParse(fuelCost.text) ?? 0,
            "morningStatus": morningStatusController.text,
            "afternoonStatus": afternoonStatusController.text,
            "totalAmount": _getTotalAmount(),
          });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated!')));
      _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
              MaterialPageRoute(
                builder: (_) => SupervisorDashboard(
                  username: widget.userName,
                  supervisorId: '',
                  supervisorName: '',
                ),
              ),
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
                constraints: BoxConstraints(
                  maxWidth: 600,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Site Information Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withOpacity(0.8),
                              primaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.construction,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: isLoadingSites
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8.0,
                                                  ),
                                              child: DropdownButtonFormField<String>(
                                                value: selectedSiteId,
                                                isExpanded: true,
                                                decoration: InputDecoration(
                                                  labelText: 'Site ID',
                                                  labelStyle: TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 10,
                                                      ),
                                                  isDense: true,
                                                ),
                                                items: siteList
                                                    .map(
                                                      (
                                                        site,
                                                      ) => DropdownMenuItem(
                                                        value: site['siteId'],
                                                        child: Text(
                                                          '${site['siteId']} - ${site['siteName']}',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .black87,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    _onSiteSelected(value);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.person,
                                'Supervisor:',
                                supervisorName ?? '-',
                              ),
                              if (supervisorId != null &&
                                  supervisorId!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 30.0,
                                    top: 4,
                                  ),
                                  child: Text(
                                    'ID: ${supervisorId ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              _buildInfoRow(
                                Icons.location_on,
                                'Location:',
                                siteLocation ?? '-',
                              ),
                              _buildInfoRow(
                                Icons.timeline,
                                'Project Stage:',
                                projectStage ?? '-',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      selectedDate != null
                                          ? DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(selectedDate!)
                                          : 'No date chosen',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  isUpdateMode
                                      ? const SizedBox.shrink()
                                      : TextButton.icon(
                                          onPressed: _pickDate,
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            'Change',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Update Entry Section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader('Update Entry'),
                            const SizedBox(height: 8),
                            if (isUpdateMode && _selectedUpdateDate != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Loaded entry for: ' +
                                      DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(_selectedUpdateDate!),
                                  style: TextStyle(
                                    color: successColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.history, size: 18),
                                    onPressed:
                                        isLoadingSites ||
                                            selectedSiteId == null ||
                                            selectedSiteId!.isEmpty
                                        ? null
                                        : _openUpdateEntrySelector,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    label: const Text('Select Existing Entry'),
                                  ),
                                ),
                                if (isUpdateMode) const SizedBox(width: 8),
                                if (isUpdateMode)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          isUpdateMode = false;
                                          _updateDocId = null;
                                          _selectedUpdateDate = null;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Exit Update Mode'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Form Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Add Entry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const Divider(height: 20, color: Colors.grey),

                    // Material Section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader('Material Details'),
                            const SizedBox(height: 12),

                            // Existing material selection UI
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: isLoadingMaterials
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : materialError != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                materialError!,
                                                style: TextStyle(
                                                  color: errorColor,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                TextField(
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Search Material...',
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 12,
                                                        ),
                                                    prefixIcon: Icon(
                                                      Icons.search,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  onChanged: (query) {
                                                    setState(() {
                                                      final q = query
                                                          .toLowerCase();
                                                      final filtered =
                                                          materialOptions
                                                              .where(
                                                                (item) => item
                                                                    .toLowerCase()
                                                                    .startsWith(
                                                                      q,
                                                                    ),
                                                              )
                                                              .toList();
                                                      filtered.sort(
                                                        (a, b) => a
                                                            .toLowerCase()
                                                            .compareTo(
                                                              b.toLowerCase(),
                                                            ),
                                                      );
                                                      if (filtered.isNotEmpty) {
                                                        selectedMaterial =
                                                            filtered.contains(
                                                              selectedMaterial,
                                                            )
                                                            ? selectedMaterial
                                                            : filtered.first;
                                                      } else {
                                                        selectedMaterial = null;
                                                      }
                                                      _filteredMaterialOptions =
                                                          filtered;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                DropdownButtonFormField<String>(
                                                  value: selectedMaterial,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    labelText: 'Material',
                                                    prefixIcon: Icon(
                                                      Icons.category_outlined,
                                                      color: primaryColor,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color: primaryColor,
                                                            width: 2,
                                                          ),
                                                        ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 12,
                                                        ),
                                                  ),
                                                  items:
                                                      (_filteredMaterialOptions ??
                                                              materialOptions)
                                                          .map(
                                                            (
                                                              item,
                                                            ) => DropdownMenuItem(
                                                              value: item,
                                                              child: Text(
                                                                item,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                  onChanged: (value) =>
                                                      setState(
                                                        () => selectedMaterial =
                                                            value,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: materialQtyController,
                                        decoration: InputDecoration(
                                          labelText: 'Qty',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            materialQty =
                                                int.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Add Material button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed:
                                    isLoadingMaterials ||
                                        materialOptions.isEmpty
                                    ? null
                                    : _addMaterial,
                                label: const Text(
                                  'Add Material',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: Icon(
                                  _showCustomMaterialFields
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: primaryColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showCustomMaterialFields =
                                        !_showCustomMaterialFields;
                                  });
                                },
                                label: Text(
                                  _showCustomMaterialFields
                                      ? 'Hide Other Materials'
                                      : 'Other Materials',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                            ),
                            if (_showCustomMaterialFields) ...[
                              const SizedBox(height: 8),
                              _buildTextField(
                                'Material Name',
                                _customMaterialNameController,
                              ),
                              const SizedBox(height: 8),
                              _buildQtyField(
                                'Qty',
                                _customMaterialQtyController,
                              ),
                              const SizedBox(height: 8),
                              _buildQtyField(
                                'Unit Price',
                                _customMaterialPriceController,
                              ),
                              const SizedBox(height: 8),
                              GlassButton(
                                label: 'ADD OTHER MATERIAL',
                                icon: Icons.check,
                                onPressed: _addCustomMaterial,
                                isSecondary: true,
                              ),
                            ],
                          ],
                        ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Select Labour',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: labourOptions
                                      .map(
                                        (l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(l),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => selectedLabour = v),
                                ),
                          const SizedBox(height: 12),
                          _buildQtyField('Count', labourQtyController),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: 'ADD LABOUR',
                            icon: Icons.person_add,
                            onPressed: _addLabour,
                            isSecondary: true,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(
                                _showCustomLabourFields
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showCustomLabourFields =
                                      !_showCustomLabourFields;
                                });
                              },
                              label: Text(
                                _showCustomLabourFields
                                    ? 'Hide Custom Labour'
                                    : 'Add Custom Labour',
                                style: TextStyle(color: primaryColor),
                              ),
                            ),
                          ),
                          if (_showCustomLabourFields) ...[
                            _buildTextField(
                              'Labour Type',
                              _customLabourNameController,
                            ),
                            const SizedBox(height: 8),
                            _buildQtyField(
                              'Salary',
                              _customLabourSalaryController,
                            ),
                            const SizedBox(height: 8),
                            _buildQtyField('Count', _customLabourQtyController),
                            const SizedBox(height: 8),
                            GlassButton(
                              label: 'ADD CUSTOM',
                              icon: Icons.check,
                              onPressed: _addCustomLabour,
                              isSecondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Other Expenses',
                      child: Column(
                        children: [
                          _buildQtyField(
                            'Food (₹)',
                            foodCost,
                            icon: Icons.fastfood,
                          ),
                          const SizedBox(height: 8),
                          _buildQtyField(
                            'Transport (₹)',
                            transportCost,
                            icon: Icons.directions_car,
                          ),
                          const SizedBox(height: 8),
                          _buildQtyField(
                            'Fuel (₹)',
                            fuelCost,
                            icon: Icons.local_gas_station,
                          ),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: 'ADD',
                            icon: Icons.add,
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() {});
                            },
                            isSecondary: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (materials.isNotEmpty ||
                        labours.isNotEmpty ||
                        (int.tryParse(foodCost.text) ?? 0) > 0 ||
                        (int.tryParse(transportCost.text) ?? 0) > 0 ||
                        (int.tryParse(fuelCost.text) ?? 0) > 0)
                      GlassCard(
                        title:
                            'Today\'s Summary (Total: ₹${_getTotalAmount()})',
                        child: _buildSummaryTable(),
                      ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: isUpdateMode ? 'UPDATE' : 'SAVE',
                            icon: isUpdateMode ? Icons.update : Icons.save,
                            onPressed: isUpdateMode
                                ? _updateExistingEntry
                                : _showConfirmationDialog,
                            isLoading: isSaving,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassButton(
                            label: 'RESET',
                            icon: Icons.refresh,
                            onPressed: _resetForm,
                            isSecondary: true,
                          ),
                        ),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: primaryColor,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildQtyField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      maxLines: 2,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryColor),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(
            label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Amt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(label: Text('')),
        ],
        rows: [
          ...materials.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(Text(e.value['type'])),
                DataCell(Text('${e.value['quantity']}')),
                DataCell(
                  Text(
                    _calculateMaterialAmount(
                      e.value['type'],
                      e.value['quantity'],
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () => _removeMaterial(e.key),
                  ),
                ),
              ],
            ),
          ),
          ...labours.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(Text(e.value['type'])),
                DataCell(Text('${e.value['count']}')),
                DataCell(
                  Text(
                    _calculateLabourAmount(e.value['type'], e.value['count']),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () => _removeLabour(e.key),
                  ),
                ),
              ],
            ),
          ),
          if ((int.tryParse(foodCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text('Food')),
                const DataCell(Text('-')),
                DataCell(Text('₹${foodCost.text}')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => foodCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(transportCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text('Transport')),
                const DataCell(Text('-')),
                DataCell(Text('₹${transportCost.text}')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => transportCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(fuelCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text('Fuel')),
                const DataCell(Text('-')),
                DataCell(Text('₹${fuelCost.text}')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => fuelCost.text = '0'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
