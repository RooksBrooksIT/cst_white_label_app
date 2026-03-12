import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:demo_cst/screens/supervisor_dashboard.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:intl/intl.dart';

class SiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  const SiteEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<SiteEntryPage> createState() => _SiteEntryPageState();
}

class _SiteEntryPageState extends State<SiteEntryPage> {
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
  String siteLocation = '';
  List<Map<String, String>> supervisorSites = [];
  String? selectedSiteId;
  bool isSaving = false;
  Map<String, num> materialPrices = {};
  Map<String, num> labourSalaries = {};

  // Project Phase dropdown state
  List<String> projectPhases = [];
  String? selectedProjectPhase;
  bool isLoadingProjectPhases = true;
  String? projectPhaseError;

  // State for custom materials/labours UI
  bool _showCustomMaterialFields = false;
  final TextEditingController _customMaterialNameController =
      TextEditingController();
  final TextEditingController _customMaterialQtyController =
      TextEditingController(text: '0');
  final TextEditingController _customMaterialPriceController =
      TextEditingController(text: '0');

  bool _showCustomLabourFields = false;
  final TextEditingController _customLabourNameController =
      TextEditingController();
  final TextEditingController _customLabourSalaryController =
      TextEditingController(text: '0');

  final Color mainColor = const Color(0xFF0B3470);

  @override
  void initState() {
    super.initState();
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSupervisorData();
    _fetchProjectPhases();
  }

  Future<void> _fetchProjectPhases() async {
    setState(() {
      isLoadingProjectPhases = true;
      projectPhaseError = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .get();
      final phases = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('projectStage')) {
          final phase = data['projectStage']?.toString() ?? '';
          if (phase.isNotEmpty) {
            phases.add(phase);
          }
        }
      }
      setState(() {
        projectPhases = phases;
        selectedProjectPhase = projectPhases.isNotEmpty
            ? projectPhases.first
            : null;
        isLoadingProjectPhases = false;
      });
    } catch (e) {
      setState(() {
        projectPhaseError = 'Failed to load project phases';
        isLoadingProjectPhases = false;
      });
    }
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
            selectedProjectPhase = sites.first['projectStage']!.isNotEmpty
                ? sites.first['projectStage']
                : (projectPhases.isNotEmpty ? projectPhases.first : null);
          } else {
            selectedSiteId = null;
            siteCode = '';
            siteLocation = 'Unknown';
            supervisorId = 'Not found';
            projectName = 'Not found';
            selectedProjectPhase = null;
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
          selectedProjectPhase = null;
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
        selectedProjectPhase = null;
      });
    }
  }

  Future<void> _fetchMaterialOptions() async {
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('materials')
          .get();
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
        selectedMaterial = materialOptions.isNotEmpty
            ? materialOptions.first
            : null;
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
      final snapshot = await FirebaseFirestore.instance
          .collection('labours')
          .get();
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

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: mainColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: mainColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
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

  void _removeMaterial(int index) {
    setState(() {
      materials.removeAt(index);
    });
  }

  void _removeLabour(int index) {
    setState(() {
      labours.removeAt(index);
    });
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

  Future<void> _saveToFirestore() async {
    if (siteCode.isEmpty ||
        selectedDate == null ||
        supervisorId == null ||
        supervisorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing site code, date, or supervisor ID!'),
        ),
      );
      return;
    }
    setState(() {
      isSaving = true;
    });
    final dateForId = DateFormat('ddMMyyyy').format(selectedDate!);
    final docId = '${siteCode}_$dateForId';
    final dateIso = selectedDate!.toIso8601String();
    final data = {
      "date": dateIso,
      "food": int.tryParse(foodCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "labours": labours
          .map(
            (l) => {
              "type": l['type'] ?? '',
              "count": l['count'] ?? 0,
              "unitSalary": labourSalaries[l['type'] ?? ''] ?? 0,
              "amount":
                  (labourSalaries[l['type'] ?? ''] ?? 0) * (l['count'] ?? 0),
            },
          )
          .toList(),
      "materials": materials
          .map(
            (m) => {
              "type": m['type'] ?? '',
              "quantity": m['quantity'] ?? 0,
              "unitPrice": materialPrices[m['type'] ?? ''] ?? 0,
              "amount":
                  (materialPrices[m['type'] ?? ''] ?? 0) * (m['quantity'] ?? 0),
            },
          )
          .toList(),
      "supervisorId": supervisorId ?? '',
      "supervisorName": widget.userName,
      "projectStage": selectedProjectPhase ?? '',
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
      "siteLocation": siteLocation,
      "siteId": siteCode,
    };
    try {
      // Check for existing entry for this site and date
      final existing = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .doc(docId)
          .get();
      if (existing.exists) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Entry'),
            content: const Text(
              'Your entry for this date has already been submitted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          isSaving = false;
        });
        return;
      }
      await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .doc(docId)
          .set(data);
      // Update total site expense aggregation
      await ExpenseService.updateTotalSiteExpense(siteCode);
      // --- Update siteSupervisorProjectStageActual collection ---
      final actualColl = FirebaseFirestore.instance.collection(
        'siteSupervisorProjectStageActual',
      );
      final actualDocId =
          '${siteCode}_${widget.userName}_${selectedProjectPhase ?? ''}';
      final actualDoc = await actualColl.doc(actualDocId).get();
      List<Map<String, dynamic>> actLabours = labours
          .map(
            (l) => {
              "labourCount": l['count'] ?? 0,
              "labourDesignation": l['type'] ?? '',
            },
          )
          .toList();
      final actualData = {
        "actLabours": actLabours,
        "actPayment": _getTotalAmount(),
        "projectName": projectName ?? '',
        "projectStage": selectedProjectPhase ?? '',
        "siteId": siteCode,
        "supervisorName": widget.userName,
      };
      if (actualDoc.exists) {
        int prevDays = (actualDoc.data()?['actDays'] ?? 0) as int;
        await actualColl.doc(actualDocId).update({
          ...actualData,
          "actDays": prevDays + 1,
        });
      } else {
        await actualColl.doc(actualDocId).set({...actualData, "actDays": 1});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save entry: $e')));
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: mainColor,
      ),
    );
  }

  Widget _buildCostInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: mainColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: mainColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: mainColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      cursorColor: mainColor,
      style: const TextStyle(color: Colors.black87),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSummaryTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowHeight: 40,
            dataRowHeight: 40,
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              DataColumn(label: SizedBox(width: 40)),
            ],
            rows: [
              ...materials.asMap().entries.map((entry) {
                int idx = entry.key;
                var m = entry.value;
                return DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Material', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          m['type']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${m['quantity'] ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          _calculateMaterialAmount(
                            m['type']?.toString() ?? '',
                            m['quantity'] ?? 0,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[300],
                            size: 16,
                          ),
                          onPressed: () => _removeMaterial(idx),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              ...labours.asMap().entries.map((entry) {
                int idx = entry.key;
                var l = entry.value;
                return DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Labour', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          l['type']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${l['count'] ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          _calculateLabourAmount(
                            l['type']?.toString() ?? '',
                            l['count'] ?? 0,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[300],
                            size: 16,
                          ),
                          onPressed: () => _removeLabour(idx),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              DataRow(
                cells: [
                  const DataCell(
                    SizedBox(
                      width: 80,
                      child: Text('Food', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${foodCost.text}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(
                    SizedBox(
                      width: 80,
                      child: Text('Transport', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${transportCost.text}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(
                    SizedBox(
                      width: 80,
                      child: Text('Fuel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const DataCell(
                    SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${fuelCost.text}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(SizedBox(width: 80, child: Text(''))),
                  const DataCell(SizedBox(width: 100, child: Text(''))),
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${_getTotalAmount()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: mainColor,
                        ),
                      ),
                    ),
                  ),
                  const DataCell(SizedBox(width: 40, child: Text(''))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(_customMaterialPriceController.text) ?? 0;
    if (name.isNotEmpty && qty > 0 && price > 0) {
      setState(() {
        materials.add({'type': name, 'quantity': qty});
        materialPrices[name] = price;
        _customMaterialNameController.clear();
        _customMaterialQtyController.text = '0';
        _customMaterialPriceController.text = '0';
        _showCustomMaterialFields = false;
      });
    }
  }

  void _addCustomLabour() {
    final name = _customLabourNameController.text.trim();
    final salary = num.tryParse(_customLabourSalaryController.text) ?? 0;
    final count = int.tryParse(labourQtyController.text) ?? 0;
    if (name.isNotEmpty && salary > 0 && count > 0) {
      setState(() {
        labours.add({'type': name, 'count': count});
        labourSalaries[name] = salary;
        _customLabourNameController.clear();
        _customLabourSalaryController.text = '0';
        labourQtyController.text = '0';
        _showCustomLabourFields = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupervisorDashboard(
                  username: widget.userName,
                  supervisorId: '',
                  supervisorName: '',
                ),
              ),
            );
          },
          child: const Text(
            'Daily Site Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
        backgroundColor: mainColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 12.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                                  color: mainColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedSiteId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Site Id (Supervisor Only)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                    ),
                                    iconEnabledColor: mainColor,
                                    items: supervisorSites
                                        .map(
                                          (site) => DropdownMenuItem(
                                            value: site['siteId'],
                                            child: Text(
                                              site['siteId'] ?? '',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: supervisorSites.isEmpty
                                        ? null
                                        : (value) {
                                            final selected = supervisorSites
                                                .firstWhere(
                                                  (site) =>
                                                      site['siteId'] == value,
                                                  orElse: () => {
                                                    'siteId': '',
                                                    'location': 'Unknown',
                                                    'supervisorId': '',
                                                    'projectStage': '',
                                                  },
                                                );
                                            setState(() {
                                              selectedSiteId = value;
                                              siteCode =
                                                  selected['siteId'] ?? '';
                                              siteLocation =
                                                  selected['location'] ??
                                                  'Unknown';
                                              supervisorId =
                                                  selected['supervisorId'] ??
                                                  '';
                                              projectName =
                                                  selected['projectName'] ??
                                                  'Not found';
                                              selectedProjectPhase =
                                                  selected['projectStage']!
                                                      .isNotEmpty
                                                  ? selected['projectStage']
                                                  : (projectPhases.isNotEmpty
                                                        ? projectPhases.first
                                                        : null);
                                            });
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, size: 20, color: mainColor),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Supervisor: ${widget.userName}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (supervisorId != null &&
                                          supervisorId!.isNotEmpty)
                                        Text(
                                          'ID: $supervisorId',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: mainColor,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Project Name: $projectName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: mainColor,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Location: $siteLocation',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.layers, size: 20, color: mainColor),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Project Stage: ${selectedProjectPhase ?? "Not selected"}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: mainColor,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    selectedDate != null
                                        ? '${selectedDate!.toLocal()}'.split(
                                            ' ',
                                          )[0]
                                        : 'No date chosen',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _pickDate,
                                  icon: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: mainColor,
                                  ),
                                  label: Text(
                                    'Change',
                                    style: TextStyle(color: mainColor),
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
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Add Entry',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ),
                    Divider(height: 16, thickness: 2, color: mainColor),
                    // Material Details Card
                    Card(
                      elevation: 1,
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
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                TextField(
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Search Material...',
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 12,
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
                                                      color: mainColor,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    filled: true,
                                                    fillColor:
                                                        Colors.grey.shade50,
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 12,
                                                        ),
                                                  ),
                                                  iconEnabledColor: mainColor,
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
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
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
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCustomMaterialFields =
                                      !_showCustomMaterialFields;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Others'),
                            ),
                            if (_showCustomMaterialFields) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customMaterialNameController,
                                decoration: InputDecoration(
                                  labelText: 'Material Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customMaterialQtyController,
                                      decoration: InputDecoration(
                                        labelText: 'Qty',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _customMaterialPriceController,
                                      decoration: InputDecoration(
                                        labelText: 'Unit Price (₹)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
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
                                        backgroundColor: mainColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Add Material'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showCustomMaterialFields = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.black,
                                      ),
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
                    // Labour Details Card similar styling applied
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : labourError != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                labourError!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                TextField(
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Search Labour...',
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 12,
                                                        ),
                                                  ),
                                                  onChanged: (query) {
                                                    setState(() {
                                                      final q = query
                                                          .toLowerCase();
                                                      final filtered =
                                                          labourOptions
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
                                                        selectedLabour =
                                                            filtered.contains(
                                                              selectedLabour,
                                                            )
                                                            ? selectedLabour
                                                            : filtered.first;
                                                      } else {
                                                        selectedLabour = null;
                                                      }
                                                      _filteredLabourOptions =
                                                          filtered;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                DropdownButtonFormField<String>(
                                                  value: selectedLabour,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    labelText: 'Labour',
                                                    prefixIcon: Icon(
                                                      Icons.group,
                                                      color: mainColor,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    filled: true,
                                                    fillColor:
                                                        Colors.grey.shade50,
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 12,
                                                        ),
                                                  ),
                                                  iconEnabledColor: mainColor,
                                                  items:
                                                      (_filteredLabourOptions ??
                                                              labourOptions)
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
                                                        () => selectedLabour =
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
                                        controller: labourQtyController,
                                        decoration: InputDecoration(
                                          labelText: 'Count',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 12,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            labourQty =
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed:
                                    isLoadingLabours || labourOptions.isEmpty
                                    ? null
                                    : _addLabour,
                                label: const Text(
                                  'Add Labour',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCustomLabourFields =
                                      !_showCustomLabourFields;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Others'),
                            ),
                            if (_showCustomLabourFields) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customLabourNameController,
                                decoration: InputDecoration(
                                  labelText: 'Labour Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customLabourSalaryController,
                                decoration: InputDecoration(
                                  labelText: 'Salary',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: labourQtyController,
                                decoration: InputDecoration(
                                  labelText: 'Count',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    labourQty = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _addCustomLabour,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: mainColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Add Labour'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showCustomLabourFields = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.black,
                                      ),
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
                    // Additional Costs Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader('Additional Costs'),
                            const SizedBox(height: 12),
                            _buildCostInput(
                              'Food Cost',
                              foodCost,
                              Icons.fastfood,
                            ),
                            const SizedBox(height: 8),
                            _buildCostInput(
                              'Transport Cost',
                              transportCost,
                              Icons.directions_car,
                            ),
                            const SizedBox(height: 8),
                            _buildCostInput(
                              'Fuel Cost',
                              fuelCost,
                              Icons.local_gas_station,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Today's Summary Header & Table
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildSectionHeader('Today\'s Summary'),
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryTable(),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  materials.clear();
                                  labours.clear();
                                  selectedMaterial = materialOptions.isNotEmpty
                                      ? materialOptions.first
                                      : null;
                                  selectedLabour = labourOptions.isNotEmpty
                                      ? labourOptions.first
                                      : null;
                                  materialQty = 0;
                                  materialQtyController.text = '0';
                                  labourQty = 0;
                                  labourQtyController.text = '0';
                                  foodCost.text = '0';
                                  transportCost.text = '0';
                                  fuelCost.text = '0';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(color: mainColor, width: 2),
                                foregroundColor: mainColor,
                              ),
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : _saveToFirestore,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Entry',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
