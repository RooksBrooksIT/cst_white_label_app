import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';
import 'package:intl/intl.dart';

class ManagerSiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  final bool hideAppBar;
  const ManagerSiteEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
    this.hideAppBar = false,
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
      final results = await Future.wait([
        FirestoreService.sites.get(),
        FirestoreService.siteSupervisorMap.get(),
      ]);
      final sitesSnapshot = results[0];
      final snapshot = results[1];

      final Map<String, String> siteNames = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };
      final List<Map<String, String>> rawSites = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawSite = (data['site'] ?? data['siteDocId'] ?? '').toString().trim();
        final rawSiteCode = (data['siteCode'] ?? data['siteId'] ?? '').toString().trim();
        final rawSiteName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim();
        final sDocId = (data['siteDocId'] ?? '').toString().trim();

        String baseId = sDocId.isNotEmpty ? sDocId : rawSite;
        if (baseId.isEmpty && doc.id.contains('_') && (doc.id.startsWith('ST') || doc.id.startsWith('PR'))) {
          baseId = doc.id;
        }

        var canonicalId = ExpenseService.formatCanonicalSiteId(
          rawId: baseId.isNotEmpty ? baseId : (rawSiteCode.isNotEmpty ? rawSiteCode : doc.id),
          siteCode: rawSiteCode.isNotEmpty ? rawSiteCode : null,
          siteName: rawSiteName.isNotEmpty ? rawSiteName : null,
        );

        if (!canonicalId.contains('_') && canonicalId.isNotEmpty) {
          final resolved = await ExpenseService.resolveCanonicalSiteDocId(canonicalId);
          if (resolved.isNotEmpty && resolved.contains('_')) {
            canonicalId = resolved;
          }
        }

        if (canonicalId.toUpperCase().startsWith('PR')) {
          canonicalId = 'ST${canonicalId.substring(2)}';
        }

        if (canonicalId.isNotEmpty) {
          rawSites.add({
            'siteId': canonicalId,
            'siteName': siteNames[canonicalId] ??
                (data['siteName']?.toString() ??
                    (rawSiteName.isNotEmpty ? rawSiteName : 'Unnamed Site')),
            'supervisor': data['supervisor']?.toString() ?? 'Not Available',
            'supervisorId':
                (data['Supervisor ID'] ?? data['supervisorId'])?.toString() ??
                    'Not Available',
            'location': data['location']?.toString() ?? 'Not Available',
            'projectStage': data['projectStage']?.toString() ?? 'Not Available',
          });
        }
      }

      for (var doc in sitesSnapshot.docs) {
        final data = doc.data();
        final siteCode = (data['siteCode'] ?? data['siteId'])?.toString().trim();
        final siteName = (data['siteName'] ?? data['projectName'])?.toString().trim();
        var canonicalId = ExpenseService.formatCanonicalSiteId(
          rawId: doc.id,
          siteCode: siteCode,
          siteName: siteName,
        );

        if (!canonicalId.contains('_') && canonicalId.isNotEmpty) {
          final resolved = await ExpenseService.resolveCanonicalSiteDocId(canonicalId);
          if (resolved.isNotEmpty && resolved.contains('_')) {
            canonicalId = resolved;
          }
        }

        if (canonicalId.toUpperCase().startsWith('PR')) {
          canonicalId = 'ST${canonicalId.substring(2)}';
        }

        if (canonicalId.isNotEmpty) {
          rawSites.add({
            'siteId': canonicalId,
            'siteName': data['siteName']?.toString() ?? 'Unnamed Site',
            'supervisor': data['supervisor']?.toString() ?? 'Not Available',
            'supervisorId':
                (data['Supervisor ID'] ?? data['supervisorId'])?.toString() ??
                    'Not Available',
            'location': data['location']?.toString() ?? 'Not Available',
            'projectStage': data['projectStage']?.toString() ?? 'Not Available',
          });
        }
      }

      final Map<String, Map<String, String>> uniqueSites = {};
      for (var s in rawSites) {
        var id = (s['siteId'] ?? '').trim();
        if (id.isEmpty) continue;

        id = ExpenseService.formatCanonicalSiteId(
          rawId: id,
          siteCode: s['siteCode'],
          siteName: s['siteName'],
        );
        if (id.toUpperCase().startsWith('PR')) {
          id = 'ST${id.substring(2)}';
        }

        if (!id.contains('_') || !id.toUpperCase().startsWith('ST')) {
          continue;
        }

        final siteCodeKey = id.split('_').first.toUpperCase();
        final displayLabel = SiteDisplayHelper.formatSiteDisplay(
          siteId: id,
          siteName: s['siteName'],
        );
        final displayKey = displayLabel.toLowerCase();

        final existingKey = uniqueSites.keys.firstWhere(
          (k) => k.toLowerCase() == id.toLowerCase() ||
                 k.split('_').first.toUpperCase() == siteCodeKey ||
                 SiteDisplayHelper.formatSiteDisplay(
                   siteId: uniqueSites[k]!['siteId'],
                   siteName: uniqueSites[k]!['siteName'],
                 ).toLowerCase() == displayKey,
          orElse: () => '',
        );

        if (existingKey.isEmpty) {
          final entry = Map<String, String>.from(s);
          entry['siteId'] = id;
          uniqueSites[id] = entry;
        } else {
          final existing = uniqueSites[existingKey]!;
          for (var entry in s.entries) {
            if ((existing[entry.key] == null ||
                    existing[entry.key] == 'Not Available' ||
                    existing[entry.key] == 'Unnamed Site' ||
                    existing[entry.key] == 'Unknown' ||
                    existing[entry.key] == 'Not found') &&
                entry.value.isNotEmpty &&
                entry.value != 'Not Available' &&
                entry.value != 'Unnamed Site' &&
                entry.value != 'Unknown' &&
                entry.value != 'Not found') {
              existing[entry.key] = entry.value;
            }
          }
        }
      }

      siteList = uniqueSites.values.toList();
      siteList.sort((a, b) => (a['siteId'] ?? '').compareTo(b['siteId'] ?? ''));

      if (siteList.isNotEmpty) {
        if (selectedSiteId == null || !siteList.any((s) => s['siteId'] == selectedSiteId)) {
          selectedSiteId = siteList.first['siteId'];
        }
        _onSiteSelected(selectedSiteId!);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  Future<void> _onSiteSelected(String siteId) async {
    final site = siteList.firstWhere(
      (element) => element['siteId'] == siteId,
      orElse: () => {
        'siteId': '',
        'siteName': '',
        'supervisor': '',
        'supervisorId': '',
        'location': '',
        'projectStage': '',
      },
    );

    setState(() {
      selectedSiteId = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId'];
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      siteCode = siteId;

      if (isUpdateMode) {
        isUpdateMode = false;
        _updateDocId = null;
        _selectedUpdateDate = null;
      }
    });

    if (supervisorName == 'Not Available' ||
        supervisorName == null ||
        supervisorName!.isEmpty ||
        projectStage == 'Not Available' ||
        projectStage == null ||
        projectStage!.isEmpty ||
        siteLocation == 'Not Available' ||
        siteLocation == null ||
        siteLocation!.isEmpty ||
        supervisorId == 'Not Available' ||
        supervisorId == null ||
        supervisorId!.isEmpty) {
      final details = await ExpenseService.resolveSiteDetails(siteId);
      if (mounted && selectedSiteId == siteId) {
        setState(() {
          if (details.supervisor != null && details.supervisor!.isNotEmpty) {
            supervisorName = details.supervisor;
          }
          if (details.supervisorId != null && details.supervisorId!.isNotEmpty) {
            supervisorId = details.supervisorId;
          }
          if (details.location != null && details.location!.isNotEmpty) {
            siteLocation = details.location;
          }
          if (details.projectStage != null && details.projectStage!.isNotEmpty) {
            projectStage = details.projectStage;
          }
          if (details.projectName != null && details.projectName!.isNotEmpty) {
            projectName = details.projectName;
          }
        });
      }
    }

    _fetchProjectNameForSite(siteId);
  }

  Future<void> _fetchProjectNameForSite(String siteId) async {
    try {
      final details = await ExpenseService.resolveSiteDetails(siteId);
      if (details.projectName != null && details.projectName!.isNotEmpty) {
        if (mounted) {
          setState(() {
            projectName = details.projectName;
          });
        }
        return;
      }

      final keys = details.allKeys;
      for (final key in keys) {
        final query = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: key)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final pName = (data['projectName'] ?? data['siteName'])?.toString();
          if (pName != null && pName.isNotEmpty) {
            if (mounted) {
              setState(() {
                projectName = pName;
              });
            }
            return;
          }
        }
      }

      for (final key in keys) {
        final siteDoc = await FirestoreService.sites.doc(key).get();
        if (siteDoc.exists && siteDoc.data() != null) {
          final data = siteDoc.data()!;
          final pName = (data['projectName'] ?? data['siteName'])?.toString();
          if (pName != null && pName.isNotEmpty) {
            if (mounted) {
              setState(() {
                projectName = pName;
              });
            }
            return;
          }
        }
      }

      if (mounted) setState(() => projectName = 'Not Available');
    } catch (e) {
      if (mounted) setState(() => projectName = 'Not Available');
    }
  }

  Future<void> _fetchMaterialOptions() async {
    try {
      final snapshot = await FirestoreService.materials.get();
      final List<String> loadedOptions = [];
      final Map<String, num> loadedPrices = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['materialName'] ?? data['name'] ?? data['title'])?.toString();
        final price = data['unitPrice'] ?? data['price'] ?? data['rate'] ?? data['cost'];

        if (name != null && name.trim().isNotEmpty) {
          final cleanName = name.trim();
          loadedOptions.add(cleanName);
          if (price != null) {
            loadedPrices[cleanName] = num.tryParse(
                    price.toString().replaceAll('₹', '').replaceAll(',', '').trim()) ??
                0;
          }
        }
      }

      loadedOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          materialOptions = loadedOptions;
          materialPrices = loadedPrices;
          selectedMaterial =
              materialOptions.isNotEmpty ? materialOptions.first : null;
          isLoadingMaterials = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          materialError = 'Failed to load materials: $e';
          isLoadingMaterials = false;
        });
      }
    }
  }

  Future<void> _fetchLabourOptions() async {
    try {
      final snapshot = await FirestoreService.labours.get();
      final List<String> loadedOptions = [];
      final Map<String, num> loadedSalaries = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final desig = (data['designation'] ?? data['labourType'] ?? data['name'] ?? data['title'])?.toString();
        final salary = data['salary'] ??
            data['salaryPerDay'] ??
            data['wage'] ??
            data['rate'] ??
            data['dailyWage'] ??
            data['dailyRate'] ??
            data['costPerDay'] ??
            data['amount'];

        if (desig != null && desig.trim().isNotEmpty) {
          final cleanDesig = desig.trim();
          loadedOptions.add(cleanDesig);
          if (salary != null) {
            loadedSalaries[cleanDesig] = num.tryParse(
                    salary.toString().replaceAll('₹', '').replaceAll(',', '').trim()) ??
                0;
          }
        }
      }

      loadedOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          labourOptions = loadedOptions;
          labourSalaries = loadedSalaries;
          selectedLabour =
              labourOptions.isNotEmpty ? labourOptions.first : null;
          isLoadingLabours = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          labourError = 'Failed to load labours: $e';
          isLoadingLabours = false;
        });
      }
    }
  }

  void _addMaterial() {
    if (selectedMaterial != null) {
      final qty = int.tryParse(materialQtyController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        final existingIndex = materials.indexWhere(
          (m) => m['type'] == selectedMaterial,
        );
        final price = materialPrices[selectedMaterial] ?? 0;
        if (existingIndex >= 0) {
          materials[existingIndex]['quantity'] =
              (materials[existingIndex]['quantity'] as int) + qty;
          if (price > 0) {
            materials[existingIndex]['unitPrice'] = price;
          }
        } else {
          materials.add({
            'type': selectedMaterial,
            'quantity': qty,
            'unitPrice': price,
          });
        }
        materialQtyController.text = '0';
        materialQty = 0;
      });
    }
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(
            _customMaterialPriceController.text.replaceAll('₹', '').replaceAll(',', '').trim()) ??
        0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter material name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      materialPrices[name] = price;
      final existingIndex = materials.indexWhere((m) => m['type'] == name);
      if (existingIndex >= 0) {
        materials[existingIndex]['quantity'] =
            (materials[existingIndex]['quantity'] as int) + qty;
        materials[existingIndex]['unitPrice'] = price;
      } else {
        materials.add({
          'type': name,
          'quantity': qty,
          'unitPrice': price,
        });
      }
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
    });
  }

  void _addLabour() {
    if (selectedLabour != null) {
      final count = int.tryParse(labourQtyController.text) ?? 0;
      if (count <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid count greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        final existingIndex = labours.indexWhere(
          (l) => l['type'] == selectedLabour,
        );
        final sal = labourSalaries[selectedLabour] ?? 0;
        if (existingIndex >= 0) {
          labours[existingIndex]['count'] =
              (labours[existingIndex]['count'] as int) + count;
          if (sal > 0) {
            labours[existingIndex]['salary'] = sal;
          }
        } else {
          labours.add({
            'type': selectedLabour,
            'count': count,
            'salary': sal,
          });
        }
        labourQtyController.text = '0';
        labourQty = 0;
      });
    }
  }

  void _addCustomLabour() {
    final name = _customLabourNameController.text.trim();
    final count = int.tryParse(_customLabourQtyController.text) ?? 0;
    final salary = num.tryParse(
            _customLabourSalaryController.text.replaceAll('₹', '').replaceAll(',', '').trim()) ??
        0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter labour designation/type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid count greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      labourSalaries[name] = salary;
      final existingIndex = labours.indexWhere((l) => l['type'] == name);
      if (existingIndex >= 0) {
        labours[existingIndex]['count'] =
            (labours[existingIndex]['count'] as int) + count;
        labours[existingIndex]['salary'] = salary;
      } else {
        labours.add({
          'type': name,
          'count': count,
          'salary': salary,
        });
      }
      _customLabourNameController.clear();
      _customLabourQtyController.text = '0';
      _customLabourSalaryController.text = '0';
    });
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

  Future<void> _openUpdateEntrySelector() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) return;

    setState(() => isLoadingEntryDates = true);

    try {
      final keys = (await ExpenseService.resolveSiteKeys(selectedSiteId!))
          .take(10)
          .toList();
      final snapshot = await FirestoreService.getCollection('ManagerSiteEntry')
          .where('siteCode', whereIn: keys)
          .get();

      _existingEntries = snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime? date;
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        }
        return {
          'docId': doc.id,
          'date': date,
          'data': data,
        };
      }).toList();

      _existingEntries.sort((a, b) {
        final da = a['date'] as DateTime?;
        final db = b['date'] as DateTime?;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Existing Entry to Update',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 12),
                if (_existingEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No past entries found for this site.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _existingEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _existingEntries[index];
                        final dateStr = entry['date'] != null
                            ? DateFormat('yyyy-MM-dd HH:mm')
                                .format(entry['date'])
                            : 'Unknown Date';
                        return ListTile(
                          leading: Icon(
                            Icons.receipt_long_rounded,
                            color: primaryColor,
                          ),
                          title: Text(
                            dateStr,
                            style: const TextStyle(
                              color: Color(0xFF0A183D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadEntryForUpdate(
                              entry['docId'],
                              entry['data'],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load past entries: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingEntryDates = false);
    }
  }

  void _loadEntryForUpdate(String docId, Map<String, dynamic> data) {
    setState(() {
      isUpdateMode = true;
      _updateDocId = docId;

      if (data['date'] is Timestamp) {
        _selectedUpdateDate = (data['date'] as Timestamp).toDate();
      } else if (data['createdAt'] is Timestamp) {
        _selectedUpdateDate = (data['createdAt'] as Timestamp).toDate();
      }
      if (_selectedUpdateDate != null) {
        selectedDate = _selectedUpdateDate;
      }

      materials = List<Map<String, dynamic>>.from(
        (data['materials'] as List? ?? []).map((m) {
          final map = Map<String, dynamic>.from(m as Map);
          final type = map['type']?.toString() ?? '';
          final qty = map['quantity'] is num
              ? (map['quantity'] as num).toInt()
              : (int.tryParse(map['quantity']?.toString() ?? '0') ?? 0);
          final price = map['unitPrice'] is num
              ? map['unitPrice'] as num
              : (num.tryParse(map['unitPrice']?.toString() ?? '0') ??
                  (materialPrices[type] ?? 0));
          return {
            'type': type,
            'quantity': qty,
            'unitPrice': price,
          };
        }),
      );

      labours = List<Map<String, dynamic>>.from(
        (data['labours'] as List? ?? []).map((l) {
          final map = Map<String, dynamic>.from(l as Map);
          final type = map['type']?.toString() ?? '';
          final count = map['count'] is num
              ? (map['count'] as num).toInt()
              : (int.tryParse(map['count']?.toString() ?? '0') ?? 0);
          final sal = map['salary'] is num
              ? map['salary'] as num
              : (num.tryParse(map['salary']?.toString() ?? '0') ??
                  (labourSalaries[type] ?? 0));
          return {
            'type': type,
            'count': count,
            'salary': sal,
          };
        }),
      );

      final expenses = data['expenses'] as Map<String, dynamic>? ?? {};
      foodCost.text = (expenses['foodCost'] ?? 0).toString();
      transportCost.text = (expenses['transportCost'] ?? 0).toString();
      fuelCost.text = (expenses['fuelCost'] ?? 0).toString();

      morningStatusController.text = data['morningStatus']?.toString() ?? '';
      afternoonStatusController.text =
          data['afternoonStatus']?.toString() ?? '';
    });
  }

  Future<void> _updateExistingEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);
    try {
      final entryData = {
        'siteCode': selectedSiteId,
        'supervisor': supervisorName,
        'supervisorId': supervisorId,
        'location': siteLocation,
        'projectStage': projectStage,
        'projectName': projectName,
        'date': selectedDate != null
            ? Timestamp.fromDate(selectedDate!)
            : FieldValue.serverTimestamp(),
        'materials': materials,
        'labours': labours,
        'expenses': {
          'foodCost': num.tryParse(foodCost.text) ?? 0,
          'transportCost': num.tryParse(transportCost.text) ?? 0,
          'fuelCost': num.tryParse(fuelCost.text) ?? 0,
          'totalExpense': _getTotalExpenses(),
        },
        'morningStatus': morningStatusController.text.trim(),
        'afternoonStatus': afternoonStatusController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.userName,
      };

      await FirestoreService.getCollection('ManagerSiteEntry')
          .doc(_updateDocId)
          .update(entryData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site entry updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
        setState(() {
          isUpdateMode = false;
          _updateDocId = null;
          _selectedUpdateDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Site Entry',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
        ),
        content: Text(
          'Are you sure you want to save entry for site "$selectedSiteId"? Total Amount: ₹${_getTotalAmount()}',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 1.5,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _saveSiteEntry();
    }
  }

  Future<void> _saveSiteEntry() async {
    setState(() => isSaving = true);
    try {
      final entryData = {
        'siteCode': selectedSiteId,
        'supervisor': supervisorName,
        'supervisorId': supervisorId,
        'location': siteLocation,
        'projectStage': projectStage,
        'projectName': projectName,
        'date': selectedDate != null
            ? Timestamp.fromDate(selectedDate!)
            : FieldValue.serverTimestamp(),
        'materials': materials,
        'labours': labours,
        'expenses': {
          'foodCost': num.tryParse(foodCost.text) ?? 0,
          'transportCost': num.tryParse(transportCost.text) ?? 0,
          'fuelCost': num.tryParse(fuelCost.text) ?? 0,
          'totalExpense': _getTotalExpenses(),
        },
        'morningStatus': morningStatusController.text.trim(),
        'afternoonStatus': afternoonStatusController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userName,
      };

      await FirestoreService.getCollection('ManagerSiteEntry').add(entryData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site entry saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
      selectedDate = DateTime.now();
      _showCustomMaterialFields = false;
      _showCustomLabourFields = false;
    });
  }

  num _getTotalExpenses() {
    final food = num.tryParse(foodCost.text) ?? 0;
    final transport = num.tryParse(transportCost.text) ?? 0;
    final fuel = num.tryParse(fuelCost.text) ?? 0;
    return food + transport + fuel;
  }

  num _getTotalAmount() {
    num total = 0;
    for (var m in materials) {
      final qty = m['quantity'] is num
          ? (m['quantity'] as num)
          : (num.tryParse(m['quantity']?.toString() ?? '0') ?? 0);
      final price = (m['unitPrice'] is num && (m['unitPrice'] as num) > 0)
          ? (m['unitPrice'] as num)
          : (materialPrices[m['type']] ?? 0);
      total += qty * price;
    }
    for (var l in labours) {
      final count = l['count'] is num
          ? (l['count'] as num)
          : (num.tryParse(l['count']?.toString() ?? '0') ?? 0);
      final sal = (l['salary'] is num && (l['salary'] as num) > 0)
          ? (l['salary'] as num)
          : (labourSalaries[l['type']] ?? 0);
      total += count * sal;
    }
    total += _getTotalExpenses();
    return total;
  }

  String _calculateMaterialAmount(String type, int qty, [num? customPrice]) {
    final price = (customPrice != null && customPrice > 0)
        ? customPrice
        : (materialPrices[type] ?? 0);
    return '₹${(qty * price).toStringAsFixed(0)}';
  }

  String _calculateLabourAmount(String type, int count, [num? customSalary]) {
    final sal = (customSalary != null && customSalary > 0)
        ? customSalary
        : (labourSalaries[type] ?? 0);
    return '₹${(count * sal).toStringAsFixed(0)}';
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Manager Daily Site Entry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      darkAccent,
                      Color.alphaBlend(
                        primaryColor.withValues(alpha: 0.35),
                        darkAccent,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Site Information Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.construction_rounded,
                                size: 22,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: isLoadingSites
                                  ? const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        initialValue: siteList.any((s) => s['siteId'] == selectedSiteId)
                                            ? selectedSiteId
                                            : null,
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        iconEnabledColor: const Color(0xFF0A183D),
                                        borderRadius: BorderRadius.circular(14),
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Select Site ID',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                        items: siteList
                                            .map(
                                              (site) => DropdownMenuItem(
                                                value: site['siteId'],
                                                child: Text(
                                                  SiteDisplayHelper.formatSiteDisplay(
                                                    siteId: site['siteId'],
                                                    siteName: site['siteName'],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF0A183D),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.person_rounded,
                          'Supervisor',
                          supervisorName ?? '-',
                        ),
                        if (supervisorId != null && supervisorId!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 24.0, top: 2),
                            child: Text(
                              'ID: ${supervisorId ?? '-'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.location_on_rounded,
                          'Location',
                          siteLocation ?? '-',
                        ),
                        _buildInfoRow(
                          Icons.timeline_rounded,
                          'Project Stage',
                          projectStage ?? '-',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                selectedDate != null
                                    ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                                    : 'No date chosen',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A183D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            if (!isUpdateMode)
                              TextButton.icon(
                                onPressed: _pickDate,
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                label: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Update Entry Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Update Entry'),
                        const SizedBox(height: 12),
                        if (isUpdateMode && _selectedUpdateDate != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              'Loaded entry for: ${DateFormat('yyyy-MM-dd').format(_selectedUpdateDate!)}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: isLoadingSites ||
                                          selectedSiteId == null ||
                                          selectedSiteId!.isEmpty
                                      ? null
                                      : _openUpdateEntrySelector,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 1.5,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  label: const Text(
                                    'Select Existing Entry',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isUpdateMode) const SizedBox(width: 10),
                            if (isUpdateMode)
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        isUpdateMode = false;
                                        _updateDocId = null;
                                        _selectedUpdateDate = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0A183D),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text(
                                      'Exit Update',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0A183D),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form Section Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Add Entry Details',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Material Section Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Material Details'),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 3,
                              child: isLoadingMaterials
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        _buildTextField(
                                          'Search Material',
                                          null,
                                          hintText: 'Search Material...',
                                          icon: Icons.search_rounded,
                                          onChanged: (query) {
                                            setState(() {
                                              final q = query.toLowerCase();
                                              final filtered = materialOptions
                                                  .where(
                                                    (item) => item
                                                        .toLowerCase()
                                                        .contains(q),
                                                  )
                                                  .toList();
                                              if (filtered.isNotEmpty) {
                                                selectedMaterial =
                                                    filtered.contains(selectedMaterial)
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
                                        _buildMaterialDropdown(),
                                      ],
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildQtyField(
                                'Qty',
                                materialQtyController,
                                onChanged: (value) {
                                  setState(() {
                                    materialQty = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1.5,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              onPressed: isLoadingMaterials || materialOptions.isEmpty
                                  ? null
                                  : _addMaterial,
                              label: const Text(
                                'Add Material',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(
                              _showCustomMaterialFields
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: primaryColor,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCustomMaterialFields = !_showCustomMaterialFields;
                              });
                            },
                            label: Text(
                              _showCustomMaterialFields
                                  ? 'Hide Other Materials'
                                  : 'Other Materials',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        if (_showCustomMaterialFields) ...[
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Material Name',
                            _customMaterialNameController,
                            hintText: 'Enter material name',
                          ),
                          const SizedBox(height: 10),
                          _buildQtyField(
                            'Qty',
                            _customMaterialQtyController,
                          ),
                          const SizedBox(height: 10),
                          _buildQtyField(
                            'Unit Price',
                            _customMaterialPriceController,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.check, size: 18, color: primaryColor),
                                label: Text(
                                  'ADD OTHER MATERIAL',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                onPressed: _addCustomMaterial,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: primaryColor, width: 1.2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Labour Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Labour Details'),
                        const SizedBox(height: 16),
                        isLoadingLabours
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Column(
                                children: [
                                  _buildTextField(
                                    'Search Labour',
                                    null,
                                    hintText: 'Search Labour...',
                                    icon: Icons.search_rounded,
                                    onChanged: (query) {
                                      setState(() {
                                        final q = query.toLowerCase();
                                        final filtered = labourOptions
                                            .where(
                                              (item) => item
                                                  .toLowerCase()
                                                  .contains(q),
                                            )
                                            .toList();
                                        if (filtered.isNotEmpty) {
                                          selectedLabour =
                                              filtered.contains(selectedLabour)
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
                                  _buildLabourDropdown(),
                                ],
                              ),
                        const SizedBox(height: 14),
                        _buildQtyField(
                          'Count',
                          labourQtyController,
                          onChanged: (value) {
                            setState(() {
                              labourQty = int.tryParse(value) ?? 0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.person_add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1.5,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              onPressed: isLoadingLabours || labourOptions.isEmpty
                                  ? null
                                  : _addLabour,
                              label: const Text(
                                'Add Labour',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(
                              _showCustomLabourFields
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: primaryColor,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCustomLabourFields = !_showCustomLabourFields;
                              });
                            },
                            label: Text(
                              _showCustomLabourFields
                                  ? 'Hide Custom Labour'
                                  : 'Add Custom Labour',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        if (_showCustomLabourFields) ...[
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Labour Type',
                            _customLabourNameController,
                            hintText: 'Enter designation',
                          ),
                          const SizedBox(height: 10),
                          _buildQtyField(
                            'Salary',
                            _customLabourSalaryController,
                          ),
                          const SizedBox(height: 10),
                          _buildQtyField('Count', _customLabourQtyController),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.check, size: 18, color: primaryColor),
                                label: Text(
                                  'ADD CUSTOM',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                onPressed: _addCustomLabour,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: primaryColor, width: 1.2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Other Expenses Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Other Expenses'),
                        const SizedBox(height: 16),
                        _buildQtyField(
                          'Food (₹)',
                          foodCost,
                          icon: Icons.fastfood_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _buildQtyField(
                          'Transport (₹)',
                          transportCost,
                          icon: Icons.directions_car_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _buildQtyField(
                          'Fuel (₹)',
                          fuelCost,
                          icon: Icons.local_gas_station_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.add_rounded, size: 18, color: primaryColor),
                              label: Text(
                                'Add Expenses',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: primaryColor, width: 1.2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today's Summary Card
                  if (materials.isNotEmpty ||
                      labours.isNotEmpty ||
                      (int.tryParse(foodCost.text) ?? 0) > 0 ||
                      (int.tryParse(transportCost.text) ?? 0) > 0 ||
                      (int.tryParse(fuelCost.text) ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Summary (Total: ₹${_getTotalAmount()})',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSummaryTable(),
                        ],
                      ),
                    ),
                  if (materials.isNotEmpty ||
                      labours.isNotEmpty ||
                      (int.tryParse(foodCost.text) ?? 0) > 0 ||
                      (int.tryParse(transportCost.text) ?? 0) > 0 ||
                      (int.tryParse(fuelCost.text) ?? 0) > 0)
                    const SizedBox(height: 20),

                  // Bottom Save & Reset Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : (isUpdateMode
                                      ? _updateExistingEntry
                                      : _showConfirmationDialog),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1.5,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isUpdateMode
                                              ? Icons.update_rounded
                                              : Icons.save_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isUpdateMode ? 'UPDATE' : 'SAVE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _resetForm,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0A183D),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: Color(0xFF0A183D),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'RESET',
                                    style: TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Builders

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        color: Color(0xFF0A183D),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              fontSize: 13.5,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final isRequired = label.contains('*');
    final cleanText = label.replaceAll('*', '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: cleanText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
            letterSpacing: -0.1,
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedMaterial,
      isExpanded: true,
      dropdownColor: Colors.white,
      iconEnabledColor: const Color(0xFF0A183D),
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(
        color: Color(0xFF0A183D),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: 'Select Material',
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.category_rounded,
            color: primaryColor,
            size: 18,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12.5,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      items: (_filteredMaterialOptions ?? materialOptions)
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => selectedMaterial = value),
    );
  }

  Widget _buildLabourDropdown() {
    final currentOptions = _filteredLabourOptions ?? labourOptions;
    return DropdownButtonFormField<String>(
      initialValue: selectedLabour,
      isExpanded: true,
      dropdownColor: Colors.white,
      iconEnabledColor: const Color(0xFF0A183D),
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(
        color: Color(0xFF0A183D),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: 'Select Labour',
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.engineering_rounded,
            color: primaryColor,
            size: 18,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12.5,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      items: currentOptions
          .map(
            (l) => DropdownMenuItem(
              value: l,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if ((labourSalaries[l] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${labourSalaries[l]}/day',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => selectedLabour = v),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController? ctrl, {
    String? hintText,
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText ?? 'Enter $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(icon, color: primaryColor, size: 18),
                  )
                : null,
            prefixIconConstraints: icon != null
                ? const BoxConstraints(minWidth: 38, minHeight: 38)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: '0',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(icon, color: primaryColor, size: 18),
                  )
                : null,
            prefixIconConstraints: icon != null
                ? const BoxConstraints(minWidth: 38, minHeight: 38)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFFF1F5F9),
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Item',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Qty',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Amt',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
          ),
          DataColumn(label: Text('')),
        ],
        rows: [
          ...materials.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(Text(
                  e.value['type']?.toString() ?? '',
                  style: const TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(Text(
                  '${e.value['quantity'] ?? 0}',
                  style: const TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(
                  Text(
                    _calculateMaterialAmount(
                      e.value['type']?.toString() ?? '',
                      e.value['quantity'] is num
                          ? (e.value['quantity'] as num).toInt()
                          : (int.tryParse(e.value['quantity']?.toString() ?? '0') ?? 0),
                      e.value['unitPrice'],
                    ),
                    style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
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
                DataCell(Text(
                  e.value['type']?.toString() ?? '',
                  style: const TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(Text(
                  '${e.value['count'] ?? 0}',
                  style: const TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(
                  Text(
                    _calculateLabourAmount(
                      e.value['type']?.toString() ?? '',
                      e.value['count'] is num
                          ? (e.value['count'] as num).toInt()
                          : (int.tryParse(e.value['count']?.toString() ?? '0') ?? 0),
                      e.value['salary'],
                    ),
                    style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
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
                const DataCell(Text(
                  'Food',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(Text(
                  '₹${foodCost.text}',
                  style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    onPressed: () => setState(() => foodCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(transportCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text(
                  'Transport',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(Text(
                  '₹${transportCost.text}',
                  style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    onPressed: () => setState(() => transportCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(fuelCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text(
                  'Fuel',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Color(0xFF0A183D)),
                )),
                DataCell(Text(
                  '₹${fuelCost.text}',
                  style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
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
