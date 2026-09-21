import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/material_inventory_service.dart';
import 'package:ebricks/services/offline_sync_service.dart';
import 'package:ebricks/widgets/offline_sync_banner.dart';
import 'package:ebricks/widgets/glass_card.dart';
import 'package:ebricks/widgets/glass_button.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class SiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  final bool hideAppBar;

  const SiteEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
    this.hideAppBar = false,
  });

  @override
  State<SiteEntryPage> createState() => _SiteEntryPageState();
}

class _SiteEntryPageState extends State<SiteEntryPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> labours = [];
  String? selectedMaterial;
  num materialQty = 0;
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

  // Site Mapped Labour State
  Map<String, int> siteMappedLabourCounts = {};

  // Site Material Pool State
  List<SiteMaterialPoolItem> sitePoolItems = [];
  bool isLoadingSitePool = false;

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
    // Pre-initialize state directly from passed userDetails if available
    final rawPassedSiteId = (widget.userDetails['siteId'] ?? '').toString().trim();
    if (rawPassedSiteId.isNotEmpty) {
      var passedSiteId = ExpenseService.formatCanonicalSiteId(rawId: rawPassedSiteId);
      if (passedSiteId.toUpperCase().startsWith('PR')) {
        passedSiteId = 'ST${passedSiteId.substring(2)}';
      }
      selectedSiteId = passedSiteId;
      siteCode = passedSiteId;
    }
    final passedLocation = (widget.userDetails['location'] ?? '').toString().trim();
    if (passedLocation.isNotEmpty) {
      siteLocation = passedLocation;
    }
    final passedSupId = (widget.userDetails['supervisorId'] ?? '').toString().trim();
    if (passedSupId.isNotEmpty) {
      supervisorId = passedSupId;
    }
    final passedProject = (widget.userDetails['projectName'] ?? '').toString().trim();
    if (passedProject.isNotEmpty) {
      projectName = passedProject;
    }
    final passedStage = (widget.userDetails['projectStage'] ?? '').toString().trim();
    if (passedStage.isNotEmpty) {
      selectedProjectPhase = passedStage;
    }
    supervisorName = widget.userName;

    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSupervisorData();
    _fetchProjectPhases();
    _fetchSiteMaterialPool();
    _fetchSiteLabourMapping();
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
        projectPhaseError = 'Failed to load project stages';
        isLoadingProjectPhases = false;
      });
    }
  }

  Future<void> _fetchSupervisorData() async {
    try {
      final String? passedSupervisorId = widget.userDetails['supervisorId']?.toString().trim();
      final String passedName = widget.userName.trim();

      var snapshot = await FirestoreService.siteSupervisorMap
          .where('Supervisor ID', isEqualTo: passedSupervisorId)
          .get();

      if (snapshot.docs.isEmpty && passedSupervisorId != null && passedSupervisorId.isNotEmpty) {
        snapshot = await FirestoreService.siteSupervisorMap
            .where('supervisorId', isEqualTo: passedSupervisorId)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        snapshot = await FirestoreService.siteSupervisorMap
            .where('supervisor', isEqualTo: passedName)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        snapshot = await FirestoreService.siteSupervisorMap
            .where('supervisorName', isEqualTo: passedName)
            .get();
      }

      List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = snapshot.docs;
      if (allDocs.isEmpty) {
        final broadSnap = await FirestoreService.siteSupervisorMap.get();
        allDocs = broadSnap.docs.where((doc) {
          final data = doc.data();
          final sId = (data['Supervisor ID'] ?? data['supervisorId'] ?? '').toString().trim().toLowerCase();
          final sName = (data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim().toLowerCase();
          final docId = doc.id.trim().toLowerCase();
          return (passedSupervisorId != null && passedSupervisorId.isNotEmpty && (sId == passedSupervisorId.toLowerCase() || docId.contains(passedSupervisorId.toLowerCase()))) ||
                 (passedName.isNotEmpty && (sName == passedName.toLowerCase() || docId.contains(passedName.toLowerCase())));
        }).toList();
      }

      final List<Map<String, String>> rawSites = [];

      for (var doc in allDocs) {
        final data = doc.data();
        final sDocId = (data['siteDocId'] ?? '').toString().trim();
        final rawSite = (data['site'] ?? data['siteDocId'] ?? '').toString().trim();
        final rawSiteId = (data['siteCode'] ?? data['siteId'] ?? '').toString().trim();
        final rawSiteName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim();

        String baseId = sDocId.isNotEmpty ? sDocId : rawSite;
        if (baseId.isEmpty && doc.id.contains('_') && (doc.id.startsWith('ST') || doc.id.startsWith('PR'))) {
          baseId = doc.id;
        }

        var canonicalId = ExpenseService.formatCanonicalSiteId(
          rawId: baseId.isNotEmpty ? baseId : (rawSiteId.isNotEmpty ? rawSiteId : doc.id),
          siteCode: rawSiteId.isNotEmpty ? rawSiteId : null,
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
            'supervisor': (data['supervisor'] ?? data['supervisorName'] ?? widget.userName).toString(),
            'location': (data['location'] ?? 'Unknown').toString(),
            'supervisorId': (data['Supervisor ID'] ?? data['supervisorId'] ?? '').toString(),
            'projectName': (data['projectName'] ?? data['project'] ?? '').toString(),
            'projectStage': (data['projectStage'] ?? data['stage'] ?? '').toString(),
          });
        }
      }

      // If siteSupervisorMap had no sites for this supervisor, check Site collection
      if (rawSites.isEmpty) {
        final siteSnap = await FirestoreService.sites.get();
        for (var doc in siteSnap.docs) {
          final data = doc.data();
          final sId = (data['Supervisor ID'] ?? data['supervisorId'] ?? '').toString().trim().toLowerCase();
          final sName = (data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim().toLowerCase();
          if ((passedSupervisorId != null && passedSupervisorId.isNotEmpty && sId == passedSupervisorId.toLowerCase()) ||
              (passedName.isNotEmpty && sName == passedName.toLowerCase())) {
            final code = (data['siteCode'] ?? data['siteId'])?.toString().trim();
            final name = (data['siteName'] ?? data['projectName'])?.toString().trim();
            var canonicalId = ExpenseService.formatCanonicalSiteId(
              rawId: doc.id,
              siteCode: code,
              siteName: name,
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
                'supervisor': (data['supervisor'] ?? widget.userName).toString(),
                'location': (data['location'] ?? 'Unknown').toString(),
                'supervisorId': (data['Supervisor ID'] ?? data['supervisorId'] ?? '').toString(),
                'projectName': (data['projectName'] ?? name ?? '').toString(),
                'projectStage': (data['projectStage'] ?? '').toString(),
              });
            }
          }
        }
      }

      // If still empty, check widget.userDetails['siteId']
      if (rawSites.isEmpty && (widget.userDetails['siteId'] ?? '').toString().trim().isNotEmpty) {
        final userSite = widget.userDetails['siteId'].toString().trim();
        final details = await ExpenseService.resolveSiteDetails(userSite);
        rawSites.add({
          'siteId': details.canonicalDocId,
          'supervisor': details.supervisor ?? widget.userName,
          'location': details.location ?? 'Unknown',
          'supervisorId': details.supervisorId ?? widget.userDetails['supervisorId']?.toString() ?? '',
          'projectName': details.projectName ?? 'Not found',
          'projectStage': details.projectStage ?? '',
        });
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
          siteName: s['siteName'] ?? s['projectName'],
        );
        final displayKey = displayLabel.toLowerCase();

        final existingKey = uniqueSites.keys.firstWhere(
          (k) => k.toLowerCase() == id.toLowerCase() ||
                 k.split('_').first.toUpperCase() == siteCodeKey ||
                 SiteDisplayHelper.formatSiteDisplay(
                   siteId: uniqueSites[k]!['siteId'],
                   siteName: uniqueSites[k]!['siteName'] ?? uniqueSites[k]!['projectName'],
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
                    existing[entry.key] == '' ||
                    existing[entry.key] == 'Unknown' ||
                    existing[entry.key] == 'Not found') &&
                entry.value.isNotEmpty &&
                entry.value != 'Unknown' &&
                entry.value != 'Not found') {
              existing[entry.key] = entry.value;
            }
          }
        }
      }

      final sites = uniqueSites.values.toList();
      sites.sort((a, b) => (a['siteId'] ?? '').compareTo(b['siteId'] ?? ''));

      setState(() {
        supervisorSites = sites;
        if (sites.isNotEmpty) {
          String passedSiteId = ExpenseService.formatCanonicalSiteId(
            rawId: widget.userDetails['siteId']?.toString() ?? '',
          );
          if (passedSiteId.toUpperCase().startsWith('PR')) {
            passedSiteId = 'ST${passedSiteId.substring(2)}';
          }
          var matchedSite = sites.first;
          if (passedSiteId.isNotEmpty) {
            matchedSite = sites.firstWhere(
              (s) => s['siteId'] == passedSiteId || s['siteId']!.toLowerCase() == passedSiteId.toLowerCase(),
              orElse: () => sites.first,
            );
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
        }
      });

      if (selectedSiteId != null) {
        final details = await ExpenseService.resolveSiteDetails(selectedSiteId!);
        if (mounted && selectedSiteId == details.canonicalDocId) {
          setState(() {
            if (supervisorName == null || supervisorName!.isEmpty || supervisorName == widget.userName) {
              if (details.supervisor != null && details.supervisor!.isNotEmpty) {
                supervisorName = details.supervisor;
              }
            }
            if (supervisorId == null || supervisorId!.isEmpty) {
              if (details.supervisorId != null && details.supervisorId!.isNotEmpty) {
                supervisorId = details.supervisorId;
              }
            }
            if (siteLocation.isEmpty || siteLocation == 'Unknown') {
              if (details.location != null && details.location!.isNotEmpty) {
                siteLocation = details.location!;
              }
            }
            if (projectName == null || projectName!.isEmpty || projectName == 'Not found') {
              if (details.projectName != null && details.projectName!.isNotEmpty) {
                projectName = details.projectName;
              }
            }
            if (selectedProjectPhase == null || selectedProjectPhase!.isEmpty) {
              if (details.projectStage != null && details.projectStage!.isNotEmpty) {
                selectedProjectPhase = details.projectStage;
              }
            }
          });
        }
      }
      _fetchSiteMaterialPool();
      _fetchSiteLabourMapping();
    } catch (e) {
      debugPrint('Error fetching supervisor data in site_entry_page: $e');
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
      if (OfflineSyncService().isOnline) {
        final orgId = getOrgId();
        final snapshot = await FirebaseFirestore.instance
            .collection('organisation')
            .doc(orgId)
            .collection('materials')
            .get();
        final options = <String>[];
        final prices = <String, num>{};
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['materialName'] ?? data['name'] ?? '').toString().trim();
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
        materialOptions = options;
        materialPrices = prices;

        await OfflineSyncService.cacheMasterData('materials_list', materialOptions);
        await OfflineSyncService.cacheMasterData('materials_prices', materialPrices);
      } else {
        final cachedOptions = await OfflineSyncService.getCachedMasterData('materials_list');
        final cachedPrices = await OfflineSyncService.getCachedMasterData('materials_prices');
        if (cachedOptions is List) {
          materialOptions = cachedOptions.map((e) => e.toString()).toList();
        }
        if (cachedPrices is Map) {
          materialPrices = Map<String, num>.from(
            cachedPrices.map((k, v) => MapEntry(k.toString(), (v as num))),
          );
        }
      }

      setState(() {
        selectedMaterial = materialOptions.isNotEmpty
            ? materialOptions.first
            : null;
        isLoadingMaterials = false;
      });
    } catch (e) {
      final cachedOptions = await OfflineSyncService.getCachedMasterData('materials_list');
      final cachedPrices = await OfflineSyncService.getCachedMasterData('materials_prices');
      if (cachedOptions is List) {
        materialOptions = cachedOptions.map((e) => e.toString()).toList();
      }
      if (cachedPrices is Map) {
        materialPrices = Map<String, num>.from(
          cachedPrices.map((k, v) => MapEntry(k.toString(), (v as num))),
        );
      }

      setState(() {
        selectedMaterial = materialOptions.isNotEmpty ? materialOptions.first : null;
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
      if (OfflineSyncService().isOnline) {
        final orgId = getOrgId();
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
                    num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
              }
              salaries[designation] = salary;
            }
          }
        }
        labourOptions = options;
        labourSalaries = salaries;

        await OfflineSyncService.cacheMasterData('labours_list', labourOptions);
        await OfflineSyncService.cacheMasterData('labours_salaries', labourSalaries);
      } else {
        final cachedOptions = await OfflineSyncService.getCachedMasterData('labours_list');
        final cachedSalaries = await OfflineSyncService.getCachedMasterData('labours_salaries');
        if (cachedOptions is List) {
          labourOptions = cachedOptions.map((e) => e.toString()).toList();
        }
        if (cachedSalaries is Map) {
          labourSalaries = Map<String, num>.from(
            cachedSalaries.map((k, v) => MapEntry(k.toString(), (v as num))),
          );
        }
      }

      setState(() {
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    } catch (e) {
      final cachedOptions = await OfflineSyncService.getCachedMasterData('labours_list');
      final cachedSalaries = await OfflineSyncService.getCachedMasterData('labours_salaries');
      if (cachedOptions is List) {
        labourOptions = cachedOptions.map((e) => e.toString()).toList();
      }
      if (cachedSalaries is Map) {
        labourSalaries = Map<String, num>.from(
          cachedSalaries.map((k, v) => MapEntry(k.toString(), (v as num))),
        );
      }

      setState(() {
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    }
  }

  Future<void> _fetchSiteLabourMapping() async {
    final targetSite = (selectedSiteId ?? siteCode).trim();
    if (targetSite.isEmpty) {
      if (mounted) {
        setState(() {
          siteMappedLabourCounts = {};
          labourOptions = [];
          _filteredLabourOptions = null;
          selectedLabour = null;
          isLoadingLabours = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingLabours = true;
        labourError = null;
      });
    }

    final String cleanSiteCode = targetSite.split('_').first.trim().toLowerCase();
    final String cleanSiteName = (projectName ?? siteLocation).trim().toLowerCase();
    final String rawDocId = targetSite.toLowerCase();

    bool matchesSiteKey(String key) {
      final clean = key.trim().toLowerCase();
      if (clean.isEmpty) return false;
      if (clean == cleanSiteCode || clean == cleanSiteName || clean == rawDocId) return true;
      if (cleanSiteCode.isNotEmpty && (clean.startsWith('${cleanSiteCode}_') || clean.endsWith('_$cleanSiteCode') || clean == cleanSiteCode)) {
        return true;
      }
      if (cleanSiteName.isNotEmpty && (clean.startsWith('${cleanSiteName}_') || clean.endsWith('_$cleanSiteName') || clean == cleanSiteName)) {
        return true;
      }
      return false;
    }

    try {
      final Map<String, Map<String, dynamic>> dedupWorkers = {};
      final Map<String, num> mappedSalaries = {};

      if (OfflineSyncService().isOnline) {
        // 1. Check primary workerSiteMapping collection
        final snap = await FirestoreService.getCollection('workerSiteMapping').get();
        for (final doc in snap.docs) {
          final docId = doc.id.trim().toLowerCase();
          final data = doc.data();
          final dSiteId = (data['siteId'] ?? '').toString();
          final dSite = (data['site'] ?? '').toString();
          final dSiteName = (data['siteName'] ?? '').toString();
          final dProjectName = (data['projectName'] ?? '').toString();

          final isMatch = matchesSiteKey(docId) ||
              matchesSiteKey(dSiteId) ||
              matchesSiteKey(dSite) ||
              matchesSiteKey(dSiteName) ||
              matchesSiteKey(dProjectName);

          if (isMatch) {
            final raw = (data['workers'] ?? data['mappedWorkers'] ?? data['workerList']) as List<dynamic>? ?? [];
            for (final item in raw) {
              if (item is Map) {
                final w = Map<String, dynamic>.from(item);
                final name = (w['workerName'] ?? w['name'] ?? w['fullName'] ?? w['worker_name'] ?? '').toString().trim();
                if (name.isNotEmpty) {
                  final wId = (w['workerId'] ?? w['id'] ?? w['worker_id'] ?? name).toString().trim();
                  final key = '${wId}_$name'.toLowerCase();
                  final desig = (w['workerDesignation'] ?? w['designation'] ?? w['role'] ?? 'Labour').toString().trim();
                  final salRaw = (w['workerSalary'] ?? w['salary'] ?? w['wage'] ?? '0').toString();
                  final sal = num.tryParse(salRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;

                  dedupWorkers[key] = {
                    'workerId': wId,
                    'workerName': name,
                    'workerDesignation': desig,
                    'workerSalary': sal,
                  };
                  if (sal > 0) {
                    mappedSalaries[desig] = sal;
                  }
                }
              }
            }
          }
        }

        // 2. Fallback to legacy workerSiteMap if empty
        if (dedupWorkers.isEmpty) {
          final legacySnap = await FirestoreService.getCollection('workerSiteMap').get();
          for (final doc in legacySnap.docs) {
            final docId = doc.id.trim().toLowerCase();
            final data = doc.data();
            final dSiteId = (data['siteId'] ?? '').toString();
            final dSite = (data['site'] ?? '').toString();
            final dSiteName = (data['siteName'] ?? '').toString();
            final dProjectName = (data['projectName'] ?? '').toString();

            final isMatch = matchesSiteKey(docId) ||
                matchesSiteKey(dSiteId) ||
                matchesSiteKey(dSite) ||
                matchesSiteKey(dSiteName) ||
                matchesSiteKey(dProjectName);

            if (isMatch) {
              final raw = (data['workers'] ?? data['mappedWorkers'] ?? data['workerList']) as List<dynamic>? ?? [];
              for (final item in raw) {
                if (item is Map) {
                  final w = Map<String, dynamic>.from(item);
                  final name = (w['workerName'] ?? w['name'] ?? w['fullName'] ?? w['worker_name'] ?? '').toString().trim();
                  if (name.isNotEmpty) {
                    final wId = (w['workerId'] ?? w['id'] ?? w['worker_id'] ?? name).toString().trim();
                    final key = '${wId}_$name'.toLowerCase();
                    final desig = (w['workerDesignation'] ?? w['designation'] ?? w['role'] ?? 'Labour').toString().trim();
                    final salRaw = (w['workerSalary'] ?? w['salary'] ?? w['wage'] ?? '0').toString();
                    final sal = num.tryParse(salRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;

                    dedupWorkers[key] = {
                      'workerId': wId,
                      'workerName': name,
                      'workerDesignation': desig,
                      'workerSalary': sal,
                    };
                    if (sal > 0) {
                      mappedSalaries[desig] = sal;
                    }
                  }
                }
              }
            }
          }
        }

        // Group counts by designation
        final Map<String, int> counts = {};
        for (final w in dedupWorkers.values) {
          final desig = (w['workerDesignation'] as String?)?.trim() ?? 'Labour';
          if (desig.isNotEmpty) {
            counts[desig] = (counts[desig] ?? 0) + 1;
          }
        }

        final options = counts.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        // Cache for offline support
        await OfflineSyncService.cacheMasterData('site_labours_counts_$targetSite', counts);
        await OfflineSyncService.cacheMasterData('site_labours_options_$targetSite', options);
        await OfflineSyncService.cacheMasterData('site_labours_salaries_$targetSite', mappedSalaries);

        if (!mounted) return;
        setState(() {
          siteMappedLabourCounts = counts;
          labourOptions = options;
          _filteredLabourOptions = null;
          labourSalaries.addAll(mappedSalaries);
          if (options.isNotEmpty) {
            if (selectedLabour == null || !options.contains(selectedLabour)) {
              selectedLabour = options.first;
            }
          } else {
            selectedLabour = null;
          }
          isLoadingLabours = false;
        });
      } else {
        // Offline retrieval
        final cachedCounts = await OfflineSyncService.getCachedMasterData('site_labours_counts_$targetSite');
        final cachedOptions = await OfflineSyncService.getCachedMasterData('site_labours_options_$targetSite');
        final cachedSalaries = await OfflineSyncService.getCachedMasterData('site_labours_salaries_$targetSite');

        Map<String, int> counts = {};
        List<String> options = [];
        Map<String, num> salaries = {};

        if (cachedCounts is Map) {
          counts = Map<String, int>.from(cachedCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
        }
        if (cachedOptions is List) {
          options = cachedOptions.map((e) => e.toString()).toList();
        }
        if (cachedSalaries is Map) {
          salaries = Map<String, num>.from(cachedSalaries.map((k, v) => MapEntry(k.toString(), (v as num))));
        }

        if (!mounted) return;
        setState(() {
          siteMappedLabourCounts = counts;
          labourOptions = options;
          _filteredLabourOptions = null;
          labourSalaries.addAll(salaries);
          if (options.isNotEmpty) {
            if (selectedLabour == null || !options.contains(selectedLabour)) {
              selectedLabour = options.first;
            }
          } else {
            selectedLabour = null;
          }
          isLoadingLabours = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site labour mapping in site_entry_page: $e');
      if (!mounted) return;
      setState(() {
        isLoadingLabours = false;
      });
    }
  }

  String _formatQty(num qty) {
    if (qty.truncateToDouble() == qty) {
      return qty.toInt().toString();
    }
    return qty.toString();
  }

  Future<void> _fetchSiteMaterialPool() async {
    if (siteCode.isEmpty) {
      if (mounted) {
        setState(() {
          sitePoolItems = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        isLoadingSitePool = true;
      });
    }
    try {
      final pool = await MaterialInventoryService.fetchSiteMaterialPool(siteCode);
      if (!mounted) return;
      setState(() {
        sitePoolItems = pool;
        isLoadingSitePool = false;
        if (pool.isNotEmpty) {
          final hasCurrent = selectedMaterial != null &&
              pool.any((p) => p.materialName.toLowerCase().trim() == selectedMaterial!.toLowerCase().trim() ||
                  p.displayName.toLowerCase().trim() == selectedMaterial!.toLowerCase().trim());
          if (!hasCurrent) {
            final withStock = pool.where((p) => p.remainingQty > 0).toList();
            if (withStock.isNotEmpty) {
              selectedMaterial = withStock.first.materialName;
            } else {
              selectedMaterial = pool.first.materialName;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching site material pool in site_entry_page: $e');
      if (mounted) {
        setState(() {
          isLoadingSitePool = false;
        });
      }
    }
  }

  SiteMaterialPoolItem? get _currentPoolItem {
    if (selectedMaterial == null) return null;
    final lowName = selectedMaterial!.toLowerCase().trim();
    for (var item in sitePoolItems) {
      if (item.materialName.toLowerCase().trim() == lowName ||
          item.displayName.toLowerCase().trim() == lowName) {
        return item;
      }
    }
    return null;
  }

  num _getAvailableStock(SiteMaterialPoolItem item) {
    num inCart = 0;
    for (var m in materials) {
      final name = (m['materialName'] ?? m['type'] ?? '').toString().toLowerCase().trim();
      if (name == item.materialName.toLowerCase().trim() ||
          name == item.displayName.toLowerCase().trim()) {
        inCart += (m['quantity'] as num? ?? 0);
      }
    }
    final remaining = item.remainingQty - inCart;
    return remaining < 0 ? 0 : remaining;
  }

  List<String> get _availableMaterialNames {
    if (sitePoolItems.isNotEmpty) {
      final names = <String>[];
      for (var p in sitePoolItems) {
        if (!names.contains(p.materialName)) {
          names.add(p.materialName);
        }
      }
      for (var opt in materialOptions) {
        if (!names.any((n) => n.toLowerCase() == opt.toLowerCase())) {
          names.add(opt);
        }
      }
      return names;
    }
    return materialOptions;
  }

  void _addMaterial() {
    final enteredQty = num.tryParse(materialQtyController.text) ?? 0;
    if (selectedMaterial == null || enteredQty <= 0) return;

    final poolItem = _currentPoolItem;
    if (poolItem != null) {
      final avail = _getAvailableStock(poolItem);
      if (enteredQty > avail) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient material! Only ${_formatQty(avail)} ${poolItem.unit} is currently available at this site.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      final rate = (poolItem.effectiveUnitRate > 0)
          ? poolItem.effectiveUnitRate
          : (materialPrices[poolItem.materialName] ?? materialPrices[selectedMaterial ?? ''] ?? 0).toDouble();
      final totalCost = (enteredQty * rate);
      setState(() {
        materials.add({
          'type': poolItem.materialName,
          'materialName': poolItem.materialName,
          'quantity': enteredQty,
          'unit': poolItem.unit,
          'category': poolItem.category,
          'unitPrice': rate,
          'amount': totalCost,
        });
        materialQty = 0;
        materialQtyController.text = '0';
      });
    } else {
      final price = materialPrices[selectedMaterial!] ?? 0;
      final totalCost = (enteredQty * price);
      setState(() {
        materials.add({
          'type': selectedMaterial!,
          'materialName': selectedMaterial!,
          'quantity': enteredQty,
          'unit': 'Units',
          'category': 'General Material',
          'unitPrice': price,
          'amount': totalCost,
        });
        materialQty = 0;
        materialQtyController.text = '0';
      });
    }
  }

  void _addLabour() {
    final int qty = int.tryParse(labourQtyController.text.trim()) ?? 0;
    if (selectedLabour == null) return;
    final int available = siteMappedLabourCounts[selectedLabour!] ?? 0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid labour count greater than 0.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (qty > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Entered labour count cannot exceed the available workers ($available).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      labours.add({'type': selectedLabour!, 'count': qty});
      labourQty = 0;
      labourQtyController.text = '0';
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

  String _calculateMaterialAmount(String material, num qty) {
    for (var m in materials) {
      if ((m['materialName'] ?? m['type']) == material) {
        final amt = m['amount'];
        if (amt != null && amt is num) {
          return '₹${amt.toStringAsFixed(0)}';
        }
      }
    }
    final price = materialPrices[material] ?? 0;
    return '₹${(price * qty).toStringAsFixed(0)}';
  }

  String _calculateLabourAmount(String labour, int qty) {
    final salary = labourSalaries[labour] ?? 0;
    return '₹${(salary * qty).toStringAsFixed(0)}';
  }

  int _getTotalAmount() {
    num total = 0;
    for (var m in materials) {
      final amt = m['amount'];
      if (amt != null && amt is num) {
        total += amt;
      } else {
        final price = materialPrices[m['type'] ?? ''] ?? 0;
        total += (price * (m['quantity'] ?? 0));
      }
    }
    for (var l in labours) {
      final salary = labourSalaries[l['type'] ?? ''] ?? 0;
      total += (salary * (l['count'] ?? 0));
    }
    total += num.tryParse(foodCost.text) ?? 0;
    total += num.tryParse(transportCost.text) ?? 0;
    total += num.tryParse(fuelCost.text) ?? 0;
    return total.round();
  }

  bool get _hasValidEntryDetails {
    final hasMaterials = materials.isNotEmpty;
    final hasLabours = labours.isNotEmpty;
    final foodVal = num.tryParse(foodCost.text) ?? 0;
    final transportVal = num.tryParse(transportCost.text) ?? 0;
    final fuelVal = num.tryParse(fuelCost.text) ?? 0;
    final hasAdditionalCosts = foodVal > 0 || transportVal > 0 || fuelVal > 0;
    return hasMaterials || hasLabours || hasAdditionalCosts;
  }

  Future<void> _saveToFirestore() async {
    // Prevent duplicate submissions while operation is in progress
    if (isSaving) return;

    if (!_hasValidEntryDetails) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one material, labour, or cost detail before saving.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (siteCode.isEmpty ||
        selectedDate == null ||
        supervisorId == null ||
        supervisorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing site code, date, or supervisor ID!'),
          backgroundColor: Colors.redAccent,
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

    final List<Map<String, dynamic>> newMaterials = materials
        .map(
          (m) => {
            "type": (m['type'] ?? m['materialName'] ?? '').toString(),
            "materialName": (m['materialName'] ?? m['type'] ?? '').toString(),
            "quantity": m['quantity'] ?? 0,
            "unit": (m['unit'] ?? 'Units').toString(),
            "category": (m['category'] ?? '').toString(),
            "unitPrice": m['unitPrice'] ?? materialPrices[m['type'] ?? ''] ?? 0,
            "amount": m['amount'] ??
                ((m['unitPrice'] ?? materialPrices[m['type'] ?? ''] ?? 0) * (m['quantity'] ?? 0)),
          },
        )
        .toList();

    final List<Map<String, dynamic>> newLabours = labours
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

    final int totalAmt = _getTotalAmount();
    final int foodVal = int.tryParse(foodCost.text) ?? 0;
    final int fuelVal = int.tryParse(fuelCost.text) ?? 0;
    final int transportVal = int.tryParse(transportCost.text) ?? 0;
    final int savedMaterialCount = newMaterials.length;
    final int savedLabourCount = newLabours.length;
    final DateTime savedDate = selectedDate!;
    final String savedSiteCode = siteCode;
    final String savedLocation = siteLocation;

    try {
      if (!OfflineSyncService().isOnline) {
        final payload = {
          'docId': docId,
          'date': dateIso,
          'food': foodVal,
          'fuel': fuelVal,
          'labours': newLabours,
          'materials': newMaterials,
          'supervisorId': supervisorId ?? '',
          'supervisorName': widget.userName,
          'projectStage': selectedProjectPhase ?? '',
          'transport': transportVal,
          'totalAmount': totalAmt,
          'siteLocation': siteLocation,
          'siteId': siteCode,
          'projectName': projectName ?? '',
        };

        await OfflineSyncService().enqueueEntry(
          type: 'supervisor_entry',
          data: payload,
          idempotencyKey: '${docId}_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (!mounted) return;

        setState(() {
          materials.clear();
          labours.clear();
          materialQty = 0;
          materialQtyController.text = '0';
          labourQty = 0;
          labourQtyController.text = '0';
          foodCost.text = '0';
          transportCost.text = '0';
          fuelCost.text = '0';
          _showCustomMaterialFields = false;
          _showCustomLabourFields = false;
        });

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Saved Offline'),
              ],
            ),
            content: const Text(
              'Site entry saved locally on your device because there is no internet connection.\n\nIt will automatically sync with the server database when connection is restored.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Fast check for existing entry for this site and date
      final directSnap = await entriesColl.doc(docId).get();
      if (directSnap.exists) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Duplicate Entry'),
              ],
            ),
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
        return;
      }

      final data = <String, dynamic>{
        "date": dateIso,
        "food": foodVal,
        "fuel": fuelVal,
        "labours": newLabours,
        "materials": newMaterials,
        "supervisorId": supervisorId ?? '',
        "supervisorName": widget.userName,
        "projectStage": selectedProjectPhase ?? '',
        "transport": transportVal,
        "totalAmount": totalAmt,
        "siteLocation": siteLocation,
        "siteId": siteCode,
        "projectName": projectName ?? '',
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // 1. Primary write: Save daily site supervisor entry
      await entriesColl.doc(docId).set(data);

      // 2. Prepare actual stage doc update
      final actualColl = FirestoreService.siteSupervisorProjectStageActual;
      final actualDocId =
          '${siteCode}_${widget.userName}_${selectedProjectPhase ?? ''}';
      final List<Map<String, dynamic>> actLabours = labours
          .map(
            (l) => {
              "labourCount": l['count'] ?? 0,
              "labourDesignation": l['type'] ?? '',
            },
          )
          .toList();
      final actualData = <String, dynamic>{
        "actLabours": actLabours,
        "actPayment": totalAmt,
        "projectName": projectName ?? '',
        "projectStage": selectedProjectPhase ?? '',
        "siteId": siteCode,
        "supervisorName": widget.userName,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // Execute secondary backend tasks in parallel for optimal speed
      final List<Future<void>> backgroundTasks = [];

      // Task A: Update stage actuals
      backgroundTasks.add(() async {
        try {
          final actualDoc = await actualColl.doc(actualDocId).get();
          if (actualDoc.exists) {
            final existingActData = actualDoc.data()!;
            final List<dynamic> existingActLabours =
                existingActData['actLabours'] as List? ?? [];
            final List<dynamic> mergedActLabours = [
              ...existingActLabours,
              ...actLabours,
            ];
            final double existingActPayment =
                (existingActData['actPayment'] ?? 0).toDouble();
            final int prevDays = (existingActData['actDays'] ?? 0) as int;

            await actualColl.doc(actualDocId).update({
              ...actualData,
              "actLabours": mergedActLabours,
              "actPayment": existingActPayment + totalAmt,
              "actDays": prevDays + 1,
            });
          } else {
            await actualColl.doc(actualDocId).set({
              ...actualData,
              "actDays": 1,
              "createdAt": FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error updating stage actuals: $e');
        }
      }());

      // Task B: Material consumption in inventory service
      if (materials.isNotEmpty) {
        final consumedItems = materials.map((m) => {
          'materialName': (m['materialName'] ?? m['type']).toString(),
          'quantity': m['quantity'] as num,
          'unit': (m['unit'] ?? 'Units').toString(),
          'category': (m['category'] ?? '').toString(),
          'unitPrice': (m['unitPrice'] ?? materialPrices[m['type']] ?? 0) as num,
          'remarks': 'Daily consumption at $siteCode by ${widget.userName}',
        }).toList();

        backgroundTasks.add(() async {
          try {
            await MaterialInventoryService.recordDailyMaterialConsumption(
              siteId: siteCode,
              siteName: siteLocation,
              date: dateIso,
              supervisorId: supervisorId ?? '',
              supervisorName: widget.userName,
              consumedMaterials: consumedItems,
              remarks: 'Daily consumption at $siteCode by ${widget.userName}',
            );
          } catch (e) {
            debugPrint('Error recording material consumption: $e');
          }
        }());
      }

      // Task C: Update total site expense aggregation
      backgroundTasks.add(() async {
        try {
          await ExpenseService.updateTotalSiteExpense(siteCode);
        } catch (e) {
          debugPrint('Error updating total site expense: $e');
        }
      }());

      // Await all parallel backend operations to complete reliably
      await Future.wait(backgroundTasks);

      // Clear the form data
      if (mounted) {
        setState(() {
          materials.clear();
          labours.clear();
          materialQty = 0;
          materialQtyController.text = '0';
          labourQty = 0;
          labourQtyController.text = '0';
          foodCost.text = '0';
          transportCost.text = '0';
          fuelCost.text = '0';
          _showCustomMaterialFields = false;
          _showCustomLabourFields = false;
        });
      }

      // Refresh site material pool and site labour mapping in background
      await _fetchSiteMaterialPool();
      await _fetchSiteLabourMapping();

      if (!mounted) return;

      // Show clear Success modal/dialog to the supervisor after successful backend save
      await _showSuccessModal(
        siteCode: savedSiteCode,
        location: savedLocation,
        date: savedDate,
        totalAmount: totalAmt,
        materialCount: savedMaterialCount,
        labourCount: savedLabourCount,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _showSuccessModal({
    required String siteCode,
    required String location,
    required DateTime date,
    required int totalAmount,
    required int materialCount,
    required int labourCount,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedDate = DateFormat('dd MMM yyyy').format(date);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Daily Entry Saved!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0A183D),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your daily site report has been saved successfully to the backend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSuccessModalRow(
                        Icons.apartment_rounded,
                        'Site',
                        siteCode,
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildSuccessModalRow(
                        Icons.calendar_today_rounded,
                        'Date',
                        formattedDate,
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildSuccessModalRow(
                        Icons.inventory_2_outlined,
                        'Materials Logged',
                        '$materialCount item(s)',
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildSuccessModalRow(
                        Icons.groups_outlined,
                        'Labours Logged',
                        '$labourCount type(s)',
                        isDark,
                      ),
                      const Divider(height: 18),
                      _buildSuccessModalRow(
                        Icons.payments_outlined,
                        'Total Cost',
                        currencyFormatter.format(totalAmount),
                        isDark,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessModalRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isTotal
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal
                ? const Color(0xFF10B981)
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
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

  Widget _buildStockMetric({
    required String label,
    required String value,
    required bool isDark,
    bool highlight = false,
    bool isWarning = false,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isWarning
                ? const Color(0xFFDC2626)
                : highlight
                    ? (isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: -0.1,
        ),
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
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 14.5,
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 14,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
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
            dataRowMinHeight: 42,
            dataRowMaxHeight: 48,
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
                        width: 70,
                        child: Text(
                          '${m['quantity'] ?? 0} ${m['unit'] ?? ''}'.trim(),
                          style: TextStyle(fontSize: 12, color: bodyTextColor),
                          overflow: TextOverflow.ellipsis,
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
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dropdownBg = isDark ? darkAccent : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Daily Site Entry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 800,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SyncStatusCard(margin: EdgeInsets.only(bottom: 14)),
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
                                  initialValue: supervisorSites.any((s) => s['siteId'] == selectedSiteId)
                                      ? selectedSiteId
                                      : null,
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
                                      : (value) async {
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

                                          if (value != null) {
                                            final details = await ExpenseService.resolveSiteDetails(value);
                                            if (mounted && selectedSiteId == value) {
                                              setState(() {
                                                if (details.supervisor != null && details.supervisor!.isNotEmpty) {
                                                  supervisorName = details.supervisor;
                                                }
                                                if (details.supervisorId != null && details.supervisorId!.isNotEmpty) {
                                                  supervisorId = details.supervisorId;
                                                }
                                                if (details.location != null && details.location!.isNotEmpty) {
                                                  siteLocation = details.location!;
                                                }
                                                if (details.projectName != null && details.projectName!.isNotEmpty) {
                                                  projectName = details.projectName;
                                                }
                                                if (details.projectStage != null && details.projectStage!.isNotEmpty) {
                                                  selectedProjectPhase = details.projectStage;
                                                }
                                              });
                                            }
                                          }

                                          _fetchSiteMaterialPool();
                                          _fetchSiteLabourMapping();
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
                            siteLocation.isNotEmpty ? siteLocation : 'Unknown',
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
                          const SizedBox(height: 14),
                          if (isLoadingMaterials || isLoadingSitePool)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              ),
                            )
                          else if (materialError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                materialError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else ...[
                            // Search Material Input
                            _buildFieldLabel('Search Material'),
                            TextField(
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                ),
                                hintText: 'Search material by name...',
                                hintStyle: TextStyle(
                                  color: labelColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                              ),
                              onChanged: (query) {
                                setState(() {
                                  final q = query.toLowerCase().trim();
                                  final filtered = _availableMaterialNames
                                      .where((item) => item.toLowerCase().contains(q))
                                      .toList();
                                  filtered.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  if (filtered.isNotEmpty) {
                                    selectedMaterial = filtered.contains(selectedMaterial)
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

                            // Select Material Dropdown
                            _buildFieldLabel('Select Material from Site Stock'),
                            DropdownButtonFormField<String>(
                              initialValue: selectedMaterial,
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
                                  size: 20,
                                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                              ),
                              items: (_filteredMaterialOptions ?? _availableMaterialNames)
                                  .map((item) {
                                final pItem = sitePoolItems.cast<SiteMaterialPoolItem?>().firstWhere(
                                  (p) => p != null && p.materialName.toLowerCase().trim() == item.toLowerCase().trim(),
                                  orElse: () => null,
                                );
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (pItem != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: pItem.remainingQty > 0
                                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            pItem.remainingQty > 0
                                                ? '${_formatQty(pItem.remainingQty)} ${pItem.unit}'
                                                : '0 (Empty)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: pItem.remainingQty > 0
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedMaterial = value),
                            ),
                            const SizedBox(height: 12),

                            // Quantity & Live Amount Row
                            Builder(
                              builder: (context) {
                                final poolItem = _currentPoolItem;
                                final price = (poolItem != null && poolItem.effectiveUnitRate > 0)
                                    ? poolItem.effectiveUnitRate
                                    : (materialPrices[selectedMaterial ?? ''] ?? (poolItem != null ? (materialPrices[poolItem.materialName] ?? 0) : 0)).toDouble();
                                final qty = materialQty;
                                final total = price * qty;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Used Quantity'),
                                          TextField(
                                            controller: materialQtyController,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(
                                                Icons.pin_outlined,
                                                size: 20,
                                                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                              ),
                                              suffixText: poolItem?.unit,
                                              suffixStyle: TextStyle(
                                                color: labelColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
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
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 14,
                                              ),
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                materialQty = num.tryParse(value) ?? 0;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Estimated Cost'),
                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: fieldBg,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: borderColor, width: 1.0),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.currency_rupee_rounded,
                                                  size: 18,
                                                  color: total > 0
                                                      ? const Color(0xFF10B981)
                                                      : (isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        poolItem != null ? 'Rate: ₹${price.toStringAsFixed(0)}/${poolItem.unit}' : 'Rate: ₹${price.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          color: labelColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        '₹${total.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: total > 0 ? const Color(0xFF10B981) : textColor,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Live Material Stock Balance Card
                            Builder(
                              builder: (context) {
                                final poolItem = _currentPoolItem;
                                if (poolItem == null) return const SizedBox.shrink();
                                final availStock = _getAvailableStock(poolItem);
                                final enteredQty = num.tryParse(materialQtyController.text) ?? 0;
                                final isOverLimit = enteredQty > availStock;
                                final balanceAfter = availStock - enteredQty;
                                final rate = (poolItem.effectiveUnitRate > 0)
                                    ? poolItem.effectiveUnitRate
                                    : (materialPrices[poolItem.materialName] ?? materialPrices[selectedMaterial ?? ''] ?? 0).toDouble();
                                final consumptionVal = enteredQty * rate;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 14.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isOverLimit
                                          ? const Color(0xFFFEF2F2)
                                          : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isOverLimit
                                            ? const Color(0xFFEF4444)
                                            : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                                        width: isOverLimit ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 16,
                                                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Site Stock Balance',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: availStock > 0
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                availStock > 0 ? '${_formatQty(availStock)} ${poolItem.unit} Available' : 'Out of Stock',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: availStock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildStockMetric(
                                                label: 'Effective Rate',
                                                value: '₹${poolItem.effectiveUnitRate.toStringAsFixed(2)} / ${poolItem.unit}',
                                                isDark: isDark,
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildStockMetric(
                                                label: 'Usage Value',
                                                value: '₹${consumptionVal.toStringAsFixed(2)}',
                                                isDark: isDark,
                                                highlight: true,
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildStockMetric(
                                                label: 'Balance After',
                                                value: '${_formatQty(balanceAfter < 0 ? 0 : balanceAfter)} ${poolItem.unit}',
                                                isDark: isDark,
                                                isWarning: isOverLimit,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isOverLimit) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Insufficient material. Only ${_formatQty(availStock)} ${poolItem.unit} is currently available at this site.',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Material Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Builder(
                                    builder: (context) {
                                      final poolItem = _currentPoolItem;
                                      final availStock = poolItem != null ? _getAvailableStock(poolItem) : double.infinity;
                                      final enteredQty = num.tryParse(materialQtyController.text) ?? 0;
                                      final isOverLimit = poolItem != null && enteredQty > availStock;
                                      final isOutOfStock = poolItem != null && availStock <= 0;
                                      final isDisabled = isLoadingMaterials ||
                                          isLoadingSitePool ||
                                          _availableMaterialNames.isEmpty ||
                                          enteredQty <= 0 ||
                                          isOverLimit ||
                                          isOutOfStock;

                                      return GlassButton(
                                        label: 'Add Material Usage',
                                        icon: Icons.add_circle_outline_rounded,
                                        onPressed: isDisabled ? null : _addMaterial,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: GlassButton(
                                    label: _showCustomMaterialFields ? 'Hide Others' : 'Others',
                                    icon: _showCustomMaterialFields ? Icons.close_rounded : Icons.more_horiz_rounded,
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

                            // Custom Material Section
                            if (_showCustomMaterialFields) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor, width: 1.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildFieldLabel('Custom Material Name'),
                                    TextField(
                                      controller: _customMaterialNameController,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.edit_note_rounded,
                                          size: 20,
                                          color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                        ),
                                        hintText: 'Enter material name...',
                                        hintStyle: TextStyle(
                                          color: labelColor.withValues(alpha: 0.8),
                                          fontSize: 13.5,
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
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Quantity'),
                                              TextField(
                                                controller: _customMaterialQtyController,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.pin_outlined,
                                                    size: 20,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 14,
                                                  ),
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Unit Price (₹)'),
                                              TextField(
                                                controller: _customMaterialPriceController,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.currency_rupee_rounded,
                                                    size: 20,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 14,
                                                  ),
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
                                      icon: Icons.playlist_add_rounded,
                                      onPressed: _addCustomMaterial,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                          const SizedBox(height: 14),
                          if (isLoadingLabours)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              ),
                            )
                          else if (labourError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                labourError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (labourOptions.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.engineering_outlined,
                                    color: Color(0xFFF59E0B),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'No Workers Mapped To Site',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'No workers are currently configured for this site by the Manager.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: labelColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // Search Labour Input
                            _buildFieldLabel('Search Labour'),
                            TextField(
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                ),
                                hintText: 'Search labour designation...',
                                hintStyle: TextStyle(
                                  color: labelColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                              ),
                              onChanged: (query) {
                                setState(() {
                                  final q = query.toLowerCase().trim();
                                  final filtered = labourOptions
                                      .where((item) => item.toLowerCase().contains(q))
                                      .toList();
                                  filtered.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  if (filtered.isNotEmpty) {
                                    selectedLabour = filtered.contains(selectedLabour)
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

                            // Select Labour Dropdown
                            _buildFieldLabel('Select Labour / Designation'),
                            DropdownButtonFormField<String>(
                              initialValue: selectedLabour,
                              isExpanded: true,
                              dropdownColor: dropdownBg,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.engineering_outlined,
                                  size: 20,
                                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                              ),
                              items: (_filteredLabourOptions ?? labourOptions)
                                  .map(
                                    (item) {
                                      final count = siteMappedLabourCounts[item] ?? 0;
                                      return DropdownMenuItem(
                                        value: item,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: count > 0
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '$count Available',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: count > 0
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() => selectedLabour = value),
                            ),
                            const SizedBox(height: 12),

                            // Mapped Worker Availability Info Banner
                            if (selectedLabour != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.groups_rounded,
                                          size: 18,
                                          color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Available $selectedLabour:',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (siteMappedLabourCounts[selectedLabour] ?? 0) > 0
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${siteMappedLabourCounts[selectedLabour] ?? 0} ${(siteMappedLabourCounts[selectedLabour] == 1) ? "Worker" : "Workers"} Available',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: (siteMappedLabourCounts[selectedLabour] ?? 0) > 0
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Labour Count & Wage Row
                            Builder(
                              builder: (context) {
                                final salary = labourSalaries[selectedLabour ?? ''] ?? 0;
                                final count = labourQty;
                                final total = salary * count;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Labour Count'),
                                          TextField(
                                            controller: labourQtyController,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(
                                                Icons.people_outline_rounded,
                                                size: 20,
                                                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                              ),
                                              suffixText: 'Persons',
                                              suffixStyle: TextStyle(
                                                color: labelColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
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
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 14,
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                labourQty = int.tryParse(value) ?? 0;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Estimated Wage'),
                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: fieldBg,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: borderColor, width: 1.0),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.currency_rupee_rounded,
                                                  size: 18,
                                                  color: total > 0
                                                      ? const Color(0xFF10B981)
                                                      : (isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Rate: ₹${salary.toStringAsFixed(0)}/day',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          color: labelColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        '₹${total.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: total > 0 ? const Color(0xFF10B981) : textColor,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Dynamic Labour Limit Warning
                            Builder(
                              builder: (context) {
                                final available = selectedLabour != null ? (siteMappedLabourCounts[selectedLabour!] ?? 0) : 0;
                                final enteredCount = int.tryParse(labourQtyController.text.trim()) ?? 0;
                                final isExceeding = available > 0 && enteredCount > available;

                                if (!isExceeding) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Entered labour count cannot exceed the available workers ($available).',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Labour Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Builder(
                                    builder: (context) {
                                      final available = selectedLabour != null ? (siteMappedLabourCounts[selectedLabour!] ?? 0) : 0;
                                      final enteredCount = int.tryParse(labourQtyController.text.trim()) ?? 0;
                                      final isExceeding = available > 0 && enteredCount > available;
                                      final isZeroOrLess = enteredCount <= 0;
                                      final isOutOfWorkers = available <= 0;
                                      final isDisabled = isLoadingLabours ||
                                          labourOptions.isEmpty ||
                                          selectedLabour == null ||
                                          isZeroOrLess ||
                                          isExceeding ||
                                          isOutOfWorkers;

                                      return GlassButton(
                                        label: 'Add Labour',
                                        icon: Icons.person_add_rounded,
                                        onPressed: isDisabled ? null : _addLabour,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: GlassButton(
                                    label: _showCustomLabourFields ? 'Hide Others' : 'Others',
                                    icon: _showCustomLabourFields ? Icons.close_rounded : Icons.more_horiz_rounded,
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

                            // Custom Labour Section
                            if (_showCustomLabourFields) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor, width: 1.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildFieldLabel('Custom Labour Designation'),
                                    TextField(
                                      controller: _customLabourNameController,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.edit_note_rounded,
                                          size: 20,
                                          color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                                        ),
                                        hintText: 'e.g. Electrician, Painter...',
                                        hintStyle: TextStyle(
                                          color: labelColor.withValues(alpha: 0.8),
                                          fontSize: 13.5,
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
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Count'),
                                              TextField(
                                                controller: _customLabourCountController,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.people_outline_rounded,
                                                    size: 20,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 14,
                                                  ),
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Daily Salary (₹)'),
                                              TextField(
                                                controller: _customLabourSalaryController,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  prefixIcon: Icon(
                                                    Icons.currency_rupee_rounded,
                                                    size: 20,
                                                    color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
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
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 14,
                                                  ),
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    GlassButton(
                                      label: 'Add Custom Labour',
                                      icon: Icons.playlist_add_rounded,
                                      onPressed: _addCustomLabour,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                            icon: Icons.restart_alt,
                            onPressed: isSaving
                                ? null
                                : () {
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
                                      _showCustomMaterialFields = false;
                                      _customMaterialNameController.clear();
                                      _customMaterialQtyController.text = '0';
                                      _customMaterialPriceController.text = '0';
                                      _showCustomLabourFields = false;
                                      _customLabourNameController.clear();
                                      _customLabourSalaryController.text = '0';
                                      _customLabourCountController.text = '0';
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
                            onPressed: (_hasValidEntryDetails && !isSaving)
                                ? _saveToFirestore
                                : null,
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
