import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/notification_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class WorkerMappingPage extends StatefulWidget {
  final String? initialSiteId;
  const WorkerMappingPage({super.key, this.initialSiteId});

  @override
  State<WorkerMappingPage> createState() => _WorkerMappingPageState();
}

class _WorkerMappingPageState extends State<WorkerMappingPage> {
  // Selected values
  String? _selectedSite;
  String? _selectedSupervisor;
  String? _selectedProjectName;

  // Selected worker for current selection
  String? _selectedWorkerId;
  String? _selectedWorkerName;
  String? _selectedWorkerDesignation;
  String? _selectedWorkerSalary;
  String? _selectedWorkerPhone;

  // List of selected workers for the site
  List<Map<String, dynamic>> _selectedWorkersList = [];

  // Lists for dropdowns
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _workers = [];

  // Worker availability tracking (workerId/workerName -> {siteId, siteName, supervisor})
  Map<String, Map<String, String>> _workerAssignedSites = {};

  // Subscriptions for real-time sync
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _allMappingsSubscription;
  StreamSubscription<dynamic>? _currentSiteMappingSubscription;

  // Loading states
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;
  bool _isSubmitting = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _initAllMappingsListener();
    _loadSites();
    _loadWorkers();
  }

  @override
  void dispose() {
    _allMappingsSubscription?.cancel();
    _currentSiteMappingSubscription?.cancel();
    super.dispose();
  }

  /// Real-time stream of all worker mappings to know worker availability across all sites
  void _initAllMappingsListener() {
    _allMappingsSubscription = FirestoreService.getCollection('workerSiteMapping')
        .snapshots()
        .listen((snapshot) {
      final Map<String, Map<String, String>> newAssigned = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sId = doc.id;
        final sName = (data['siteName'] ?? data['site'] ?? sId).toString();
        final sSup = (data['supervisor'] ?? '').toString();
        final workersList = data['workers'] as List<dynamic>? ?? [];

        for (final w in workersList) {
          if (w is Map) {
            final wId = (w['workerId'] ?? w['id'] ?? '').toString().trim().toLowerCase();
            final wName = (w['workerName'] ?? w['name'] ?? '').toString().trim().toLowerCase();
            final info = {
              'siteId': sId,
              'siteName': sName,
              'supervisor': sSup,
            };
            if (wId.isNotEmpty) newAssigned[wId] = info;
            if (wName.isNotEmpty) newAssigned[wName] = info;
          }
        }
      }

      if (mounted) {
        setState(() {
          _workerAssignedSites = newAssigned;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to all workerSiteMapping: $e');
    });
  }

  Map<String, String>? _getAssignedInfoForWorker(String? id, String? name) {
    final cleanId = (id ?? '').trim().toLowerCase();
    final cleanName = (name ?? '').trim().toLowerCase();
    if (cleanId.isNotEmpty && _workerAssignedSites.containsKey(cleanId)) {
      return _workerAssignedSites[cleanId];
    }
    if (cleanName.isNotEmpty && _workerAssignedSites.containsKey(cleanName)) {
      return _workerAssignedSites[cleanName];
    }
    return null;
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);

    try {
      // 1. Try 'projects' collection first (single source of truth)
      List<Map<String, dynamic>> loadedSites = [];
      try {
        final projectSnap = await FirestoreService.getCollection('projects').get();
        for (final doc in projectSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['id'] ?? doc.id).toString().trim();
          final sName = (data['siteName'] ?? data['projectName'] ?? doc.id).toString().trim();
          final supervisor = (data['assignedSupervisor'] ?? data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim();
          if (sId.isNotEmpty || sName.isNotEmpty) {
            loadedSites.add({
              'id': sId.isNotEmpty ? sId : sName,
              'site': sId.isNotEmpty ? sId : sName,
              'siteId': sId,
              'siteName': sName.isNotEmpty ? sName : sId,
              'supervisor': supervisor,
              'projectName': sName,
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading from projects: $e');
      }

      // 2. Fallback to 'Site' collection if projects was empty
      if (loadedSites.isEmpty) {
        final siteSnapshot = await FirestoreService.getCollection('Site').get();
        for (final doc in siteSnapshot.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? doc.id).toString().trim();
          final sName = (data['siteName'] ?? doc.id).toString().trim();
          loadedSites.add({
            'id': doc.id,
            'site': doc.id,
            'siteId': sId.isNotEmpty ? sId : doc.id,
            'siteName': sName,
            'supervisor': (data['assignedSupervisor'] ?? data['supervisor'] ?? '').toString(),
            'projectName': sName,
          });
        }
      }

      // Deduplicate by site ID / name
      final Map<String, Map<String, dynamic>> dedup = {};
      for (final s in loadedSites) {
        final key = (s['site'] ?? s['id']).toString();
        dedup[key] = s;
      }

      final finalList = dedup.values.toList();
      finalList.sort((a, b) => (a['siteName'] ?? '').toString().toLowerCase().compareTo((b['siteName'] ?? '').toString().toLowerCase()));

      if (!mounted) return;
      setState(() {
        _sites = finalList;
        _isLoadingSites = false;
      });

      // Handle initial site selection if provided
      if (widget.initialSiteId != null && _selectedSite == null) {
        final matched = _sites.firstWhere(
          (s) => s['id'] == widget.initialSiteId || s['site'] == widget.initialSiteId || s['siteId'] == widget.initialSiteId,
          orElse: () => {},
        );
        if (matched.isNotEmpty) {
          _onSiteSelected(matched['site'] as String?);
        } else if (_sites.isNotEmpty) {
          _onSiteSelected(_sites.first['site'] as String?);
        }
      }
    } catch (e) {
      debugPrint('Error loading sites: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sites: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);

    try {
      final querySnapshot = await FirestoreService.getCollection('workersConfig').get();

      final Map<String, Map<String, dynamic>> workersMap = {};
      final Set<String> seenIdentifiers = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final id = (data['workerId'] ?? data['id'] ?? doc.id).toString().trim();
        final name = (data['name'] ?? data['workerName'] ?? data['fullName'] ?? '').toString().trim();
        final designation = (data['designation'] ?? data['workerDesignation'] ?? data['role'] ?? '').toString().trim();
        final salary = (data['salary'] ?? data['workerSalary'] ?? data['wage'] ?? '0').toString().trim();
        final phone = (data['phoneNumber'] ?? data['phone'] ?? data['workerPhone'] ?? data['mobile'] ?? '').toString().trim();

        if (name.isEmpty && id.isEmpty) continue;

        final cleanName = name.isNotEmpty ? name : id;
        final dedupKey = '${cleanName.toLowerCase()}_${designation.toLowerCase()}';

        if (id.isNotEmpty && !workersMap.containsKey(id) && !seenIdentifiers.contains(dedupKey)) {
          seenIdentifiers.add(dedupKey);
          workersMap[id] = {
            'id': id,
            'name': cleanName,
            'designation': designation.isNotEmpty ? designation : 'General Worker',
            'salary': salary,
            'phoneNumber': phone,
          };
        }
      }

      final list = workersMap.values.toList();
      list.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      if (!mounted) return;
      setState(() {
        _workers = list;
        _isLoadingWorkers = false;
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workers: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _onSiteSelected(String? site) {
    setState(() {
      _selectedSite = site;
      _selectedSupervisor = null;
      _selectedProjectName = null;
      _selectedWorkersList.clear();
      _selectedWorkerId = null;
      _selectedWorkerName = null;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });

    if (site != null) {
      _loadSiteDetails(site);
      _listenToSiteWorkerMapping(site);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      // 1. Check local _sites list first
      final matched = _sites.firstWhere(
        (s) => s['site'] == siteId || s['id'] == siteId || s['siteId'] == siteId,
        orElse: () => {},
      );

      if (matched.isNotEmpty && (matched['supervisor']?.toString().isNotEmpty ?? false)) {
        if (mounted) {
          setState(() {
            _selectedSupervisor = matched['supervisor'] ?? 'Not available';
            _selectedProjectName = matched['siteName'] ?? matched['projectName'] ?? siteId;
          });
        }
        return;
      }

      // 2. Query siteSupervisorMap
      final mapSnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('site', isEqualTo: siteId).limit(1).get();

      if (!mounted) return;

      if (mapSnapshot.docs.isNotEmpty) {
        final data = mapSnapshot.docs.first.data();
        setState(() {
          _selectedSupervisor = data['supervisor'] ?? 'Not available';
          _selectedProjectName = data['projectName'] ?? matched['siteName'] ?? siteId;
        });
      } else {
        final projDoc = await FirestoreService.getCollection('projects').doc(siteId).get();
        if (projDoc.exists && mounted) {
          final data = projDoc.data()!;
          setState(() {
            _selectedSupervisor = data['assignedSupervisor'] ?? data['supervisor'] ?? 'Not available';
            _selectedProjectName = data['siteName'] ?? data['projectName'] ?? siteId;
          });
        } else {
          final siteDoc = await FirestoreService.getCollection('Site').doc(siteId).get();
          if (!mounted) return;
          setState(() {
            _selectedSupervisor = siteDoc.exists ? (siteDoc.data()?['assignedSupervisor'] ?? 'Not available') : 'Not available';
            _selectedProjectName = siteDoc.exists ? (siteDoc.data()?['siteName'] ?? siteId) : siteId;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching site details: $e');
    }
  }

  void _listenToSiteWorkerMapping(String siteId) {
    _currentSiteMappingSubscription?.cancel();

    final cleanSiteId = siteId.trim().toLowerCase();
    final cleanSiteName = (_selectedProjectName ?? '').trim().toLowerCase();
    final combinedKey = '${cleanSiteId}_$cleanSiteName'.trim().toLowerCase();

    final Set<String> candidateKeys = {
      cleanSiteId,
      if (cleanSiteName.isNotEmpty) cleanSiteName,
      if (cleanSiteId.isNotEmpty && cleanSiteName.isNotEmpty) combinedKey,
    };

    bool matchesSite(String? val) {
      if (val == null) return false;
      final clean = val.trim().toLowerCase();
      if (clean.isEmpty) return false;
      if (candidateKeys.contains(clean)) return true;
      for (final key in candidateKeys) {
        if (clean == key || clean.contains(key) || key.contains(clean)) return true;
      }
      return false;
    }

    _currentSiteMappingSubscription = FirestoreService.getCollection('workerSiteMapping')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final Map<String, Map<String, dynamic>> dedup = {};

      for (final doc in snapshot.docs) {
        final docId = doc.id.trim().toLowerCase();
        final data = doc.data();
        final dSiteId = (data['siteId'] ?? '').toString();
        final dSite = (data['site'] ?? '').toString();
        final dSiteName = (data['siteName'] ?? '').toString();
        final dProjectName = (data['projectName'] ?? '').toString();

        final isMatch = candidateKeys.contains(docId) ||
            matchesSite(docId) ||
            matchesSite(dSiteId) ||
            matchesSite(dSite) ||
            matchesSite(dSiteName) ||
            matchesSite(dProjectName);

        if (isMatch) {
          final workersList = (data['workers'] ?? data['mappedWorkers']) as List<dynamic>? ?? [];
          for (final w in workersList) {
            if (w is Map) {
              final workerMap = Map<String, dynamic>.from(w);
              final name = (workerMap['workerName'] ?? workerMap['name'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                final key = name.toLowerCase();
                dedup[key] = {
                  'workerId': (workerMap['workerId'] ?? workerMap['id'] ?? '').toString(),
                  'workerName': name,
                  'workerDesignation': (workerMap['workerDesignation'] ?? workerMap['designation'] ?? 'Worker').toString(),
                  'workerSalary': (workerMap['workerSalary'] ?? workerMap['salary'] ?? '0').toString(),
                  'workerPhone': (workerMap['workerPhone'] ?? workerMap['phoneNumber'] ?? workerMap['phone'] ?? '').toString(),
                  'siteId': (workerMap['siteId'] ?? siteId).toString(),
                  'assignmentStatus': (workerMap['assignmentStatus'] ?? 'Active').toString(),
                  'mappingDate': (workerMap['mappingDate'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now())).toString(),
                };
              }
            }
          }
        }
      }

      setState(() {
        _selectedWorkersList = dedup.values.toList();
      });
    }, onError: (e) {
      debugPrint('Error listening to workerSiteMapping for $siteId: $e');
    });
  }

  void _onWorkerSelected(String? workerId) {
    if (workerId == null) {
      setState(() {
        _selectedWorkerId = null;
        _selectedWorkerName = null;
        _selectedWorkerDesignation = null;
        _selectedWorkerSalary = null;
        _selectedWorkerPhone = null;
      });
      return;
    }

    final worker = _workers.firstWhere(
      (w) => w['id'] == workerId,
      orElse: () => {},
    );

    if (worker.isNotEmpty) {
      setState(() {
        _selectedWorkerId = workerId;
        _selectedWorkerName = (worker['name'] ?? '').toString();
        _selectedWorkerDesignation = (worker['designation'] ?? '').toString();
        _selectedWorkerSalary = (worker['salary'] ?? '').toString();
        _selectedWorkerPhone = (worker['phoneNumber'] ?? '').toString();
      });
    }
  }

  void _addWorkerToList() {
    if (_selectedWorkerId == null || _selectedWorkerName == null || _selectedWorkerName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a worker profile'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isAlreadyAdded = _selectedWorkersList.any(
      (w) => (w['workerId'] != null && w['workerId'].toString().isNotEmpty && w['workerId'] == _selectedWorkerId) ||
             (w['workerName'] != null && w['workerName'].toString().isNotEmpty && w['workerName'] == _selectedWorkerName),
    );

    if (isAlreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Worker "$_selectedWorkerName" is already mapped to this site'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final assignedInfo = _getAssignedInfoForWorker(_selectedWorkerId, _selectedWorkerName);
    final isAssignedElsewhere = assignedInfo != null &&
        assignedInfo['siteId'] != null &&
        assignedInfo['siteId'] != _selectedSite;

    if (isAssignedElsewhere) {
      final prevSiteName = assignedInfo['siteName'] ?? assignedInfo['siteId'] ?? 'another site';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reassigning "$_selectedWorkerName" from $prevSiteName to $_selectedSite.'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _selectedWorkersList.add({
        'workerId': _selectedWorkerId,
        'workerName': _selectedWorkerName,
        'workerDesignation': _selectedWorkerDesignation ?? 'General Worker',
        'workerSalary': _selectedWorkerSalary ?? '0',
        'workerPhone': _selectedWorkerPhone ?? '',
        'siteId': _selectedSite ?? '',
        'siteName': _selectedProjectName ?? _selectedSite ?? '',
        'assignmentStatus': 'Active',
        'mappingDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      });

      _selectedWorkerId = null;
      _selectedWorkerName = null;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });
  }

  void _removeWorkerFromList(int index) {
    setState(() {
      _selectedWorkersList.removeAt(index);
    });
  }

  bool get _isFormComplete {
    return _selectedSite != null &&
        _selectedSite!.isNotEmpty &&
        _selectedWorkersList.isNotEmpty;
  }

  Future<void> _submitMapping() async {
    if (!_isFormComplete) return;

    setState(() => _isSubmitting = true);

    try {
      final String siteId = _selectedSite!;
      final String siteName = _selectedProjectName ?? siteId;
      final String supervisor = _selectedSupervisor ?? 'Not available';

      final cleanSiteId = siteId.trim();
      final cleanSiteName = siteName.trim();
      final combinedKey = '${cleanSiteId}_$cleanSiteName';

      final docData = {
        'site': cleanSiteId,
        'siteId': cleanSiteId,
        'siteName': cleanSiteName,
        'supervisor': supervisor,
        'projectName': cleanSiteName,
        'totalWorkersMapped': _selectedWorkersList.length,
        'workers': _selectedWorkersList,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Check if this site already had allocated workers (to distinguish new vs updated allocation)
      bool isUpdate = false;
      try {
        final existingDoc = await FirestoreService.getCollection('workerSiteMapping')
            .doc(cleanSiteId)
            .get();
        if (existingDoc.exists) {
          final existingCount =
              (existingDoc.data()?['totalWorkersMapped'] as num?)?.toInt() ?? 0;
          if (existingCount > 0) {
            isUpdate = true;
          }
        }
      } catch (_) {}

      // 1. Commit mapping to both workerSiteMapping and legacy workerSiteMap across all canonical keys
      final batch = FirebaseFirestore.instance.batch();

      final Set<String> targetDocKeys = {
        cleanSiteId,
        if (cleanSiteName.isNotEmpty) cleanSiteName,
        if (cleanSiteId.isNotEmpty && cleanSiteName.isNotEmpty) combinedKey,
      };

      for (final key in targetDocKeys) {
        final ref1 = FirestoreService.getCollection('workerSiteMapping').doc(key);
        final ref2 = FirestoreService.getCollection('workerSiteMap').doc(key);
        batch.set(ref1, docData, SetOptions(merge: true));
        batch.set(ref2, docData, SetOptions(merge: true));
      }

      // 2. If workers were transferred from other sites, clean them up from previous site mapping
      final Set<String> addedWorkerIds = _selectedWorkersList
          .map((w) => (w['workerId'] ?? '').toString().toLowerCase())
          .where((id) => id.isNotEmpty)
          .toSet();
      final Set<String> addedWorkerNames = _selectedWorkersList
          .map((w) => (w['workerName'] ?? '').toString().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();

      final otherSiteSnapshots = await FirestoreService.getCollection('workerSiteMapping').get();
      for (final otherDoc in otherSiteSnapshots.docs) {
        if (targetDocKeys.contains(otherDoc.id.trim())) continue;
        final data = otherDoc.data();
        final rawList = data['workers'] as List<dynamic>? ?? [];
        bool modified = false;

        final updatedList = rawList.where((w) {
          if (w is! Map) return true;
          final wid = (w['workerId'] ?? w['id'] ?? '').toString().toLowerCase();
          final wname = (w['workerName'] ?? w['name'] ?? '').toString().toLowerCase();
          if ((wid.isNotEmpty && addedWorkerIds.contains(wid)) ||
              (wname.isNotEmpty && addedWorkerNames.contains(wname))) {
            modified = true;
            return false; // Remove transferred worker
          }
          return true;
        }).toList();

        if (modified) {
          batch.update(otherDoc.reference, {
            'workers': updatedList,
            'totalWorkersMapped': updatedList.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      try {
        final workerNames = _selectedWorkersList
            .map((w) => (w['workerName'] ?? w['name'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toList();
        final cleanSupervisor = (supervisor.isNotEmpty &&
                supervisor.toLowerCase() != 'not available' &&
                supervisor.toLowerCase() != 'unassigned')
            ? supervisor
            : null;
        await NotificationService.notifyWorkerAssignment(
          siteId: cleanSiteId,
          siteName: cleanSiteName.isNotEmpty ? cleanSiteName : cleanSiteId,
          workerCount: _selectedWorkersList.length,
          workerNames: workerNames,
          supervisorName: cleanSupervisor,
          projectName: cleanSiteName,
          isUpdate: isUpdate,
        );
      } catch (notifErr) {
        debugPrint('Error sending worker assignment notification: $notifErr');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully mapped ${_selectedWorkersList.length} workers to site $siteName ($siteId)!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving worker mapping: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Worker Site Mapping',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 650,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    title: 'Select Site & Project',
                    icon: Icons.location_city_rounded,
                    primaryColor: primaryColor,
                    children: [
                      _buildSiteDropdown(primaryColor),
                      if (_selectedSupervisor != null || _selectedProjectName != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailTile(
                                Icons.person_rounded,
                                'Supervisor',
                                _selectedSupervisor ?? 'Not available',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDetailTile(
                                Icons.business_center_rounded,
                                'Project Name',
                                _selectedProjectName ?? 'Not available',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  _buildSectionCard(
                    title: 'Select Worker to Add',
                    icon: Icons.person_add_alt_1_rounded,
                    primaryColor: primaryColor,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildWorkerDropdown(primaryColor),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _addWorkerToList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'ADD',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedWorkerDesignation != null || _selectedWorkerSalary != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailTile(
                                Icons.construction_rounded,
                                'Role',
                                _selectedWorkerDesignation ?? 'N/A',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDetailTile(
                                Icons.payments_rounded,
                                'Daily Wage',
                                '₹${_selectedWorkerSalary ?? '0'}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  if (_selectedWorkersList.isNotEmpty)
                    _buildSelectedWorkersCard(primaryColor),

                  const SizedBox(height: 16),

                  _buildSubmitButton(primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
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

  Widget _buildSiteDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Select Site *'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedSite,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: 'Choose site location',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.location_on_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          items: _isLoadingSites
              ? [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Loading sites...'),
                  ),
                ]
              : _sites.map<DropdownMenuItem<String>>((site) {
                  final displayName = SiteDisplayHelper.formatSiteDisplay(
                    siteId: site['siteId'] ?? site['site'],
                    siteName: site['siteName'] ?? site['projectName'],
                  );
                  return DropdownMenuItem<String>(
                    value: site['site'] as String?,
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
          onChanged: _onSiteSelected,
        ),
      ],
    );
  }

  Widget _buildWorkerDropdown(Color primaryColor) {
    final availableWorkers = _workers.where((worker) {
      final wId = worker['id']?.toString().trim().toLowerCase() ?? '';
      final wName = worker['name']?.toString().trim().toLowerCase() ?? '';

      return !_selectedWorkersList.any((selectedWorker) {
        final sId = selectedWorker['workerId']?.toString().trim().toLowerCase() ?? '';
        final sName = selectedWorker['workerName']?.toString().trim().toLowerCase() ?? '';

        if (wId.isNotEmpty && sId.isNotEmpty && wId == sId) return true;
        if (wName.isNotEmpty && sName.isNotEmpty && wName == sName) return true;
        return false;
      });
    }).toList();

    final bool isSelectedValid = availableWorkers.any((w) => w['id'] == _selectedWorkerId);
    final String? currentDropdownValue = isSelectedValid ? _selectedWorkerId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Select Worker Profile *'),
        DropdownButtonFormField<String>(
          key: ValueKey('worker_dd_${currentDropdownValue}_${availableWorkers.length}'),
          isExpanded: true,
          initialValue: currentDropdownValue,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: _isLoadingWorkers
                ? 'Loading workers...'
                : (availableWorkers.isEmpty
                    ? (_workers.isEmpty
                        ? 'No workers registered in system'
                        : 'All workers already added')
                    : 'Choose registered worker'),
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.badge_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          items: _isLoadingWorkers
              ? [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Loading workers...'),
                  ),
                ]
              : availableWorkers.map<DropdownMenuItem<String>>((worker) {
                  final String id = worker['id']?.toString() ?? '';
                  final String name = worker['name']?.toString().trim() ?? '';
                  final String des = worker['designation']?.toString().trim() ?? '';
                  final String displayName = des.isNotEmpty ? '$name ($des)' : name;

                  final assignedInfo = _getAssignedInfoForWorker(id, name);
                  final isAssignedElsewhere = assignedInfo != null &&
                      assignedInfo['siteId'] != null &&
                      assignedInfo['siteId'] != _selectedSite;

                  final assignedSiteLabel = assignedInfo?['siteName'] ?? assignedInfo?['siteId'] ?? '';

                  return DropdownMenuItem<String>(
                    value: worker['id'] as String?,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAssignedElsewhere ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isAssignedElsewhere ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Text(
                            isAssignedElsewhere ? 'Mapped: $assignedSiteLabel' : 'Available',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAssignedElsewhere ? const Color(0xFFD97706) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          onChanged: availableWorkers.isEmpty ? null : _onWorkerSelected,
        ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWorkersCard(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mapped Workers (${_selectedWorkersList.length})',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedWorkersList.clear();
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedWorkersList.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0xFFE2E8F0), height: 12),
            itemBuilder: (context, index) {
              final worker = _selectedWorkersList[index];
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker['workerName'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        Row(
                          children: [
                            if (worker['workerDesignation'] != null) ...[
                              Text(
                                worker['workerDesignation'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            ],
                            Text(
                              '₹${worker['workerSalary'] ?? '0'}/day',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    onPressed: () => _removeWorkerFromList(index),
                    tooltip: 'Remove',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return Column(
      children: [
        if (!_isFormComplete && _selectedSite != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    _selectedWorkersList.isEmpty
                        ? 'Add at least one worker to save site mapping'
                        : 'Waiting for site details...',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _isSubmitting
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isFormComplete ? _submitMapping : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'SAVE WORKER SITE MAPPING',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
