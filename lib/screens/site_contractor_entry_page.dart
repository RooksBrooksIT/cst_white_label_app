import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import 'package:demo_cst/services/firestore_service.dart';

class SiteContractorEntryPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String userName;
  final Map<String, dynamic> userDetails;

  const SiteContractorEntryPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<SiteContractorEntryPage> createState() =>
      _SiteContractorEntryPageState();
}

class _SiteContractorEntryPageState extends State<SiteContractorEntryPage> {
  // Section 1: Contractor fields
  final _contractorNameController = TextEditingController();
  String? _selectedContractorName;
  String? _selectedProjectField;
  final TextEditingController _projectFieldController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // Section 2: Add Entry state (mirrors site_entry_page Add Entry functionality)
  final Color _primaryColor = const Color(0xFF772323);
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

  // Minimal supervisor/site context used only to populate dropdowns (not saved)
  String? supervisorId;
  String? projectName;
  String siteCode = '';
  String siteLocation = '';
  String? projectStage;
  List<Map<String, String>> supervisorSites = [];
  String? selectedSiteId;
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

  @override
  void initState() {
    super.initState();
    supervisorId = widget.supervisorId;
    selectedSiteId = widget.supervisorId;
    siteCode = widget.supervisorId;
    // Optionally fill the siteLocation if you want - can be fetched or fixed
    // supervisorName is from widget.supervisorName
    _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSupervisorData();
  }

  @override
  void dispose() {
    _contractorNameController.dispose();
    _projectFieldController.dispose();
    _dateController.dispose();
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

  Future<void> _fetchSupervisorData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.userName)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final sites = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'siteId': data['site']?.toString() ?? '',
                'location': data['location']?.toString() ?? 'Unknown',
                'supervisorId': data['Supervisor ID']?.toString() ?? '',
                'projectName': data['projectName']?.toString() ?? '',
                'projectStage': data['projectStage']?.toString() ?? '',
              };
            })
            .where((site) => site['siteId']!.isNotEmpty)
            .toList();
        setState(() {
          supervisorSites = sites;
          if (sites.isNotEmpty) {
            selectedSiteId = sites.first['siteId'];
            siteCode = sites.first['siteId']!;
            siteLocation = sites.first['location']!;
            supervisorId = sites.first['supervisorId']!;
            projectName = sites.first['projectName']!;
            projectStage = sites.first['projectStage']!;
          } else {
            selectedSiteId = null;
            siteCode = '';
            siteLocation = 'Unknown';
            supervisorId = 'Not found';
            projectName = 'Not found';
            projectStage = 'Not found';
          }
        });
      } else {
        setState(() {
          supervisorSites = [];
          selectedSiteId = null;
          supervisorId = 'Not found';
          siteCode = '';
          siteLocation = 'Unknown';
          projectName = 'Not found';
          projectStage = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        supervisorSites = [];
        selectedSiteId = null;
        supervisorId = 'Error loading';
        siteCode = '';
        siteLocation = 'Error loading';
        projectName = 'Not found';
        projectStage = 'Not found';
      });
    }
  }

  Future<void> _fetchMaterialOptions() async {
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot =
          await FirestoreService.getCollection('materials').get();
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
              price =
                  num.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            }
            prices[name] = price;
          }
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial =
            materialOptions.isNotEmpty ? materialOptions.first : null;
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
      final snapshot =
          await FirestoreService.getCollection('labours').get();
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
              salary =
                  num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ??
                      0;
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

  void _addMaterial() {
    int qty = int.tryParse(materialQtyController.text) ?? 0;
    if (selectedMaterial != null && qty > 0) {
      setState(() {
        materials.add({'type': selectedMaterial!, 'quantity': qty});
        materialQty = 0;
        materialQtyController.text = '0';
      });
    }
  }

  void _addLabour() {
    int qty = int.tryParse(labourQtyController.text) ?? 0;
    if (selectedLabour != null && qty > 0) {
      setState(() {
        labours.add({'type': selectedLabour!, 'count': qty});
        labourQty = 0;
        labourQtyController.text = '0';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveToFirestore() async {
    final siteIdForEntry =
        ((selectedSiteId ?? siteCode) ?? '').toString().trim();

    if (_selectedContractorName == null ||
        _selectedContractorName!.isEmpty ||
        _selectedProjectField == null ||
        _selectedProjectField!.isEmpty ||
        selectedDate == null ||
        siteIdForEntry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Select contractor, project field, date and site ID')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      // Build labours array with numeric fields
      final laboursList = labours.map((l) {
        final type = (l['type'] ?? '').toString();
        final count = (l['count'] ?? 0) as int;
        final unitSalary = (labourSalaries[type] ?? 0);
        final amount = (unitSalary * count).toInt();
        return {
          'amount': amount,
          'count': count,
          'type': type,
          'unitSalary':
              unitSalary is int ? unitSalary : (unitSalary).toInt(),
        };
      }).toList();

      // Build materials array with numeric fields
      final materialsList = materials.map((m) {
        final type = (m['type'] ?? '').toString();
        final qty = (m['quantity'] ?? 0) as int;
        final unitPrice = (materialPrices[type] ?? 0);
        final amount = (unitPrice * qty).toInt();
        return {
          'amount': amount,
          'quantity': qty,
          'type': type,
          'unitPrice':
              unitPrice is int ? unitPrice : (unitPrice).toInt(),
        };
      }).toList();

      final totalAmount = _getTotalAmount().toInt();
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final contractorNameForId = _selectedContractorName!
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      final docId = '${contractorNameForId}_$dateStr';

      final data = {
        'contractorName': _selectedContractorName,
        'projectField': _selectedProjectField ?? '',
        'date': dateStr,
        'food': int.tryParse(foodCost.text) ?? 0,
        'fuel': int.tryParse(fuelCost.text) ?? 0,
        'labours': laboursList,
        'materials': materialsList,
        'totalAmount': totalAmount,
        'transport': int.tryParse(transportCost.text) ?? 0,
        'siteId': siteIdForEntry,
      };

      await FirebaseFirestore.instance
          .collection('contractorEntries')
          .doc(docId)
          .set(data);

      // Update totals for this site (writes totalContractorExpense and totalAllExpenses)
      try {
        await ExpenseService.recalcTotalsAndSyncProject(siteIdForEntry);
      } catch (e) {
        debugPrint('Failed to update totals for siteId $siteIdForEntry: $e');
        // Do not block success on totals failure
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contractor entry saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save entry: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildCostInput(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSummaryTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowHeight: 40,
            dataRowHeight: 40,
            columns: const [
              DataColumn(
                  label: SizedBox(
                      width: 80,
                      child: Text('Type',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)))),
              DataColumn(
                  label: SizedBox(
                      width: 100,
                      child: Text('Item',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)))),
              DataColumn(
                  label: SizedBox(
                      width: 60,
                      child: Text('Qty',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)))),
              DataColumn(
                  label: SizedBox(
                      width: 100,
                      child: Text('Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)))),
              DataColumn(label: SizedBox(width: 40)),
            ],
            rows: [
              ...materials.asMap().entries.map((entry) {
                int idx = entry.key;
                var m = entry.value;
                return DataRow(cells: [
                  const DataCell(SizedBox(
                      width: 80,
                      child: Text('Material', style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text(m['type']?.toString() ?? '',
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('${m['quantity'] ?? 0}',
                          style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text(
                          _calculateMaterialAmount(
                              m['type']?.toString() ?? '', m['quantity'] ?? 0),
                          style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                    width: 40,
                    child: IconButton(
                      icon:
                          Icon(Icons.delete, color: Colors.red[300], size: 16),
                      onPressed: () => _removeMaterial(idx),
                      padding: EdgeInsets.zero,
                    ),
                  )),
                ]);
              }),
              ...labours.asMap().entries.map((entry) {
                int idx = entry.key;
                var l = entry.value;
                return DataRow(cells: [
                  const DataCell(SizedBox(
                      width: 80,
                      child: Text('Labour', style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text(l['type']?.toString() ?? '',
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('${l['count'] ?? 0}',
                          style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text(
                          _calculateLabourAmount(
                              l['type']?.toString() ?? '', l['count'] ?? 0),
                          style: TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(
                    width: 40,
                    child: IconButton(
                      icon:
                          Icon(Icons.delete, color: Colors.red[300], size: 16),
                      onPressed: () => _removeLabour(idx),
                      padding: EdgeInsets.zero,
                    ),
                  )),
                ]);
              }),
              DataRow(cells: [
                const DataCell(SizedBox(
                    width: 80,
                    child: Text('Food', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 100,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 60,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                DataCell(SizedBox(
                    width: 100,
                    child: Text('₹${foodCost.text}',
                        style: const TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(width: 40)),
              ]),
              DataRow(cells: [
                const DataCell(SizedBox(
                    width: 80,
                    child: Text('Transport', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 100,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 60,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                DataCell(SizedBox(
                    width: 100,
                    child: Text('₹${transportCost.text}',
                        style: const TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(width: 40)),
              ]),
              DataRow(cells: [
                const DataCell(SizedBox(
                    width: 80,
                    child: Text('Fuel', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 100,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(
                    width: 60,
                    child: Text('-', style: TextStyle(fontSize: 12)))),
                DataCell(SizedBox(
                    width: 100,
                    child: Text('₹${fuelCost.text}',
                        style: const TextStyle(fontSize: 12)))),
                const DataCell(SizedBox(width: 40)),
              ]),
              DataRow(cells: [
                const DataCell(SizedBox(width: 80, child: Text(''))),
                const DataCell(SizedBox(width: 100, child: Text(''))),
                const DataCell(SizedBox(
                    width: 60,
                    child: Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)))),
                DataCell(SizedBox(
                    width: 100,
                    child: Text('₹${_getTotalAmount()}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _primaryColor)))),
                const DataCell(SizedBox(width: 40, child: Text(''))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: const Text('Contractor Entry',
            style: TextStyle()),
        iconTheme: const IconThemeData(),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Section 1: Inputs (Site ID + Supervisor Name + Contractor Name + Project Field + Date)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Contractor Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: _primaryColor)),
                    const SizedBox(height: 12),

                    // Display Site ID
                    Text('Site ID: $siteCode',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),

                    // Display Supervisor Name
                    Text('Supervisor Name: ${widget.supervisorName}',
                        style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),

                    // Contractor Name Dropdown
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('contractors')
                          .orderBy('contractorName')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final names = <String>[];
                        final fieldByName = <String, String>{};
                        for (final d in docs) {
                          final data = d.data();
                          final name =
                              (data['contractorName'] ?? '').toString();
                          final field =
                              (data['contractorField'] ?? '').toString();
                          if (name.isNotEmpty) {
                            names.add(name);
                            fieldByName[name] = field;
                          }
                        }
                        final value = names.contains(_selectedContractorName)
                            ? _selectedContractorName
                            : null;
                        return DropdownButtonFormField<String>(
                          value: value,
                          items: names
                              .map((n) => DropdownMenuItem<String>(
                                  value: n, child: Text(n)))
                              .toList(),
                          onChanged: (val) => setState(() {
                            _selectedContractorName = val;
                            _selectedProjectField =
                                val != null ? (fieldByName[val] ?? '') : null;
                            _projectFieldController.text =
                                _selectedProjectField ?? '';
                            _contractorNameController.text = val ?? '';
                          }),
                          decoration: InputDecoration(
                            labelText: 'Contractor Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 12),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      controller: _projectFieldController,
                      decoration: InputDecoration(
                        labelText: 'Project Field',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      controller: _dateController,
                      onTap: _pickDate,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        suffixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section 2: Only Add Entry details below
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Add Entry',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 16),

                  // Material Section
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Material Details'),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: isLoadingMaterials
                                        ? const Center(
                                            child: CircularProgressIndicator())
                                        : materialError != null
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Text(materialError!,
                                                    style: const TextStyle(
                                                        color: Colors.red)))
                                            : Column(
                                                children: [
                                                  TextField(
                                                    decoration:
                                                        const InputDecoration(
                                                      hintText:
                                                          'Search Material...',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 12),
                                                    ),
                                                    onChanged: (query) {
                                                      setState(() {
                                                        final q =
                                                            query.toLowerCase();
                                                        final filtered =
                                                            materialOptions
                                                                .where((item) => item
                                                                    .toLowerCase()
                                                                    .startsWith(
                                                                        q))
                                                                .toList();
                                                        filtered.sort((a, b) => a
                                                            .toLowerCase()
                                                            .compareTo(b
                                                                .toLowerCase()));
                                                        if (filtered
                                                            .isNotEmpty) {
                                                          selectedMaterial =
                                                              filtered.contains(
                                                                      selectedMaterial)
                                                                  ? selectedMaterial
                                                                  : filtered
                                                                      .first;
                                                        } else {
                                                          selectedMaterial =
                                                              null;
                                                        }
                                                        _filteredMaterialOptions =
                                                            filtered;
                                                      });
                                                    },
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<
                                                      String>(
                                                    value: selectedMaterial,
                                                    isExpanded: true,
                                                    decoration: InputDecoration(
                                                      labelText: 'Material',
                                                      prefixIcon: const Icon(Icons
                                                          .category_outlined),
                                                      border:
                                                          OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              vertical: 8,
                                                              horizontal: 12),
                                                    ),
                                                    items: (_filteredMaterialOptions ??
                                                            materialOptions)
                                                        .map((item) => DropdownMenuItem(
                                                            value: item,
                                                            child: Text(item,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis)))
                                                        .toList(),
                                                    onChanged: (value) =>
                                                        setState(() =>
                                                            selectedMaterial =
                                                                value),
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
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 12),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() =>
                                          materialQty =
                                              int.tryParse(value) ?? 0),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed:
                                  isLoadingMaterials || materialOptions.isEmpty
                                      ? null
                                      : _addMaterial,
                              label: const Text('Add',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Toggle custom material fields
                          ElevatedButton(
                            onPressed: () => setState(() =>
                                _showCustomMaterialFields =
                                    !_showCustomMaterialFields),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Add Materials'),
                          ),
                          const SizedBox(height: 8),

                          if (_showCustomMaterialFields) ...[
                            TextField(
                              controller: _customMaterialNameController,
                              decoration: const InputDecoration(
                                labelText: 'Material Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customMaterialQtyController,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _customMaterialPriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Price (₹)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addCustomMaterial,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white),
                                    child: const Text('Add Material'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() =>
                                        _showCustomMaterialFields = false),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.black),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Labour Section
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Labour Details'),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: isLoadingLabours
                                        ? const Center(
                                            child: CircularProgressIndicator())
                                        : labourError != null
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Text(labourError!,
                                                    style: const TextStyle(
                                                        color: Colors.red)))
                                            : Column(
                                                children: [
                                                  TextField(
                                                    decoration:
                                                        const InputDecoration(
                                                      hintText:
                                                          'Search Labour...',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 12),
                                                    ),
                                                    onChanged: (query) {
                                                      setState(() {
                                                        final q =
                                                            query.toLowerCase();
                                                        final filtered = labourOptions
                                                            .where((item) => item
                                                                .toLowerCase()
                                                                .startsWith(q))
                                                            .toList();
                                                        filtered.sort((a, b) => a
                                                            .toLowerCase()
                                                            .compareTo(b
                                                                .toLowerCase()));
                                                        if (filtered
                                                            .isNotEmpty) {
                                                          selectedLabour =
                                                              filtered.contains(
                                                                      selectedLabour)
                                                                  ? selectedLabour
                                                                  : filtered
                                                                      .first;
                                                        } else {
                                                          selectedLabour = null;
                                                        }
                                                        _filteredLabourOptions =
                                                            filtered;
                                                      });
                                                    },
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<
                                                      String>(
                                                    value: selectedLabour,
                                                    isExpanded: true,
                                                    decoration: InputDecoration(
                                                      labelText: 'Labour',
                                                      prefixIcon: const Icon(
                                                          Icons.group),
                                                      border:
                                                          OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              vertical: 8,
                                                              horizontal: 12),
                                                    ),
                                                    items: (_filteredLabourOptions ??
                                                            labourOptions)
                                                        .map((item) => DropdownMenuItem(
                                                            value: item,
                                                            child: Text(item,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis)))
                                                        .toList(),
                                                    onChanged: (value) =>
                                                        setState(() =>
                                                            selectedLabour =
                                                                value),
                                                  ),
                                                ],
                                              ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: labourQtyController,
                                      decoration: InputDecoration(
                                        labelText: 'Count',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 12),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => setState(() =>
                                          labourQty = int.tryParse(value) ?? 0),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed:
                                  isLoadingLabours || labourOptions.isEmpty
                                      ? null
                                      : _addLabour,
                              label: const Text('Add',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Toggle custom labour fields
                          ElevatedButton(
                            onPressed: () => setState(() =>
                                _showCustomLabourFields =
                                    !_showCustomLabourFields),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Add Labour'),
                          ),
                          const SizedBox(height: 8),

                          if (_showCustomLabourFields) ...[
                            TextField(
                              controller: _customLabourNameController,
                              decoration: const InputDecoration(
                                labelText: 'Labour Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customLabourSalaryController,
                              decoration: const InputDecoration(
                                labelText: 'Salary',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: labourQtyController,
                              decoration: const InputDecoration(
                                labelText: 'Count',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => setState(
                                  () => labourQty = int.tryParse(value) ?? 0),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addCustomLabour,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white),
                                    child: const Text('Add Labour'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(
                                        () => _showCustomLabourFields = false),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.black),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Additional Costs Section
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Additional Costs'),
                          const SizedBox(height: 12),
                          _buildCostInput(
                              'Food Cost', foodCost, Icons.fastfood),
                          const SizedBox(height: 8),
                          _buildCostInput('Transport Cost', transportCost,
                              Icons.directions_car),
                          const SizedBox(height: 8),
                          _buildCostInput(
                              'Fuel Cost', fuelCost, Icons.local_gas_station),
                        ],
                      ),
                    ),
                  ),

                  // Summary Section
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('Summary'),
                              Text('Total: ₹${_getTotalAmount()}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryTable(),
                        ],
                      ),
                    ),
                  ),

                  // Save Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, ))
                          : const Text('Save Entry',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
