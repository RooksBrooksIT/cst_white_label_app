import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import 'supervisor_dashboard.dart';

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
  final materialSearchController = TextEditingController();
  final labourSearchController = TextEditingController();
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
      final snapshot = await FirestoreService.getCollection(
        'projectStages',
      ).get();
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
      final snapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('supervisor', isEqualTo: widget.userName).get();
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
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
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
      final existing = await FirestoreService.getCollection(
        'siteSupervisorEntries',
      ).doc(docId).get();
      if (existing.exists) {
        if (!mounted) return;
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
      await FirestoreService.getCollection(
        'siteSupervisorEntries',
      ).doc(docId).set(data);
      // Update total site expense aggregation
      await ExpenseService.updateTotalSiteExpense(siteCode);
      // --- Update siteSupervisorProjectStageActual collection ---
      final actualColl = FirestoreService.getCollection(
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
        if (!mounted) return;
        await actualColl.doc(actualDocId).update({
          ...actualData,
          "actDays": prevDays + 1,
        });
      } else {
        if (!mounted) return;
        await actualColl.doc(actualDocId).set({...actualData, "actDays": 1});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved successfully!')),
      );

      // Notify the organisation about the daily site report
      await NotificationService.notifyOrganisation(
        title: '📝 Daily Site Report Submitted',
        body: '${widget.userName} submitted a daily report for $siteCode.',
        data: {
          'type': 'site_entry',
          'siteId': siteCode,
          'supervisorName': widget.userName,
          'date': dateForId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save entry: $e')));
    } finally {
      if (!mounted) return;
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
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildCostInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 20, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      cursorColor: colorScheme.primary,
      style: TextStyle(color: colorScheme.onSurface),
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
                          color: Theme.of(context).primaryColor,
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

  Widget _buildInfoRow(IconData icon, String value, {String? subValue}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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
    materialSearchController.dispose();
    labourSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Daily Site Entry',
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
                  supervisorId: supervisorId ?? '',
                  supervisorName: widget.userName,
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
            padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 800,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.construction,
                                size: 22,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedSiteId,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Site Id (Supervisor Only)',
                                    labelStyle: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                  ),
                                  iconEnabledColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
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
                                            siteCode = selected['siteId'] ?? '';
                                            siteLocation =
                                                selected['location'] ??
                                                'Unknown';
                                            supervisorId =
                                                selected['supervisorId'] ?? '';
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
                          const SizedBox(height: 20),
                          _buildInfoRow(
                            Icons.person,
                            'Supervisor: ${widget.userName}',
                            subValue: supervisorId != null
                                ? 'ID: $supervisorId'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.business,
                            'Project: $projectName',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.location_on,
                            'Location: $siteLocation',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.layers,
                            'Stage: ${selectedProjectPhase ?? "Not selected"}',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDate != null
                                      ? DateFormat(
                                          'EEEE, MMM d, yyyy',
                                        ).format(selectedDate!)
                                      : 'No date chosen',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Change'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Add Entry',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),

                    // Material Details Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Material Details'),
                          const SizedBox(height: 16),
                          isLoadingMaterials
                              ? const Center(child: CircularProgressIndicator())
                              : materialError != null
                              ? Text(
                                  materialError!,
                                  style: const TextStyle(color: Colors.red),
                                )
                              : Column(
                                  children: [
                                    GlassTextField(
                                      controller: materialSearchController,
                                      label: 'Search Material...',
                                      icon: Icons.search,
                                      onChanged: (query) {
                                        setState(() {
                                          final q = query.toLowerCase();
                                          final filtered = materialOptions
                                              .where(
                                                (item) => item
                                                    .toLowerCase()
                                                    .startsWith(q),
                                              )
                                              .toList();
                                          filtered.sort(
                                            (a, b) => a.toLowerCase().compareTo(
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
                                          _filteredMaterialOptions = filtered;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: selectedMaterial,
                                      isExpanded: true,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Material',
                                        labelStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.category_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.5),
                                      ),
                                      iconEnabledColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      items:
                                          (_filteredMaterialOptions ??
                                                  materialOptions)
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item,
                                                  child: Text(
                                                    item,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) => setState(
                                        () => selectedMaterial = value,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: GlassTextField(
                                  controller: materialQtyController,
                                  label: 'Qty',
                                  icon: Icons.production_quantity_limits,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => setState(
                                    () =>
                                        materialQty = int.tryParse(value) ?? 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: 'Add',
                                  onPressed:
                                      isLoadingMaterials ||
                                          materialOptions.isEmpty
                                      ? null
                                      : _addMaterial,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(
                              () => _showCustomMaterialFields =
                                  !_showCustomMaterialFields,
                            ),
                            child: Text(
                              _showCustomMaterialFields
                                  ? 'Hide Others'
                                  : 'Show Others',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          if (_showCustomMaterialFields) ...[
                            const SizedBox(height: 12),
                            GlassTextField(
                              controller: _customMaterialNameController,
                              label: 'Material Name',
                              icon: Icons.edit,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassTextField(
                                    controller: _customMaterialQtyController,
                                    label: 'Qty',
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassTextField(
                                    controller: _customMaterialPriceController,
                                    label: 'Price (₹)',
                                    icon: Icons.payments,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassButton(
                                    label: 'Add Custom',
                                    onPressed: _addCustomMaterial,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassButton(
                                    label: 'Cancel',
                                    isSecondary: true,
                                    onPressed: () => setState(
                                      () => _showCustomMaterialFields = false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Labour Details Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Labour Details'),
                          const SizedBox(height: 16),
                          isLoadingLabours
                              ? const Center(child: CircularProgressIndicator())
                              : labourError != null
                              ? Text(
                                  labourError!,
                                  style: const TextStyle(color: Colors.red),
                                )
                              : Column(
                                  children: [
                                    GlassTextField(
                                      controller: labourSearchController,
                                      label: 'Search Labour...',
                                      icon: Icons.search,
                                      onChanged: (query) {
                                        setState(() {
                                          final q = query.toLowerCase();
                                          final filtered = labourOptions
                                              .where(
                                                (item) => item
                                                    .toLowerCase()
                                                    .startsWith(q),
                                              )
                                              .toList();
                                          filtered.sort(
                                            (a, b) => a.toLowerCase().compareTo(
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
                                          _filteredLabourOptions = filtered;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: selectedLabour,
                                      isExpanded: true,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Labour Type',
                                        labelStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.group,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.5),
                                      ),
                                      iconEnabledColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      items:
                                          (_filteredLabourOptions ??
                                                  labourOptions)
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item,
                                                  child: Text(
                                                    item,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) => setState(
                                        () => selectedLabour = value,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: GlassTextField(
                                  controller: labourQtyController,
                                  label: 'Count',
                                  icon: Icons.person_add,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => setState(
                                    () => labourQty = int.tryParse(value) ?? 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: 'Add',
                                  onPressed:
                                      isLoadingLabours || labourOptions.isEmpty
                                      ? null
                                      : _addLabour,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(
                              () => _showCustomLabourFields =
                                  !_showCustomLabourFields,
                            ),
                            child: Text(
                              _showCustomLabourFields
                                  ? 'Hide Others'
                                  : 'Show Others',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          if (_showCustomLabourFields) ...[
                            const SizedBox(height: 12),
                            GlassTextField(
                              controller: _customLabourNameController,
                              label: 'Labour Type Name',
                              icon: Icons.edit,
                            ),
                            const SizedBox(height: 12),
                            GlassTextField(
                              controller: _customLabourSalaryController,
                              label: 'Daily Salary (₹)',
                              icon: Icons.payments,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassButton(
                                    label: 'Add Custom',
                                    onPressed: _addCustomLabour,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassButton(
                                    label: 'Cancel',
                                    isSecondary: true,
                                    onPressed: () => setState(
                                      () => _showCustomLabourFields = false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Additional Costs Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Additional Costs'),
                          const SizedBox(height: 16),
                          _buildCostInput(
                            'Food Cost',
                            foodCost,
                            Icons.fastfood,
                          ),
                          const SizedBox(height: 12),
                          _buildCostInput(
                            'Transport Cost',
                            transportCost,
                            Icons.directions_car,
                          ),
                          const SizedBox(height: 12),
                          _buildCostInput(
                            'Fuel Cost',
                            fuelCost,
                            Icons.local_gas_station,
                          ),
                        ],
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
                            child: GlassButton(
                              label: 'Reset',
                              isSecondary: true,
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
                                  materialSearchController.clear();
                                  labourSearchController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: isSaving
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : GlassButton(
                                    label: 'Save Entry',
                                    onPressed: _saveToFirestore,
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
