import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class AttendanceManagementPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const AttendanceManagementPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
  // Selected values
  String? _selectedSiteId;
  String? _selectedSiteName;
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _workers = [];

  // Extra / Unknown count-based workers
  List<Map<String, dynamic>> _extraWorkers = [];
  String _selectedExtraWorkerType = 'Mason';
  int _currentExtraCount = 1;
  final TextEditingController _customTypeController = TextEditingController();
  bool _isCustomType = false;

  // Dynamic worker categories fetched from 'labours' collection
  List<String> _workerCategories = [];
  bool _isLoadingLabours = false;

  // Loading states
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;
  bool _isSubmitting = false;

  // Attendance state
  final Map<String, String> _attendanceStatus = {};
  final String _currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Real-time stream subscriptions
  StreamSubscription<dynamic>? _siteMappingSub;
  StreamSubscription<dynamic>? _todayAttendanceSub;
  StreamSubscription<dynamic>? _laboursSub;

  @override
  void initState() {
    super.initState();
    _initLaboursListener();
    _fetchAssignedSitesAndLoad();
  }

  @override
  void dispose() {
    _laboursSub?.cancel();
    _siteMappingSub?.cancel();
    _todayAttendanceSub?.cancel();
    _customTypeController.dispose();
    super.dispose();
  }

  /// Real-time listener for worker designations from 'labours' collection
  void _initLaboursListener() {
    setState(() => _isLoadingLabours = true);
    _laboursSub?.cancel();
    _laboursSub = FirestoreService.getCollection('labours')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final Set<String> seen = {};
      final List<String> fetchedDesignations = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final des = (data['designation'] ?? data['name'] ?? data['trade'] ?? data['type'] ?? data['role'] ?? doc.id).toString().trim();
        if (des.isNotEmpty) {
          final lower = des.toLowerCase();
          if (!seen.contains(lower) && lower != 'other / custom' && lower != 'other') {
            seen.add(lower);
            fetchedDesignations.add(des);
          }
        }
      }

      // Sort alphabetically
      fetchedDesignations.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // Fallback defaults if labours collection is empty
      if (fetchedDesignations.isEmpty) {
        fetchedDesignations.addAll([
          'Mason',
          'Helper',
          'Carpenter',
          'Painter',
          'Electrician',
          'Plumber',
          'Barbender',
          'Welder',
          'Tile Mason',
          'General Labour',
        ]);
      }

      // Append Other / Custom option for custom trade inputs
      fetchedDesignations.add('Other / Custom');

      setState(() {
        _workerCategories = fetchedDesignations;
        _isLoadingLabours = false;

        if (_selectedExtraWorkerType.isEmpty || !_workerCategories.contains(_selectedExtraWorkerType)) {
          _selectedExtraWorkerType = _workerCategories.firstWhere(
            (c) => c != 'Other / Custom',
            orElse: () => _workerCategories.first,
          );
        }
      });
    }, onError: (e) {
      debugPrint('Error listening to labours collection: $e');
      if (mounted) {
        setState(() {
          _isLoadingLabours = false;
          if (_workerCategories.isEmpty) {
            _workerCategories = [
              'Mason',
              'Helper',
              'Carpenter',
              'Painter',
              'Electrician',
              'Plumber',
              'Barbender',
              'Welder',
              'Tile Mason',
              'General Labour',
              'Other / Custom',
            ];
            _selectedExtraWorkerType = 'Mason';
          }
        });
      }
    });
  }

  Future<void> _fetchAssignedSitesAndLoad() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSites = true;
      _sites = [];
    });

    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final cleanSupId = widget.supervisorId.trim().toLowerCase();
      final cleanSupName = widget.supervisorName.trim().toLowerCase();

      final Map<String, Map<String, dynamic>> uniqueSitesBySiteId = {};

      void addOrMergeSite({
        required String rawSiteId,
        required String rawSiteName,
        String? rawDocId,
        String? projectName,
        String? supervisor,
      }) {
        String sId = rawSiteId.trim();
        String sName = rawSiteName.trim();
        if (sId.isEmpty && rawDocId != null) sId = rawDocId;
        if (sName.isEmpty) sName = sId;

        final key = sId.toLowerCase();
        if (!uniqueSitesBySiteId.containsKey(key)) {
          uniqueSitesBySiteId[key] = {
            'siteId': sId,
            'siteName': sName,
            'projectName': projectName ?? sName,
            'supervisor': supervisor ?? widget.supervisorName,
          };
        }
      }

      // 1. Fetch from 'projects' collection (single source of truth)
      try {
        final projSnap = await FirestoreService.getCollection('projects').get();
        for (final doc in projSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['id'] ?? doc.id).toString().trim();
          final sName = (data['siteName'] ?? data['projectName'] ?? doc.id).toString().trim();
          final supName = (data['assignedSupervisor'] ?? data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim().toLowerCase();
          final supId = (data['supervisorId'] ?? '').toString().trim().toLowerCase();

          final isAssigned = (cleanSupId.isNotEmpty && supId == cleanSupId) ||
              (cleanSupName.isNotEmpty && supName == cleanSupName) ||
              (cleanSupName.isNotEmpty && supName.contains(cleanSupName));

          if (isAssigned || cleanSupName.isEmpty) {
            addOrMergeSite(
              rawSiteId: sId,
              rawSiteName: sName,
              rawDocId: doc.id,
              projectName: sName,
              supervisor: data['assignedSupervisor'] ?? data['supervisor'],
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading from projects: $e');
      }

      // 2. Fallback to siteSupervisorMap
      try {
        final mapSnap = await FirestoreService.getCollection('siteSupervisorMap').get();
        for (final doc in mapSnap.docs) {
          final data = doc.data();
          final sup = (data['supervisor'] ?? '').toString().trim().toLowerCase();
          if (cleanSupName.isEmpty || sup == cleanSupName || sup.contains(cleanSupName)) {
            final sId = (data['siteId'] ?? data['site'] ?? doc.id).toString().trim();
            final sName = (data['siteName'] ?? data['projectName'] ?? data['site'] ?? doc.id).toString().trim();
            addOrMergeSite(
              rawSiteId: sId,
              rawSiteName: sName,
              rawDocId: doc.id,
              projectName: data['projectName'],
              supervisor: data['supervisor'],
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading siteSupervisorMap: $e');
      }

      // 3. Fallback to workerSiteMapping
      try {
        final mapSnap = await FirestoreService.getCollection('workerSiteMapping').get();
        for (final doc in mapSnap.docs) {
          final data = doc.data();
          final sup = (data['supervisor'] ?? '').toString().trim().toLowerCase();
          if (cleanSupName.isEmpty || sup == cleanSupName || sup.contains(cleanSupName)) {
            final sId = (data['siteId'] ?? doc.id).toString().trim();
            final sName = (data['siteName'] ?? data['site'] ?? doc.id).toString().trim();
            addOrMergeSite(
              rawSiteId: sId,
              rawSiteName: sName,
              rawDocId: doc.id,
              projectName: data['projectName'] ?? sName,
              supervisor: data['supervisor'],
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading workerSiteMapping sites: $e');
      }

      // If still empty, load all projects as fallback
      if (uniqueSitesBySiteId.isEmpty) {
        try {
          final allSnap = await FirestoreService.getCollection('projects').get();
          for (final doc in allSnap.docs) {
            final data = doc.data();
            final sId = (data['siteId'] ?? doc.id).toString().trim();
            final sName = (data['siteName'] ?? data['projectName'] ?? doc.id).toString().trim();
            addOrMergeSite(
              rawSiteId: sId,
              rawSiteName: sName,
              rawDocId: doc.id,
              projectName: sName,
              supervisor: data['assignedSupervisor'] ?? data['supervisor'],
            );
          }
        } catch (_) {}
      }

      // Convert to clean list
      final List<Map<String, dynamic>> finalSites = uniqueSitesBySiteId.values.map((s) {
        final sId = s['siteId']?.toString() ?? '';
        final sName = s['siteName']?.toString() ?? '';
        final displayName = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);

        return {
          'id': sId.isNotEmpty ? sId : sName,
          'siteId': sId,
          'siteName': sName.isNotEmpty ? sName : sId,
          'site': sName.isNotEmpty ? sName : sId,
          'displayName': displayName,
          'projectName': s['projectName'] ?? '',
          'supervisor': s['supervisor'] ?? '',
        };
      }).toList();

      finalSites.sort((a, b) => (a['displayName'] as String).compareTo(b['displayName'] as String));

      if (mounted) {
        setState(() {
          _sites = finalSites;
          _isLoadingSites = false;
          if (_selectedSiteId != null && !_sites.any((s) => s['id'] == _selectedSiteId)) {
            _selectedSiteId = null;
            _selectedSiteName = null;
            _workers.clear();
            _extraWorkers.clear();
            _attendanceStatus.clear();
          }
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchAssignedSitesAndLoad: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
      }
    }
  }

  void _onSiteSelected(String? siteId) {
    if (siteId == null || siteId == '__loading__' || siteId == '__empty__') return;
    final site = _sites.firstWhere(
      (s) => s['id'] == siteId || s['siteId'] == siteId,
      orElse: () => {},
    );
    final String siteName = (site['siteName'] ?? site['site'] ?? siteId).toString();
    final String actualSiteId = (site['siteId'] ?? siteId).toString();

    setState(() {
      _selectedSiteId = actualSiteId;
      _selectedSiteName = siteName;
      _workers.clear();
      _extraWorkers.clear();
      _attendanceStatus.clear();
    });

    _setupRealTimeStreams(actualSiteId, siteName);
  }

  /// Real-time stream listeners for both worker site mapping and daily attendance
  void _setupRealTimeStreams(String siteId, String siteName) {
    _siteMappingSub?.cancel();
    _todayAttendanceSub?.cancel();

    setState(() => _isLoadingWorkers = true);

    final cleanSiteId = siteId.trim().toLowerCase();
    final cleanSiteName = siteName.trim().toLowerCase();
    final combined1 = '${siteId}_$siteName'.trim().toLowerCase();
    final combined2 = '${siteName}_$siteId'.trim().toLowerCase();

    final Set<String> candidateKeys = {
      cleanSiteId,
      cleanSiteName,
      combined1,
      combined2,
    }..removeWhere((k) => k.isEmpty);

    for (final key in List<String>.from(candidateKeys)) {
      if (key.contains('_')) {
        for (final part in key.split('_')) {
          if (part.trim().isNotEmpty) candidateKeys.add(part.trim().toLowerCase());
        }
      }
      if (key.contains('-')) {
        for (final part in key.split('-')) {
          if (part.trim().isNotEmpty) candidateKeys.add(part.trim().toLowerCase());
        }
      }
    }

    bool matchesSiteKey(String? val) {
      if (val == null) return false;
      final clean = val.trim().toLowerCase();
      if (clean.isEmpty) return false;
      if (candidateKeys.contains(clean)) return true;
      for (final key in candidateKeys) {
        if (clean == key || clean.contains(key) || key.contains(clean)) return true;
      }
      return false;
    }

    // 1. Stream worker mapping for this site across workerSiteMapping
    _siteMappingSub = FirestoreService.getCollection('workerSiteMapping')
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;
      final Map<String, Map<String, dynamic>> dedupWorkers = {};

      for (final doc in snap.docs) {
        final docId = doc.id.trim().toLowerCase();
        final data = doc.data();
        final dSiteId = (data['siteId'] ?? '').toString();
        final dSite = (data['site'] ?? '').toString();
        final dSiteName = (data['siteName'] ?? '').toString();
        final dProjectName = (data['projectName'] ?? '').toString();

        final isMatch = candidateKeys.contains(docId) ||
            matchesSiteKey(docId) ||
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
                final key = name.toLowerCase();
                dedupWorkers[key] = {
                  'workerId': wId,
                  'workerName': name,
                  'workerDesignation': (w['workerDesignation'] ?? w['designation'] ?? w['role'] ?? 'Worker').toString().trim(),
                  'workerSalary': (w['workerSalary'] ?? w['salary'] ?? w['wage'] ?? '0').toString().trim(),
                  'workerPhone': (w['workerPhone'] ?? w['phoneNumber'] ?? w['phone'] ?? w['mobile'] ?? '').toString().trim(),
                  'siteId': (w['siteId'] ?? siteId).toString(),
                  'siteName': (w['siteName'] ?? siteName).toString(),
                };
              }
            }
          }
        }
      }

      // If empty from workerSiteMapping, check fallback collections
      if (dedupWorkers.isEmpty) {
        try {
          final legacySnap = await FirestoreService.getCollection('workerSiteMap').get();
          for (final doc in legacySnap.docs) {
            final docId = doc.id.trim().toLowerCase();
            final data = doc.data();
            final dSiteId = (data['siteId'] ?? '').toString();
            final dSite = (data['site'] ?? '').toString();
            final dSiteName = (data['siteName'] ?? '').toString();

            if (candidateKeys.contains(docId) || matchesSiteKey(docId) || matchesSiteKey(dSiteId) || matchesSiteKey(dSite) || matchesSiteKey(dSiteName)) {
              final raw = (data['workers'] ?? data['mappedWorkers']) as List<dynamic>? ?? [];
              for (final item in raw) {
                if (item is Map) {
                  final w = Map<String, dynamic>.from(item);
                  final name = (w['workerName'] ?? w['name'] ?? w['fullName'] ?? '').toString().trim();
                  if (name.isNotEmpty) {
                    final wId = (w['workerId'] ?? w['id'] ?? name).toString().trim();
                    final key = name.toLowerCase();
                    dedupWorkers[key] = {
                      'workerId': wId,
                      'workerName': name,
                      'workerDesignation': (w['workerDesignation'] ?? w['designation'] ?? 'Worker').toString().trim(),
                      'workerSalary': (w['workerSalary'] ?? w['salary'] ?? '0').toString().trim(),
                      'workerPhone': (w['workerPhone'] ?? w['phoneNumber'] ?? '').toString().trim(),
                      'siteId': (w['siteId'] ?? siteId).toString(),
                      'siteName': (w['siteName'] ?? siteName).toString(),
                    };
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      // If still empty, check workersConfig for any worker directly assigned to this site
      if (dedupWorkers.isEmpty) {
        try {
          final confSnap = await FirestoreService.getCollection('workersConfig').get();
          for (final doc in confSnap.docs) {
            final data = doc.data();
            final wSite = (data['site'] ?? data['siteId'] ?? data['assignedSite'] ?? data['siteName'] ?? '').toString();
            if (matchesSiteKey(wSite)) {
              final name = (data['workerName'] ?? data['name'] ?? data['fullName'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                final wId = (data['workerId'] ?? data['id'] ?? doc.id).toString().trim();
                final key = name.toLowerCase();
                dedupWorkers[key] = {
                  'workerId': wId,
                  'workerName': name,
                  'workerDesignation': (data['workerDesignation'] ?? data['designation'] ?? data['role'] ?? 'Worker').toString().trim(),
                  'workerSalary': (data['workerSalary'] ?? data['salary'] ?? data['wage'] ?? '0').toString().trim(),
                  'workerPhone': (data['workerPhone'] ?? data['phoneNumber'] ?? data['phone'] ?? '').toString().trim(),
                  'siteId': siteId,
                  'siteName': siteName,
                };
              }
            }
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> workersList = dedupWorkers.values.toList();
      workersList.sort((a, b) => (a['workerName'] as String).toLowerCase().compareTo((b['workerName'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          _workers = workersList;
          _isLoadingWorkers = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error streaming worker mapping: $e');
      if (mounted) setState(() => _isLoadingWorkers = false);
    });

    // 2. Stream today's attendance document
    final formattedDayMonthYear = DateFormat('dd_MM_yyyy').format(DateTime.now());
    _todayAttendanceSub = FirestoreService.getCollection('workersAttendance')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final Map<String, String> loadedStatus = {};
      List<Map<String, dynamic>> loadedExtra = [];

      for (final doc in snap.docs) {
        final docId = doc.id.trim();
        final data = doc.data();
        final dSiteId = (data['siteId'] ?? '').toString();
        final dSite = (data['site'] ?? '').toString();
        final dSiteName = (data['siteName'] ?? '').toString();
        final dDate = (data['Day'] ?? data['date'] ?? '').toString();

        final isSiteMatch = docId.contains(formattedDayMonthYear) &&
            (matchesSiteKey(docId) || matchesSiteKey(dSiteId) || matchesSiteKey(dSite) || matchesSiteKey(dSiteName));

        final isDateMatch = dDate == _currentDate || docId.contains(formattedDayMonthYear);

        if (isSiteMatch || (isDateMatch && (matchesSiteKey(dSiteId) || matchesSiteKey(dSite) || matchesSiteKey(dSiteName)))) {
          final workersMap = data['workers'] as Map<String, dynamic>? ?? {};
          final rawExtra = data['extraWorkers'] as List<dynamic>? ?? [];

          workersMap.forEach((wName, wDetails) {
            if (wDetails is Map) {
              final status = (wDetails['attendance'] ?? wDetails['status'] ?? '').toString();
              if (status.isNotEmpty) {
                loadedStatus[wName] = status;
              }
            }
          });

          if (rawExtra.isNotEmpty) {
            loadedExtra = rawExtra.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }

      setState(() {
        if (loadedStatus.isNotEmpty) {
          _attendanceStatus.addAll(loadedStatus);
        }
        if (loadedExtra.isNotEmpty) {
          _extraWorkers = loadedExtra;
        }
      });
    }, onError: (e) {
      debugPrint('Error streaming today attendance: $e');
    });
  }

  void _setAttendance(String workerName, String status) {
    setState(() {
      _attendanceStatus[workerName] = status;
    });
  }

  void _addExtraWorkers() {
    final type = _isCustomType
        ? _customTypeController.text.trim()
        : _selectedExtraWorkerType;

    if (type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid worker trade/category'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_currentExtraCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker count must be at least 1'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final existingIndex = _extraWorkers.indexWhere(
      (e) => (e['workerType'] ?? '').toString().toLowerCase() == type.toLowerCase(),
    );

    setState(() {
      if (existingIndex >= 0) {
        final current = (_extraWorkers[existingIndex]['count'] as num?)?.toInt() ?? 0;
        _extraWorkers[existingIndex]['count'] = current + _currentExtraCount;
      } else {
        _extraWorkers.add({
          'workerType': type,
          'count': _currentExtraCount,
          'supervisor': widget.supervisorName,
        });
      }

      // Reset input
      _currentExtraCount = 1;
      _customTypeController.clear();
      _isCustomType = false;
      _selectedExtraWorkerType = 'Mason';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $_currentExtraCount extra $type worker(s)'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeExtraWorker(int index) {
    setState(() {
      _extraWorkers.removeAt(index);
    });
  }

  void _updateExtraCount(int index, int delta) {
    setState(() {
      final current = (_extraWorkers[index]['count'] as num?)?.toInt() ?? 1;
      final updated = current + delta;
      if (updated <= 0) {
        _extraWorkers.removeAt(index);
      } else {
        _extraWorkers[index]['count'] = updated;
      }
    });
  }

  int get _totalExtraCount {
    return _extraWorkers.fold(0, (acc, item) => acc + ((item['count'] as num?)?.toInt() ?? 0));
  }

  int get _totalMappedPresentCount {
    return _workers.where((worker) {
      final name = (worker['workerName'] ?? '').toString();
      final status = (_attendanceStatus[name] ?? '').toLowerCase();
      return status == 'present' || status == 'overtime' || status == 'half day';
    }).length;
  }

  int get _totalWorkforcePresentCount {
    return _totalMappedPresentCount + _totalExtraCount;
  }

  Future<void> _submitAttendance() async {
    if (_selectedSiteId == null || _selectedSiteName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first')),
      );
      return;
    }

    if (_workers.isEmpty && _extraWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mapped workers or extra workers to record attendance for')),
      );
      return;
    }

    // Check if mapped workers have attendance marked
    final unMarkedWorkers = _workers.where((w) {
      final name = (w['workerName'] ?? '').toString();
      return (_attendanceStatus[name] ?? '').isEmpty;
    }).toList();

    if (unMarkedWorkers.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please mark attendance for all ${unMarkedWorkers.length} mapped worker(s)'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String month = _currentMonth;
      final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String formattedDayMonthYear = DateFormat('dd_MM_yyyy').format(DateTime.now());
      final batch = FirebaseFirestore.instance.batch();

      // 1. Process Mapped Workers Individual Attendance
      final Map<String, dynamic> workersDataLog = {};
      for (final worker in _workers) {
        final workerName = (worker['workerName'] ?? '').toString();
        final attendanceStatus = _attendanceStatus[workerName] ?? 'Absent';
        final workerId = (worker['workerId'] ?? '${workerName}_$_selectedSiteId').toString();
        final salaryStr = (worker['workerSalary'] ?? '0').toString();
        final designation = (worker['workerDesignation'] ?? 'Worker').toString();

        workersDataLog[workerName] = {
          'workerId': workerId,
          'workerName': workerName,
          'designation': designation,
          'salary': salaryStr,
          'attendance': attendanceStatus,
          'siteId': _selectedSiteId,
          'siteName': _selectedSiteName,
          'markedAt': FieldValue.serverTimestamp(),
        };

        // Monthly record update for payroll calculation
        final String workerDocId = '${workerId}_$month';
        final docRef = FirestoreService.getCollection('WorkerMonthlyAttendance').doc(workerDocId);

        final Map<String, dynamic> todayAttendanceEntry = {
          'status': attendanceStatus.toLowerCase(),
          'markedAt': FieldValue.serverTimestamp(),
          'salaryPerDay': double.tryParse(salaryStr) ?? 0.0,
        };

        batch.set(docRef, {
          'workerId': workerId,
          'workerName': workerName,
          'designation': designation,
          'site': _selectedSiteName,
          'siteId': _selectedSiteId,
          'month': month,
          'baseSalary': salaryStr,
          'status': 'verified',
          'attendanceData': {todayDate: todayAttendanceEntry},
        }, SetOptions(merge: true));
      }

      // 2. Prepare Comprehensive Daily Attendance Document (Mapped + Extra Count-Based)
      final dailyDocData = {
        'day': DateFormat('dd').format(DateTime.now()),
        'month': DateFormat('MM-yyyy').format(DateTime.now()),
        'site': _selectedSiteName,
        'siteId': _selectedSiteId,
        'siteName': _selectedSiteName,
        'supervisor': widget.supervisorName,
        'supervisorId': widget.supervisorId,
        'workers': workersDataLog,
        'extraWorkers': _extraWorkers,
        'totalMappedWorkers': _workers.length,
        'totalMappedPresent': _totalMappedPresentCount,
        'totalExtraWorkers': _totalExtraCount,
        'totalPresentCount': _totalWorkforcePresentCount,
        'totalWorkersOnSite': _totalWorkforcePresentCount,
        'Day': _currentDate,
        'date': _currentDate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRefBySiteId = FirestoreService.getCollection('workersAttendance')
          .doc('${_selectedSiteId}_$formattedDayMonthYear');
      final docRefBySiteName = FirestoreService.getCollection('workersAttendance')
          .doc('${_selectedSiteName}_$formattedDayMonthYear');

      batch.set(docRefBySiteId, dailyDocData, SetOptions(merge: true));
      if (_selectedSiteName != _selectedSiteId) {
        batch.set(docRefBySiteName, dailyDocData, SetOptions(merge: true));
      }

      await batch.commit();

      // Recalculate monthly salaries
      await _recalculateMonthlySalaries();

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance submitted: $_totalWorkforcePresentCount total workers present ($_totalMappedPresentCount mapped + $_totalExtraCount extra)',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _recalculateMonthlySalaries() async {
    try {
      final String month = _currentMonth;
      final querySnapshot = await FirestoreService.getCollection('WorkerMonthlyAttendance')
          .where('month', isEqualTo: month)
          .where('siteId', isEqualTo: _selectedSiteId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic> attendanceMap =
            data['attendanceData'] as Map<String, dynamic>? ?? {};

        double totalSalary = 0.0;
        int presentDays = 0;

        attendanceMap.forEach((date, details) {
          if (details is Map) {
            final String status = details['status']?.toString().toLowerCase() ?? '';
            final double salaryPerDay =
                double.tryParse(details['salaryPerDay']?.toString() ?? '0') ?? 0.0;

            if (status == 'present' || status == 'overtime') {
              totalSalary += salaryPerDay;
              presentDays += 1;
            } else if (status == 'half day') {
              totalSalary += (salaryPerDay / 2.0);
              presentDays += 1;
            }
          }
        });

        batch.update(doc.reference, {
          'calculatedSalary': totalSalary,
          'totalPresentDays': presentDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error in salary recalculation: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'overtime':
        return const Color(0xFF8B5CF6);
      case 'half day':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'overtime':
        return 'Overtime';
      case 'half day':
        return 'Half Day';
      default:
        return 'Not Marked';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Daily Attendance Management',
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isLoadingSites
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            tooltip: 'Reload Sites',
            onPressed: _isLoadingSites ? null : _fetchAssignedSitesAndLoad,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: Column(
            children: [
              // Fixed Top Section: Site Selection
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: _buildSiteSelectionSection(primaryColor),
              ),

              // Workforce Summary Ribbon (if site selected)
              if (_selectedSiteId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildTotalWorkforceSummaryRibbon(primaryColor),
                ),

              // Main Content Scrollable
              Expanded(
                child: _selectedSiteId == null
                    ? _buildNoSiteSelectedState(primaryColor)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Mapped Configured Workers Section
                            _buildMappedWorkersCard(primaryColor),

                            const SizedBox(height: 16),

                            // 2. Extra / Unknown Workers (Count Based) Section
                            _buildExtraWorkersCard(primaryColor),

                            const SizedBox(height: 20),

                            // Submit Button
                            _buildSubmitButton(primaryColor),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSiteSelectedState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 48,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select an Assigned Site',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Supervisor: ${widget.supervisorName}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalWorkforceSummaryRibbon(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL WORKFORCE TODAY',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$_totalWorkforcePresentCount Present on Site',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalMappedPresentCount Mapped + $_totalExtraCount Extra',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteSelectionSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('site_dd_${_selectedSiteId}_${_sites.length}_$_isLoadingSites'),
            initialValue: _selectedSiteId,
            dropdownColor: Colors.white,
            isExpanded: true,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Select Assigned Site *',
              labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              prefixIcon: Icon(Icons.construction_rounded, color: primaryColor, size: 18),
              suffixIcon: _isLoadingSites
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      width: 16,
                      height: 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.8),
              ),
            ),
            items: _isLoadingSites
                ? [
                    const DropdownMenuItem(
                      value: '__loading__',
                      enabled: false,
                      child: Text('Loading assigned sites...', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ]
                : _sites.isEmpty
                    ? [
                        const DropdownMenuItem(
                          value: '__empty__',
                          enabled: false,
                          child: Text('No assigned sites found', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                      ]
                    : _sites.map<DropdownMenuItem<String>>((site) {
                        return DropdownMenuItem<String>(
                          value: site['id'] as String?,
                          child: Text(
                            site['displayName'] ?? site['site'] ?? 'Unnamed Site',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
            onChanged: (_isLoadingSites || _sites.isEmpty) ? null : _onSiteSelected,
          ),
          if (_selectedSiteId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 13, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Date: $_currentDate',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: primaryColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Supervisor: ${widget.supervisorName}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMappedWorkersCard(Color primaryColor) {
    final markedCount = _attendanceStatus.values.where((status) => status.isNotEmpty).length;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.badge_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configured / Mapped Workers',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${_workers.length} mapped to site',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              if (_workers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: markedCount == _workers.length ? const Color(0xFFECFDF5) : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: markedCount == _workers.length ? const Color(0xFF6EE7B7) : primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '$markedCount/${_workers.length} marked',
                    style: TextStyle(
                      color: markedCount == _workers.length ? const Color(0xFF059669) : primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),

          if (_isLoadingWorkers)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
              ),
            )
          else if (_workers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Icon(Icons.person_off_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'No mapped workers found for this site',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Assign workers under Manager Worker Mapping',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workers.length,
              itemBuilder: (context, index) {
                final worker = _workers[index];
                final workerName = (worker['workerName'] ?? '').toString();
                final designation = (worker['workerDesignation'] ?? 'Worker').toString();
                final currentStatus = _attendanceStatus[workerName] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: primaryColor.withValues(alpha: 0.12),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        title: Text(
                          workerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                        ),
                        subtitle: Text(
                          designation,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                        ),
                        trailing: currentStatus.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentStatus).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getStatusColor(currentStatus).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _getStatusText(currentStatus),
                                  style: TextStyle(
                                    color: _getStatusColor(currentStatus),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: _buildAttendanceButton('Present', workerName, currentStatus)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildAttendanceButton('Absent', workerName, currentStatus)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildAttendanceButton('Half Day', workerName, currentStatus)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildAttendanceButton('Overtime', workerName, currentStatus)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExtraWorkersCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extra / Unregistered Workers',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Text(
                        'Count-based daily attendance by worker trade',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              if (_extraWorkers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    '$_totalExtraCount Extra',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Input Form: Category & Count Stepper
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Worker Category Selector
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Worker Type / Trade',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 4),
                          if (!_isCustomType)
                            DropdownButtonFormField<String>(
                              key: ValueKey('extra_cat_${_selectedExtraWorkerType}_${_workerCategories.length}_$_isLoadingLabours'),
                              initialValue: _workerCategories.contains(_selectedExtraWorkerType)
                                  ? _selectedExtraWorkerType
                                  : (_workerCategories.isNotEmpty ? _workerCategories.first : null),
                              dropdownColor: Colors.white,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                suffixIcon: _isLoadingLabours
                                    ? Container(
                                        padding: const EdgeInsets.all(12),
                                        width: 14,
                                        height: 14,
                                        child: const CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              items: _workerCategories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == 'Other / Custom') {
                                  setState(() {
                                    _isCustomType = true;
                                  });
                                } else if (v != null) {
                                  setState(() {
                                    _selectedExtraWorkerType = v;
                                  });
                                }
                              },
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customTypeController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter trade (e.g. Scaffolder)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  onPressed: () => setState(() => _isCustomType = false),
                                  tooltip: 'Back to standard list',
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Quantity Stepper
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Count',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    if (_currentExtraCount > 1) {
                                      setState(() => _currentExtraCount--);
                                    }
                                  },
                                ),
                                Text(
                                  '$_currentExtraCount',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    setState(() => _currentExtraCount++);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add Button
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _addExtraWorkers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // List of added extra worker counts
          if (_extraWorkers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'No extra workers added for today',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _extraWorkers.length,
              separatorBuilder: (c, i) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _extraWorkers[index];
                final type = item['workerType'] ?? 'Worker';
                final count = (item['count'] as num?)?.toInt() ?? 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.handyman_rounded, color: Color(0xFFD97706), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            type,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Stepper
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _updateExtraCount(index, -1),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Icon(Icons.remove_rounded, size: 14, color: Color(0xFF92400E)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF78350F)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _updateExtraCount(index, 1),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Icon(Icons.add_rounded, size: 14, color: Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            onPressed: () => _removeExtraWorker(index),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton(String status, String workerName, String currentStatus) {
    final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
    final statusColor = _getStatusColor(status);

    return InkWell(
      onTap: () => _setAttendance(workerName, status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? statusColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? statusColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return _isSubmitting
        ? const Center(child: CircularProgressIndicator())
        : SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: Text(
                'SAVE ATTENDANCE ($_totalWorkforcePresentCount PRESENT)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          );
  }
}
