import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/screens/supervisor/supervisor_dashboard.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_button.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  const SiteEntryPage({
    Key? key,
    required this.userName,
    required this.userDetails,
  }) : super(key: key);

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
  String? supervisorName;
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
  final TextEditingController _customLabourCountController =
      TextEditingController(text: '0');

  String getOrgId() {
    String orgId = FirestoreService.currentOrgId;
    if (orgId == 'uninitialized' || orgId.isEmpty) {
      final rawId =
          widget.userDetails['orgId']?.toString() ??
          widget.userDetails['dynamicPath']?.toString() ??
          AuthService().userData['orgId']?.toString() ??
          AuthService().userData['dynamicPath']?.toString() ??
          'HariMama';
      if (rawId.contains('/')) {
        final parts = rawId.split('/');
        if (parts[0] == 'organisation' && parts.length > 1) {
          return parts[1];
        }
        return parts[0];
      }
      return rawId;
    }
    return orgId;
  }

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
      final orgId = getOrgId();
      final snapshot = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
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
        // Only set if not already set from supervisor mapping
        selectedProjectPhase ??= projectPhases.isNotEmpty
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
      final orgId = getOrgId();
      final String? passedSupervisorId = widget.userDetails['supervisorId']
          ?.toString();
      Query query = FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
          .collection('siteSupervisorMap');

      if (passedSupervisorId != null && passedSupervisorId.isNotEmpty) {
        query = query.where('Supervisor ID', isEqualTo: passedSupervisorId);
      } else {
        query = query.where('supervisor', isEqualTo: widget.userName);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        final sites = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return <String, String>{
                'siteId': data['site']?.toString() ?? '',
                'supervisor': data['supervisor']?.toString() ?? '',
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
            String passedSiteId =
                widget.userDetails['siteId']?.toString() ?? '';
            var matchedSite = sites.first;
            if (passedSiteId.isNotEmpty) {
              try {
                matchedSite = sites.firstWhere(
                  (s) => s['siteId'] == passedSiteId,
                );
              } catch (_) {
                // If not found, fallback to first
              }
            }
            selectedSiteId = matchedSite['siteId'];
            siteCode = matchedSite['siteId']!;
            supervisorName = matchedSite['supervisor']!;
            siteLocation = matchedSite['location']!;
            supervisorId = matchedSite['supervisorId']!;
            projectName = matchedSite['projectName']!;
            selectedProjectPhase = matchedSite['projectStage']!.isNotEmpty
                ? matchedSite['projectStage']
                : (projectPhases.isNotEmpty ? projectPhases.first : null);
          } else {
            selectedSiteId = null;
            siteCode = '';
            supervisorName = widget.userName;
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
          supervisorName = widget.userName;
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
        supervisorName = widget.userName;
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
      final orgId = getOrgId();

      // 1. Fetch materialCategories to build a lookup map
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
          .collection('materialCategories')
          .get();
      final categoryMap = <String, String>{};
      for (var doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final name = (data['matCategory'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          categoryMap[doc.reference.path] = name;
          categoryMap[doc.id] = name;
        }
      }

      // 2. Fetch materials from organisation/{orgId}/materials
      final snapshot = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
          .collection('materials')
          .get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('materialName')) {
          final catRef = data['materialName'];
          String? resolvedCategory;
          if (catRef is DocumentReference) {
            resolvedCategory =
                categoryMap[catRef.path] ?? categoryMap[catRef.id];
          } else if (catRef is String && catRef.isNotEmpty) {
            resolvedCategory =
                categoryMap[catRef] ?? categoryMap[catRef.split('/').last];
          }
          final name =
              (resolvedCategory ??
                      data['materialName'] ??
                      data['materialName'] ??
                      catRef?.toString() ??
                      '')
                  .toString()
                  .trim();
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
      final orgId = getOrgId();
      // Load labours from /organisation/{orgId}/labours
      final snapshot = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
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
      _fetchProjectPhases();
      _fetchSupervisorData();
      _fetchMaterialOptions();
      _fetchLabourOptions();
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
    final entriesColl = FirestoreService.siteSupervisorEntries;

    final dateForId = DateFormat('ddMMyyyy').format(selectedDate!);
    final docId = '${siteCode}_$dateForId';
    final dateIso = selectedDate!.toIso8601String();

    List<Map<String, dynamic>> newMaterials = materials
        .map(
          (m) => {
            "type": m['type'] ?? '',
            "quantity": m['quantity'] ?? 0,
            "unitPrice": materialPrices[m['type'] ?? ''] ?? 0,
            "amount":
                (materialPrices[m['type'] ?? ''] ?? 0) * (m['quantity'] ?? 0),
          },
        )
        .toList();

    List<Map<String, dynamic>> newLabours = labours
        .map(
          (l) => {
            "type": l['type'] ?? '',
            "count": l['count'] ?? 0,
            "unitSalary": labourSalaries[l['type'] ?? ''] ?? 0,
            "amount":
                (labourSalaries[l['type'] ?? ''] ?? 0) * (l['count'] ?? 0),
          },
        )
        .toList();

    try {
      // Check for existing entry for this site and date
      final existing = await entriesColl.doc(docId).get();
      final bool isSameDate = existing.exists;

      if (isSameDate) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Entry'),
            content: const Text(
              'An entry for this site and date already exists.',
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

      Map<String, dynamic> data;

      if (isSameDate) {
        // Merge with existing entry
        final existingData = existing.data()!;
        final List<dynamic> existingMaterials =
            existingData['materials'] as List? ?? [];
        final List<dynamic> existingLabours =
            existingData['labours'] as List? ?? [];
        final int existingFood = (existingData['food'] ?? 0) is int
            ? existingData['food']
            : (existingData['food'] as num?)?.toInt() ?? 0;
        final int existingFuel = (existingData['fuel'] ?? 0) is int
            ? existingData['fuel']
            : (existingData['fuel'] as num?)?.toInt() ?? 0;
        final int existingTransport = (existingData['transport'] ?? 0) is int
            ? existingData['transport']
            : (existingData['transport'] as num?)?.toInt() ?? 0;

        final List<dynamic> mergedMaterials = [
          ...existingMaterials,
          ...newMaterials,
        ];
        final List<dynamic> mergedLabours = [...existingLabours, ...newLabours];
        final int mergedFood =
            existingFood + (int.tryParse(foodCost.text) ?? 0);
        final int mergedFuel =
            existingFuel + (int.tryParse(fuelCost.text) ?? 0);
        final int mergedTransport =
            existingTransport + (int.tryParse(transportCost.text) ?? 0);

        int mergedTotalAmount = mergedFood + mergedFuel + mergedTransport;
        for (var m in mergedMaterials) {
          mergedTotalAmount += ((m['amount'] ?? 0) as num).toInt();
        }
        for (var l in mergedLabours) {
          mergedTotalAmount += ((l['amount'] ?? 0) as num).toInt();
        }

        data = {
          "date": dateIso,
          "food": mergedFood,
          "fuel": mergedFuel,
          "labours": mergedLabours,
          "materials": mergedMaterials,
          "supervisorId": supervisorId ?? '',
          "supervisorName": widget.userName,
          "projectStage": selectedProjectPhase ?? '',
          "transport": mergedTransport,
          "totalAmount": mergedTotalAmount,
          "siteLocation": siteLocation,
          "siteId": siteCode,
        };
      } else {
        data = {
          "date": dateIso,
          "food": int.tryParse(foodCost.text) ?? 0,
          "fuel": int.tryParse(fuelCost.text) ?? 0,
          "labours": newLabours,
          "materials": newMaterials,
          "supervisorId": supervisorId ?? '',
          "supervisorName": widget.userName,
          "projectStage": selectedProjectPhase ?? '',
          "transport": int.tryParse(transportCost.text) ?? 0,
          "totalAmount": _getTotalAmount(),
          "siteLocation": siteLocation,
          "siteId": siteCode,
        };
      }

      await entriesColl.doc(docId).set(data);
      // Update total site expense aggregation
      await ExpenseService.updateTotalSiteExpense(siteCode);
      // --- Update siteSupervisorProjectStageActual collection ---
      final actualColl = FirestoreService.siteSupervisorProjectStageActual;
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
        final existingActData = actualDoc.data()!;
        final List<dynamic> existingActLabours =
            existingActData['actLabours'] as List? ?? [];
        final List<dynamic> mergedActLabours = [
          ...existingActLabours,
          ...actLabours,
        ];
        final double existingActPayment = (existingActData['actPayment'] ?? 0)
            .toDouble();
        int prevDays = (existingActData['actDays'] ?? 0) as int;

        if (isSameDate) {
          await actualColl.doc(actualDocId).update({
            ...actualData,
            "actLabours": mergedActLabours,
            "actPayment": existingActPayment + _getTotalAmount(),
            "actDays": prevDays,
          });
        } else {
          await actualColl.doc(actualDocId).update({
            ...actualData,
            "actLabours": mergedActLabours,
            "actPayment": existingActPayment + _getTotalAmount(),
            "actDays": prevDays + 1,
          });
        }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: isDark ? Colors.white : const Color(0xFF0A183D),
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _buildCostInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 20,
                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.8),
              ),
              filled: true,
              fillColor: fieldBg,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTable() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);
    final headerTextColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final bodyTextColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
            headingRowHeight: 44,
            dataRowHeight: 42,
            headingRowColor: WidgetStateProperty.all(
              isDark ? primaryColor.withValues(alpha: 0.25) : primaryColor.withValues(alpha: 0.08),
            ),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: headerTextColor),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: headerTextColor),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: headerTextColor),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: headerTextColor),
                  ),
                ),
              ),
              const DataColumn(label: SizedBox(width: 40)),
            ],
            rows: [
              ...materials.asMap().entries.map((entry) {
                int idx = entry.key;
                var m = entry.value;
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Material', style: TextStyle(fontSize: 12, color: bodyTextColor)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          m['type']?.toString() ?? '',
                          style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${m['quantity'] ?? 0}',
                          style: TextStyle(fontSize: 12, color: bodyTextColor),
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
                          style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
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
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Labour', style: TextStyle(fontSize: 12, color: bodyTextColor)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          l['type']?.toString() ?? '',
                          style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${l['count'] ?? 0}',
                          style: TextStyle(fontSize: 12, color: bodyTextColor),
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
                          style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
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
                  DataCell(SizedBox(width: 80, child: Text('Food', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('₹${foodCost.text}', style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w700)))),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 80, child: Text('Transport', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('₹${transportCost.text}', style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w700)))),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 80, child: Text('Fuel', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: bodyTextColor)))),
                  DataCell(SizedBox(width: 100, child: Text('₹${fuelCost.text}', style: TextStyle(fontSize: 12, color: bodyTextColor, fontWeight: FontWeight.w700)))),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: headerTextColor,
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
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
    final count = int.tryParse(_customLabourCountController.text) ?? 0;
    if (name.isNotEmpty && count > 0) {
      setState(() {
        labours.add({'type': name, 'count': count});
        labourSalaries[name] = salary;
        _customLabourNameController.clear();
        _customLabourSalaryController.text = '0';
        _customLabourCountController.text = '0';
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
    _customLabourCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dropdownBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

    return GlassScaffold(
      title: 'Daily Site Entry',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
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
                      color: cardBg,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.construction,
                                size: 22,
                                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedSiteId,
                                  isExpanded: true,
                                  dropdownColor: dropdownBg,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Site Id (Supervisor Only)',
                                    labelStyle: TextStyle(
                                      color: labelColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: borderColor, width: 1.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: borderColor, width: 1.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: primaryColor, width: 1.8),
                                    ),
                                    filled: true,
                                    fillColor: fieldBg,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 14,
                                    ),
                                  ),
                                  items: supervisorSites
                                      .map(
                                        (site) => DropdownMenuItem(
                                          value: site['siteId'],
                                          child: Text(
                                            site['siteId'] ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                                orElse: () => <String, String>{
                                                  'siteId': '',
                                                  'supervisor': '',
                                                  'location': 'Unknown',
                                                  'supervisorId': '',
                                                  'projectStage': '',
                                                },
                                              );
                                          setState(() {
                                            selectedSiteId = value;
                                            siteCode = selected['siteId'] ?? '';
                                            supervisorName =
                                                selected['supervisor'] ?? '';
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
                          const SizedBox(height: 12),
                          _buildModernSiteRow(
                            Icons.person,
                            'Supervisor',
                            '${supervisorName ?? widget.userName}${supervisorId != null && supervisorId!.isNotEmpty ? ' (ID: $supervisorId)' : ''}',
                          ),
                          _buildModernSiteRow(
                            Icons.business,
                            'Project Name',
                            projectName ?? 'Not found',
                          ),
                          _buildModernSiteRow(
                            Icons.location_on,
                            'Location',
                            siteLocation ?? 'Unknown',
                          ),
                          _buildModernSiteRow(
                            Icons.stairs_outlined,
                            'Project Stage',
                            selectedProjectPhase ?? 'Not assigned',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Date: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: labelColor,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  selectedDate != null
                                      ? '${selectedDate!.toLocal()}'.split(
                                          ' ',
                                        )[0]
                                      : 'No date chosen',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text(
                                  'Change',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add Entry Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        'Add Entry',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Material Details Card
                    GlassCard(
                      color: cardBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Material Details'),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Search & Select Material',
                                                style: TextStyle(
                                                  color: labelColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              TextField(
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Search Material...',
                                                  hintStyle: TextStyle(
                                                    color: labelColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: primaryColor, width: 1.8),
                                                  ),
                                                  filled: true,
                                                  fillColor: fieldBg,
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 14,
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
                                                dropdownColor: dropdownBg,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.category_outlined,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: primaryColor, width: 1.8),
                                                  ),
                                                  filled: true,
                                                  fillColor: fieldBg,
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 14,
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
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: textColor,
                                                                fontWeight: FontWeight.w700,
                                                              ),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Qty',
                                          style: TextStyle(
                                            color: labelColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: materialQtyController,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.0),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.0),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: primaryColor, width: 1.8),
                                            ),
                                            filled: true,
                                            fillColor: fieldBg,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 14,
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
                                        const SizedBox(height: 6),
                                        Builder(
                                          builder: (context) {
                                            final price =
                                                materialPrices[selectedMaterial ??
                                                    ''] ??
                                                0;
                                            final qty = materialQty;
                                            final total = price * qty;
                                            return Text(
                                              '$qty × ₹${price.toStringAsFixed(0)} = ₹${total.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: total > 0
                                                    ? const Color(0xFF10B981)
                                                    : labelColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'Add Material',
                                  icon: Icons.add,
                                  onPressed: isLoadingMaterials || materialOptions.isEmpty
                                      ? null
                                      : _addMaterial,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: _showCustomMaterialFields ? 'Hide Others' : 'Others',
                                  icon: Icons.more_horiz,
                                  onPressed: () {
                                    setState(() {
                                      _showCustomMaterialFields = !_showCustomMaterialFields;
                                    });
                                  },
                                  isSecondary: true,
                                ),
                              ),
                            ],
                          ),
                          if (_showCustomMaterialFields) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Material Name',
                              style: TextStyle(
                                color: labelColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _customMaterialNameController,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: borderColor, width: 1.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: borderColor, width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: primaryColor, width: 1.8),
                                ),
                                filled: true,
                                fillColor: fieldBg,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Qty',
                                        style: TextStyle(
                                          color: labelColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _customMaterialQtyController,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor, width: 1.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor, width: 1.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                                          ),
                                          filled: true,
                                          fillColor: fieldBg,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Unit Price (₹)',
                                        style: TextStyle(
                                          color: labelColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _customMaterialPriceController,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor, width: 1.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor, width: 1.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                                          ),
                                          filled: true,
                                          fillColor: fieldBg,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'Add Custom Material',
                              icon: Icons.playlist_add,
                              onPressed: _addCustomMaterial,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Labour Details Card
                    GlassCard(
                      color: cardBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Labour Details'),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Search & Select Labour',
                                                style: TextStyle(
                                                  color: labelColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              TextField(
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Search Labour...',
                                                  hintStyle: TextStyle(
                                                    color: labelColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: primaryColor, width: 1.8),
                                                  ),
                                                  filled: true,
                                                  fillColor: fieldBg,
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 14,
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
                                                dropdownColor: dropdownBg,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.group,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: borderColor, width: 1.0),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    borderSide: BorderSide(color: primaryColor, width: 1.8),
                                                  ),
                                                  filled: true,
                                                  fillColor: fieldBg,
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 14,
                                                      ),
                                                ),
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
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: textColor,
                                                                fontWeight: FontWeight.w700,
                                                              ),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Count',
                                          style: TextStyle(
                                            color: labelColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: labourQtyController,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.0),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: borderColor, width: 1.0),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: primaryColor, width: 1.8),
                                            ),
                                            filled: true,
                                            fillColor: fieldBg,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 14,
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
                                        const SizedBox(height: 6),
                                        Builder(
                                          builder: (context) {
                                            final salary =
                                                labourSalaries[selectedLabour ??
                                                    ''] ??
                                                0;
                                            final count = labourQty;
                                            final total = salary * count;
                                            return Text(
                                              '$count × ₹${salary.toStringAsFixed(0)} = ₹${total.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: total > 0
                                                    ? const Color(0xFF10B981)
                                                    : labelColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'Add Labour',
                                  icon: Icons.person_add,
                                  onPressed: isLoadingLabours || labourOptions.isEmpty
                                      ? null
                                      : _addLabour,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: _showCustomLabourFields ? 'Hide Others' : 'Others',
                                  icon: Icons.more_horiz,
                                  onPressed: () {
                                    setState(() {
                                      _showCustomLabourFields = !_showCustomLabourFields;
                                    });
                                  },
                                  isSecondary: true,
                                ),
                              ),
                            ],
                          ),
                          if (_showCustomLabourFields) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _customLabourNameController,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Labour Type',
                                labelStyle: TextStyle(
                                  color: labelColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: borderColor, width: 1.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: borderColor, width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: primaryColor, width: 1.8),
                                ),
                                filled: true,
                                fillColor: fieldBg,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customLabourCountController,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Count',
                                      labelStyle: TextStyle(
                                        color: labelColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: primaryColor, width: 1.8),
                                      ),
                                      filled: true,
                                      fillColor: fieldBg,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _customLabourSalaryController,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Salary (₹)',
                                      labelStyle: TextStyle(
                                        color: labelColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: borderColor, width: 1.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: primaryColor, width: 1.8),
                                      ),
                                      filled: true,
                                      fillColor: fieldBg,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'Add Custom Labour',
                              icon: Icons.playlist_add,
                              onPressed: _addCustomLabour,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Additional Costs Card
                    GlassCard(
                      color: cardBg,
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
                          _buildCostInput(
                            'Transport Cost',
                            transportCost,
                            Icons.directions_car,
                          ),
                          _buildCostInput(
                            'Fuel Cost',
                            fuelCost,
                            Icons.local_gas_station,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Today's Summary Header & Table
                    GlassCard(
                      color: cardBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Today\'s Summary'),
                          const SizedBox(height: 12),
                          _buildSummaryTable(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Reset',
                            icon: Icons.refresh,
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
                            isSecondary: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassButton(
                            label: 'Save Entry',
                            icon: Icons.save,
                            onPressed: isSaving ? null : _saveToFirestore,
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

  Widget _buildModernSiteRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final iconColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final valueColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
