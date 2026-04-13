import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'supervisor_dashboard.dart';
import '../services/expense_service.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

class OrganizationSiteEntry extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  const OrganizationSiteEntry({
    super.key,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<OrganizationSiteEntry> createState() => _OrganizationSiteEntryState();
}

class _OrganizationSiteEntryState extends State<OrganizationSiteEntry> {
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
    setState(() {
      isLoadingSites = true;
    });
    try {
      // 1. Fetch site names from the master Site collection
      final sitesSnapshot = await FirestoreService.sites.get();
      final Map<String, String> siteNames = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site'
      };

      // 2. Fetch site mappings using FirestoreService
      final snapshot = await FirestoreService.siteSupervisorMap.get();

      siteList = snapshot.docs
          .map((doc) {
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
          })
          .where((site) => site['siteId']!.isNotEmpty)
          .toList();

      if (siteList.isNotEmpty) {
        selectedSiteId = siteList.first['siteId'];
        _onSiteSelected(selectedSiteId!);
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingSites = false;
      });
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere(
      (s) => s['siteId'] == siteId,
      orElse: () => {
        'siteId': '',
        'supervisor': '',
        'supervisorId': '',
        'location': '',
        'projectStage': '',
      },
    );
    setState(() {
      selectedSiteId = siteId;
      siteCode = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId']?.isNotEmpty == true
          ? site['supervisorId']
          : 'Not Available';
      siteLocation = site['location'];
      projectStage = site['projectStage'];
    });
  }

  Future<void> _fetchMaterialOptions() async {
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
        if (data.containsKey('materialName')) {
          final name = data['materialName']?.toString() ?? '';
          if (name.isNotEmpty) {
            options.add(name);
            final priceRaw = data['materialPrice'];
            num price = 0;

            if (priceRaw is num) {
              price = priceRaw;
            } else if (priceRaw is String) {
              final cleanPrice = priceRaw.replaceAll(RegExp(r'[^\d.]'), '');
              price = num.tryParse(cleanPrice) ?? 0;
            }
            prices[name] = price;
          }
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
      if (!mounted) return;
      setState(() {
        materialError = 'Failed to load materials: $e';
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
      final snapshot = await FirestoreService.labours.get();
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
              final cleanSalary = salaryRaw.replaceAll(RegExp(r'[^\d.]'), '');
              salary = num.tryParse(cleanSalary) ?? 0;
            }
            salaries[designation] = salary;
          }
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
      if (!mounted) return;
      setState(() {
        labourError = 'Failed to load labours: $e';
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
        labourQty = 0;
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

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      materialQtyController.text = '0';
      labourQtyController.text = '0';
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _customLabourNameController.clear();
      _customLabourSalaryController.text = '0';
      _showCustomMaterialFields = false;
      _showCustomLabourFields = false;
      if (materialOptions.isNotEmpty) {
        selectedMaterial = materialOptions.first;
      }
      if (labourOptions.isNotEmpty) {
        selectedLabour = labourOptions.first;
      }
    });
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Entry'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Site: $siteCode'),
                Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}'),
                Text('Total Amount: ₹${_getTotalAmount()}'),
                const SizedBox(height: 16),
                const Text('Are you sure you want to save this entry?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                _saveToFirestore();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToFirestore() async {
    if (siteCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site.')));
      return;
    }
    if (selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date.')));
      return;
    }
    if (supervisorName == null || supervisorName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supervisor is missing for this site.')),
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
      "Supervisor ID": supervisorId ?? 'Not Available',
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
      "siteLocation": siteLocation,
      "siteId": siteCode,
      "supervisorName": supervisorName,
      "projectStage": projectStage,
    };
    try {
      final existing = await FirestoreService.siteSupervisorEntries
          .doc(docId)
          .get();
      if (existing.exists) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Entry'),
            content: const Text('This entry already exists in your records.'),
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
      await FirestoreService.siteSupervisorEntries.doc(docId).set(data);
      // Update total site expense aggregation
      await ExpenseService.updateTotalSiteExpense(siteCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved successfully!')),
      );
      _resetForm();
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
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        prefixIcon: Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
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
                        height: 40,
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
                        height: 40,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassScaffold(
      title: 'Organiser Daily Site Entry',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => SupervisorDashboard(
                      username: widget.userName,
                      supervisorId: supervisorId ?? '',
                      supervisorName: supervisorName ?? '',
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
                  maxWidth: 800,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Site info card
                    GlassCard(
                      title: 'Site Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isLoadingSites
                              ? const Center(child: CircularProgressIndicator())
                              : DropdownButtonFormField<String>(
                                  value: selectedSiteId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Site ID',
                                    prefixIcon: Icon(
                                      Icons.construction,
                                      color: theme.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                  items: siteList
                                      .map(
                                        (site) => DropdownMenuItem(
                                          value: site['siteId'],
                                          child: Text(
                                            '${site['siteId']} - ${site['siteName']}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
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
                          const SizedBox(height: 16),
                          _buildModernInfoRow(
                            Icons.person,
                            'Supervisor',
                            '${supervisorName ?? '-'} (${supervisorId ?? '-'})',
                            theme,
                          ),
                          _buildModernInfoRow(
                            Icons.location_on,
                            'Location',
                            siteLocation ?? '-',
                            theme,
                          ),
                          _buildModernInfoRow(
                            Icons.timeline,
                            'Project Stage',
                            projectStage ?? '-',
                            theme,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Date:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedDate != null
                                    ? DateFormat('dd MMM yyyy').format(selectedDate!)
                                    : 'No date chosen',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Change'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Material Details Card
                    GlassCard(
                      title: 'Material Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isLoadingMaterials)
                            const Center(child: CircularProgressIndicator())
                          else if (materialError != null)
                            Text(
                              materialError!,
                              style: const TextStyle(color: Colors.red),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: selectedMaterial,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Material',
                                prefixIcon: Icon(
                                  Icons.category_outlined,
                                  color: theme.primaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                              ),
                              items: (_filteredMaterialOptions ?? materialOptions)
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedMaterial = value),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: materialQtyController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  materialQty = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassButton(
                                    label: 'Add Material',
                                    icon: Icons.add,
                                    onPressed: materialOptions.isEmpty
                                        ? null
                                        : _addMaterial,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassButton(
                                    label:
                                        _showCustomMaterialFields
                                            ? 'Hide Others'
                                            : 'Others',
                                    icon: Icons.more_horiz,
                                    onPressed: () => setState(
                                      () =>
                                          _showCustomMaterialFields =
                                              !_showCustomMaterialFields,
                                    ),
                                    isSecondary: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_showCustomMaterialFields) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        title: 'Custom Material',
                        child: Column(
                          children: [
                            TextField(
                              controller: _customMaterialNameController,
                              decoration: const InputDecoration(
                                labelText: 'Material Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customMaterialQtyController,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      border: OutlineInputBorder(),
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
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GlassButton(
                              label: 'Add Custom',
                              icon: Icons.playlist_add,
                              onPressed: _addCustomMaterial,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Labour Details Card
                    GlassCard(
                      title: 'Labour Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isLoadingLabours)
                            const Center(child: CircularProgressIndicator())
                          else if (labourError != null)
                            Text(
                              labourError!,
                              style: const TextStyle(color: Colors.red),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: selectedLabour,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Labour',
                                prefixIcon: Icon(
                                  Icons.group,
                                  color: theme.primaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                              ),
                              items: (_filteredLabourOptions ?? labourOptions)
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedLabour = value),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: labourQtyController,
                              decoration: InputDecoration(
                                labelText: 'Count',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => setState(
                                () => labourQty = int.tryParse(value) ?? 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassButton(
                                    label: 'Add Labour',
                                    icon: Icons.person_add,
                                    onPressed: labourOptions.isEmpty
                                        ? null
                                        : _addLabour,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassButton(
                                    label:
                                        _showCustomLabourFields
                                            ? 'Hide Others'
                                            : 'Others',
                                    icon: Icons.more_horiz,
                                    onPressed: () => setState(
                                      () =>
                                          _showCustomLabourFields =
                                              !_showCustomLabourFields,
                                    ),
                                    isSecondary: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_showCustomLabourFields) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        title: 'Custom Labour',
                        child: Column(
                          children: [
                            TextField(
                              controller: _customLabourNameController,
                              decoration: const InputDecoration(
                                labelText: 'Designation Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _customLabourSalaryController,
                              decoration: const InputDecoration(
                                labelText: 'Salary (₹)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            GlassButton(
                              label: 'Add Custom',
                              icon: Icons.playlist_add,
                              onPressed: _addCustomLabour,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Additional Costs
                    GlassCard(
                      title: 'Additional Costs',
                      child: Column(
                        children: [
                          _buildCostInput(
                            'Food Cost',
                            foodCost,
                            Icons.restaurant,
                          ),
                          const SizedBox(height: 12),
                          _buildCostInput(
                            'Transport Cost',
                            transportCost,
                            Icons.local_shipping,
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

                    const SizedBox(height: 24),

                    // Summary Section
                    if (materials.isNotEmpty || labours.isNotEmpty) ...[
                      GlassCard(
                        title: 'Daily Summary',
                        child: _buildSummaryTable(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Reset',
                            icon: Icons.refresh,
                            onPressed: _resetForm,
                            isSecondary: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassButton(
                            label: 'Save Entry',
                            icon: Icons.save,
                            onPressed: isSaving
                                ? null
                                : _showConfirmationDialog,
                            isLoading: isSaving,
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

  Widget _buildModernInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.primaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
