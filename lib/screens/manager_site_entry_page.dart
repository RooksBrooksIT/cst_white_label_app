import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/supervisor_dashboard.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';


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
  List<Map<String, dynamic>> _existingEntries = [];
  DateTime? _selectedUpdateDate;

  // Color scheme
  final Color primaryColor = const Color(0xFF0b3470);
  final Color accentColor = const Color(0xFF4a7cda);
  final Color lightBackgroundColor = const Color(0xFFf5f7fa);
  final Color cardBackgroundColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
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
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
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
      setState(() {
        isLoadingSites = false;
      });
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
      // Reset update mode when switching site
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
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
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
        materials.add({
          'type': selectedMaterial!,
          'quantity': qty,
        });
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
        materials.add({
          'type': name,
          'quantity': qty,
        });
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
        labours.add({
          'type': selectedLabour!,
          'count': qty,
        });
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
        labours.add({
          'type': name,
          'count': qty,
        });
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
      // Exit update mode and clear selection
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Confirm Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Site: $siteCode',
                    style: TextStyle(color: textColor, fontSize: 16)),
                Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                    style: TextStyle(color: textColor, fontSize: 16)),
                Text('Total Amount: ₹${_getTotalAmount()}',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Are you sure you want to save this entry?',
                    style: TextStyle(color: textColor, fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: textColor,
                      ),
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _saveToFirestore();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveToFirestore() async {
    if (siteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a site.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a date.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    if (supervisorName == null || supervisorName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Supervisor is missing for this site.'),
          backgroundColor: errorColor,
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
          .map((l) => {
                "type": l['type'] ?? '',
                "count": l['count'] ?? 0,
                "unitSalary": labourSalaries[l['type'] ?? ''] ?? 0,
                "amount":
                    (labourSalaries[l['type'] ?? ''] ?? 0) * (l['count'] ?? 0),
              })
          .toList(),
      "materials": materials
          .map((m) => {
                "type": m['type'] ?? '',
                "quantity": m['quantity'] ?? 0,
                "unitPrice": materialPrices[m['type'] ?? ''] ?? 0,
                "amount": (materialPrices[m['type'] ?? ''] ?? 0) *
                    (m['quantity'] ?? 0),
              })
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
      final existing = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .doc(docId)
          .get();
      if (existing.exists) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 40, color: warningColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Duplicate Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('This entry already exists in your records.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry saved successfully!'),
          backgroundColor: successColor,
        ),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _openUpdateEntrySelector() async {
    if (siteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a site first.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    setState(() {
      isLoadingEntryDates = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .where('siteId', isEqualTo: siteCode)
          .get();

      final entries = <Map<String, dynamic>>[];
      for (var doc in query.docs) {
        final data = doc.data();
        DateTime? dt;
        final rawDate = data['date'];
        if (rawDate is String) {
          dt = DateTime.tryParse(rawDate);
        } else if (rawDate is Timestamp) {
          dt = rawDate.toDate();
        }
        if (dt != null) {
          entries.add({'docId': doc.id, 'date': dt});
        }
      }
      entries.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _existingEntries = entries;
      });

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No existing entries found for this site.'),
            backgroundColor: warningColor,
          ),
        );
        return;
      }

      String selectedDocId = entries.first['docId'];

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Entry to Update',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDocId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    items: entries
                        .map((e) => DropdownMenuItem<String>(
                              value: e['docId'] as String,
                              child: Text(DateFormat('yyyy-MM-dd')
                                  .format(e['date'] as DateTime)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        selectedDocId = val;
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _loadEntryByDocId(selectedDocId);
                        },
                        child: const Text('Load Entry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load entries: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      setState(() {
        isLoadingEntryDates = false;
      });
    }
  }

  Future<void> _loadEntryByDocId(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .doc(docId)
          .get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Selected entry not found.'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }
      final data = doc.data()!;

      // Parse date
      DateTime? dt;
      final rawDate = data['date'];
      if (rawDate is String) {
        dt = DateTime.tryParse(rawDate);
      } else if (rawDate is Timestamp) {
        dt = rawDate.toDate();
      }

      // Parse materials and labours
      final List<dynamic> mats = (data['materials'] as List<dynamic>? ?? []);
      final List<dynamic> labs = (data['labours'] as List<dynamic>? ?? []);

      final loadedMaterials = <Map<String, dynamic>>[];
      for (var m in mats) {
        if (m is Map<String, dynamic>) {
          final type = (m['type'] ?? '').toString();
          final qty = (m['quantity'] is num)
              ? (m['quantity'] as num).toInt()
              : int.tryParse((m['quantity'] ?? '0').toString()) ?? 0;
          loadedMaterials.add({'type': type, 'quantity': qty});

          // Ensure unitPrice available
          final upRaw = m['unitPrice'];
          num up = 0;
          if (upRaw is num) {
            up = upRaw;
          } else if (upRaw is String) {
            up = num.tryParse(upRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          if (type.isNotEmpty) {
            materialPrices[type] = up;
          }
        }
      }

      final loadedLabours = <Map<String, dynamic>>[];
      for (var l in labs) {
        if (l is Map<String, dynamic>) {
          final type = (l['type'] ?? '').toString();
          final count = (l['count'] is num)
              ? (l['count'] as num).toInt()
              : int.tryParse((l['count'] ?? '0').toString()) ?? 0;
          loadedLabours.add({'type': type, 'count': count});

          // Ensure unitSalary available
          final usRaw = l['unitSalary'];
          num us = 0;
          if (usRaw is num) {
            us = usRaw;
          } else if (usRaw is String) {
            us = num.tryParse(usRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          if (type.isNotEmpty) {
            labourSalaries[type] = us;
          }
        }
      }

      setState(() {
        materials = loadedMaterials;
        labours = loadedLabours;
        foodCost.text = ((data['food'] ?? 0)).toString();
        transportCost.text = ((data['transport'] ?? 0)).toString();
        fuelCost.text = ((data['fuel'] ?? 0)).toString();
        if (dt != null) {
          selectedDate = dt;
          _selectedUpdateDate = dt;
        }
        isUpdateMode = true;
        _updateDocId = doc.id;

        // Update projectStage from the loaded entry if available
        if (data.containsKey('projectStage')) {
          projectStage = data['projectStage']?.toString();
        } else if (data.containsKey('projectStage')) {
          projectStage = data['projectStage']?.toString();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Entry loaded. You can edit and press Update Entry to save.'),
          backgroundColor: successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load entry: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _updateExistingEntry() async {
    if (!isUpdateMode || _updateDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No entry selected for update.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    if (siteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a site.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a date.'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final dateIso = selectedDate!.toIso8601String();
    final data = {
      "date": dateIso,
      "food": int.tryParse(foodCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "labours": labours
          .map((l) => {
                "type": l['type'] ?? '',
                "count": l['count'] ?? 0,
                "unitSalary": labourSalaries[l['type'] ?? ''] ?? 0,
                "amount":
                    (labourSalaries[l['type'] ?? ''] ?? 0) * (l['count'] ?? 0),
              })
          .toList(),
      "materials": materials
          .map((m) => {
                "type": m['type'] ?? '',
                "quantity": m['quantity'] ?? 0,
                "unitPrice": materialPrices[m['type'] ?? ''] ?? 0,
                "amount": (materialPrices[m['type'] ?? ''] ?? 0) *
                    (m['quantity'] ?? 0),
              })
          .toList(),
      "Supervisor ID": supervisorId ?? 'Not Available',
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
      "siteLocation": siteLocation,
      "siteId": siteCode,
      "supervisorName": supervisorName,
    };

    try {
      await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .doc(_updateDocId)
          .update(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry updated successfully!'),
          backgroundColor: successColor,
        ),
      );

      setState(() {
        isUpdateMode = false;
        _updateDocId = null;
        _selectedUpdateDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update entry: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primaryColor));
  }

  Widget _buildCostInput(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        prefixIcon: Icon(icon, size: 20, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
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
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowHeight: 40,
            dataRowHeight: 40,
            columns: [
              DataColumn(
                  label: SizedBox(
                      width: 80,
                      child: Text('Type',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor)))),
              DataColumn(
                  label: SizedBox(
                      width: 100,
                      child: Text('Item',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor)))),
              DataColumn(
                  label: SizedBox(
                      width: 60,
                      child: Text('Qty',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor)))),
              DataColumn(
                  label: SizedBox(
                      width: 100,
                      child: Text('Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor)))),
              DataColumn(label: SizedBox(width: 40)),
            ],
            rows: [
              ...materials.asMap().entries.map((entry) {
                int idx = entry.key;
                var m = entry.value;
                return DataRow(
                  cells: [
                    DataCell(SizedBox(
                        width: 80,
                        child: Text('Material',
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                        width: 100,
                        child: Text(m['type']?.toString() ?? '',
                            style: TextStyle(fontSize: 12, color: textColor),
                            overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(
                        width: 60,
                        child: Text('${m['quantity'] ?? 0}',
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                        width: 100,
                        child: Text(
                            _calculateMaterialAmount(
                                m['type']?.toString() ?? '',
                                m['quantity'] ?? 0),
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(Icons.delete,
                            color: errorColor, size: 16),
                        onPressed: () => _removeMaterial(idx),
                        padding: EdgeInsets.zero,
                      ),
                    )),
                  ],
                );
              }),
              ...labours.asMap().entries.map((entry) {
                int idx = entry.key;
                var l = entry.value;
                return DataRow(
                  cells: [
                    DataCell(SizedBox(
                        width: 80,
                        child: Text('Labour',
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                        width: 100,
                        child: Text(l['type']?.toString() ?? '',
                            style: TextStyle(fontSize: 12, color: textColor),
                            overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(
                        width: 60,
                        child: Text('${l['count'] ?? 0}',
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                        width: 100,
                        child: Text(
                            _calculateLabourAmount(
                                l['type']?.toString() ?? '', l['count'] ?? 0),
                            style: TextStyle(fontSize: 12, color: textColor)))),
                    DataCell(SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(Icons.delete,
                            color: errorColor, size: 16),
                        onPressed: () => _removeLabour(idx),
                        padding: EdgeInsets.zero,
                      ),
                    )),
                  ],
                );
              }),
              DataRow(
                cells: [
                  DataCell(SizedBox(
                      width: 80,
                      child: Text('Food', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('₹${foodCost.text}',
                          style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(SizedBox(
                      width: 80,
                      child: Text('Transport', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('₹${transportCost.text}',
                          style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(SizedBox(
                      width: 80,
                      child: Text('Fuel', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('₹${fuelCost.text}',
                          style: TextStyle(fontSize: 12, color: textColor)))),
                  DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 80, child: Text(''))),
                  DataCell(SizedBox(width: 100, child: Text(''))),
                  DataCell(SizedBox(
                      width: 60,
                      child: Text('Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primaryColor,
                          )))),
                  DataCell(SizedBox(
                      width: 100,
                      child: Text('₹${_getTotalAmount()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primaryColor,
                          )))),
                  DataCell(SizedBox(width: 40, child: Text(''))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, ),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, ),
                children: [
                  TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.w500)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: const Text('Manager Daily Site Entry',
              style: TextStyle()),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(),
      ),
      backgroundColor: lightBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
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
                            colors: [primaryColor.withOpacity(0.8), primaryColor],
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
                                  Icon(Icons.construction,
                                      size: 22, ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: isLoadingSites
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              
                                            ))
                                        : Container(
                                            decoration: BoxDecoration(
                                              
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: DropdownButtonFormField<String>(
                                                value: selectedSiteId,
                                                isExpanded: true,
                                                decoration: InputDecoration(
                                                  labelText: 'Site ID',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                ),
                                                items: siteList
                                                    .map((site) => DropdownMenuItem(
                                                          value: site['siteId'],
                                                          child: Text(
                                                              site['siteId'] ?? '',
                                                              overflow: TextOverflow
                                                                  .ellipsis),
                                                        ))
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
                              _buildInfoRow(Icons.person, 'Supervisor:', supervisorName ?? '-'),
                              if (supervisorId != null && supervisorId!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 30.0, top: 4),
                                  child: Text(
                                    'ID: ${supervisorId ?? '-'}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              _buildInfoRow(Icons.location_on, 'Location:', siteLocation ?? '-'),
                              _buildInfoRow(Icons.timeline, 'Project Stage:', projectStage ?? '-'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 20, ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      selectedDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(selectedDate!)
                                          : 'No date chosen',
                                      style: const TextStyle(
                                          fontSize: 16, ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  isUpdateMode
                                      ? const SizedBox.shrink()
                                      : TextButton.icon(
                                          onPressed: _pickDate,
                                          icon: const Icon(Icons.edit, size: 16, ),
                                          label: const Text('Change', style: TextStyle()),
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
                                  'Loaded entry for: ${DateFormat('yyyy-MM-dd')
                                          .format(_selectedUpdateDate!)}',
                                  style: TextStyle(color: successColor, fontWeight: FontWeight.w500),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.history, size: 18),
                                    onPressed: isLoadingSites ||
                                            selectedSiteId == null ||
                                            selectedSiteId!.isEmpty
                                        ? null
                                        : _openUpdateEntrySelector,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
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
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                      child: Text('Add Entry',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          )),
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
                                                  CircularProgressIndicator())
                                          : materialError != null
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(materialError!,
                                                      style: TextStyle(
                                                          color: errorColor)))
                                              : Column(
                                                  children: [
                                                    TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            'Search Material...',
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor),
                                                        ),
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 10,
                                                                    horizontal:
                                                                        12),
                                                        prefixIcon: Icon(Icons.search, color: primaryColor),
                                                      ),
                                                      onChanged: (query) {
                                                        setState(() {
                                                          final q = query
                                                              .toLowerCase();
                                                          final filtered = materialOptions
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
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Material',
                                                        prefixIcon: Icon(Icons.category_outlined, color: primaryColor),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor, width: 2),
                                                        ),
                                                        filled: true,
                                                        fillColor:
                                                            Colors.grey[50],
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10,
                                                                horizontal: 12),
                                                      ),
                                                      items: (_filteredMaterialOptions ??
                                                              materialOptions)
                                                          .map((item) =>
                                                              DropdownMenuItem(
                                                                value: item,
                                                                child: Text(
                                                                    item,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis),
                                                              ))
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
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(color: primaryColor),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: primaryColor, width: 2),
                                          ),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 12),
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
                                      horizontal: 16, vertical: 10),
                                ),
                                onPressed: isLoadingMaterials ||
                                        materialOptions.isEmpty
                                    ? null
                                    : _addMaterial,
                                label: const Text('Add Material',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Other Materials button
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCustomMaterialFields =
                                      !_showCustomMaterialFields;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor.withOpacity(0.1),
                                foregroundColor: primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Other Materials'),
                            ),
                            const SizedBox(height: 8),

                            // Custom Material Fields
                            if (_showCustomMaterialFields) ...[
                              TextField(
                                controller: _customMaterialNameController,
                                decoration: InputDecoration(
                                  labelText: 'Material Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
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
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primaryColor),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primaryColor, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 12),
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
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primaryColor),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primaryColor, width: 2),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 12),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _addCustomMaterial,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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

                    // Labour Section
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
                            _buildSectionHeader('Labour Details'),
                            const SizedBox(height: 12),

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
                                                  CircularProgressIndicator())
                                          : labourError != null
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(labourError!,
                                                      style: TextStyle(
                                                          color: errorColor)))
                                              : Column(
                                                  children: [
                                                    TextField(
                                                      decoration: InputDecoration(
                                                        hintText: 'Search Labour...',
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor),
                                                        ),
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(
                                                            vertical: 10, horizontal: 12),
                                                        prefixIcon: Icon(Icons.search, color: primaryColor),
                                                      ),
                                                      onChanged: (query) {
                                                        setState(() {
                                                          final q = query
                                                              .toLowerCase();
                                                          final filtered = labourOptions
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
                                                            selectedLabour = filtered
                                                                .contains(
                                                                selectedLabour)
                                                                ? selectedLabour
                                                                : filtered
                                                                .first;
                                                          } else {
                                                            selectedLabour =
                                                                null;
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
                                                        prefixIcon: Icon(Icons.group, color: primaryColor),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(color: primaryColor, width: 2),
                                                        ),
                                                        filled: true,
                                                        fillColor: Colors.grey[50],
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(
                                                            vertical: 10, horizontal: 12),
                                                      ),
                                                      items: (_filteredLabourOptions ?? labourOptions)
                                                          .map((item) => DropdownMenuItem(
                                                        value: item,
                                                        child: Text(item,
                                                            overflow: TextOverflow.ellipsis),
                                                      ))
                                                          .toList(),
                                                      onChanged: (value) => setState(() => selectedLabour = value),
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
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: primaryColor),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: primaryColor, width: 2),
                                          ),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 12),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            labourQty = int.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Add Labour button
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
                                      horizontal: 16, vertical: 10),
                                ),
                                onPressed: isLoadingLabours || labourOptions.isEmpty
                                    ? null
                                    : _addLabour,
                                label: const Text('Add Labour',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Add Custom Labour button
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCustomLabourFields = !_showCustomLabourFields;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor.withOpacity(0.1),
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Other Labour Types'),
                            ),
                            const SizedBox(height: 8),

                            // Custom Labour Fields
                            if (_showCustomLabourFields) ...[
                              TextField(
                                controller: _customLabourNameController,
                                decoration: InputDecoration(
                                  labelText: 'Labour Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customLabourSalaryController,
                                decoration: InputDecoration(
                                  labelText: 'Salary',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
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
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
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
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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

                    // Cost Inputs Section
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
                            _buildSectionHeader('Additional Costs'),
                            const SizedBox(height: 12),
                            _buildCostInput('Food Cost', foodCost, Icons.fastfood),
                            const SizedBox(height: 12),
                            _buildCostInput('Transport Cost', transportCost, Icons.directions_car),
                            const SizedBox(height: 12),
                            _buildCostInput('Fuel Cost', fuelCost, Icons.local_gas_station),
                          ],
                        ),
                      ),
                    ),

                    // Summary Section
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader('Summary'),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Total: ₹${_getTotalAmount()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryTable(),
                          ],
                        ),
                      ),
                    ),

                    // Save and Reset Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          if (isUpdateMode)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSaving ? null : _updateExistingEntry,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: warningColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          
                                        ),
                                      )
                                    : const Text('Update Entry',
                                        style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          if (isUpdateMode) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => _showConfirmationDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        
                                      ),
                                    )
                                  : const Text('Save Entry',
                                      style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resetForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Reset',
                                  style: TextStyle(fontSize: 16)),
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