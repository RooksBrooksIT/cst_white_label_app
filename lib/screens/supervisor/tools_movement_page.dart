import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ToolsMovementPage extends StatefulWidget {
  const ToolsMovementPage({super.key});

  @override
  State<ToolsMovementPage> createState() => _ToolsMovementPageState();
}

class _ToolsMovementPageState extends State<ToolsMovementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Color get primaryColor => Theme.of(context).primaryColor;

  // ── Logged In User State ──────────────────────────────────────────────────
  String _loggedInManagerName = '';

  // ── Company to Site State ──────────────────────────────────────────────────
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedSiteId;
  String? _selectedTool;
  int? _toolCount = 1;
  int? _selectedToolAvailableCount;
  final List<Map<String, dynamic>> _addedTools = [];
  bool _isMovingTools = false;

  // ── Site to Company State ──────────────────────────────────────────────────
  final TextEditingController _returnProjectNameController = TextEditingController();
  final TextEditingController _returnManagerNameController = TextEditingController();
  final TextEditingController _returnSupervisorNameController = TextEditingController();
  final TextEditingController _returnToolCountController = TextEditingController();
  DateTime _returnSelectedDate = DateTime.now();
  String? _returnSelectedSiteId;
  String? _returnSelectedTool;
  int? _returnToolCount = 1;
  int? _returnSelectedToolAvailableCount;
  final List<Map<String, dynamic>> _returnAddedTools = [];
  bool _isReturningTools = false;

  // ── Logs Tab State ────────────────────────────────────────────────────────
  String _logSearchQuery = '';
  String _selectedLogType = 'All'; // 'All', 'Dispatched', 'Returned'
  final TextEditingController _logSearchController = TextEditingController();
  List<Map<String, dynamic>> _movementLogs = [];
  bool _isLoadingLogs = false;

  // ── Shared Reference Data ─────────────────────────────────────────────────
  List<String> _siteIds = [];
  Map<String, Map<String, String>> _siteDetailsMap = {};
  List<Map<String, dynamic>> _tools = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _fetchMovementLogs();
      }
    });
    _toolCountController.text = '1';
    _returnToolCountController.text = '1';
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectNameController.dispose();
    _managerNameController.dispose();
    _supervisorNameController.dispose();
    _toolCountController.dispose();
    _returnProjectNameController.dispose();
    _returnManagerNameController.dispose();
    _returnSupervisorNameController.dispose();
    _returnToolCountController.dispose();
    _logSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([
        _fetchCurrentManagerName(),
        _fetchSitesData(),
        _fetchTools(),
        _fetchMovementLogs(),
      ]);
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Error loading data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _fetchCurrentManagerName() async {
    try {
      final auth = AuthService();
      String resolvedName = '';

      if (auth.userRole == UserRole.organization) {
        resolvedName = (auth.userData['org_name'] ??
                auth.userData['username'] ??
                'Organization Administrator')
            .toString();
      } else if (auth.userRole == UserRole.manager) {
        final data = auth.userData;
        resolvedName = (data['FullName'] ??
                data['fullName'] ??
                data['UserName'] ??
                data['username'] ??
                '')
            .toString();

        if (resolvedName.isEmpty || resolvedName == 'Manager') {
          final username = (data['username'] ?? data['UserName'] ?? '').toString().trim();
          if (username.isNotEmpty) {
            final q = await FirestoreService.getCollection('manager')
                .where('UserName', isEqualTo: username)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final docData = q.docs.first.data();
              resolvedName = (docData['FullName'] ?? docData['fullName'] ?? docData['name'] ?? '').toString();
            }
          }
        }
      }

      if (resolvedName.isNotEmpty && mounted) {
        setState(() {
          _loggedInManagerName = resolvedName;
          if (_managerNameController.text.trim().isEmpty) {
            _managerNameController.text = resolvedName;
          }
          if (_returnManagerNameController.text.trim().isEmpty) {
            _returnManagerNameController.text = resolvedName;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching logged in manager name: $e');
    }
  }

  Future<void> _fetchSitesData() async {
    try {
      final snapshot = await FirestoreService.getCollection('siteSupervisorMap').get();
      final Map<String, Map<String, String>> siteMap = {};
      final Set<String> ids = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final site = (data['site'] ?? doc.id).toString().trim();
        if (site.isNotEmpty) {
          ids.add(site);
          siteMap[site] = {
            'projectName': (data['projectName'] ?? '').toString(),
            'supervisor': (data['supervisor'] ?? '').toString(),
          };
        }
      }

      try {
        final sitesSnapshot = await FirestoreService.getCollection('Site').get();
        for (var doc in sitesSnapshot.docs) {
          final sId = doc.id.trim();
          if (sId.isNotEmpty && !siteMap.containsKey(sId)) {
            final data = doc.data();
            ids.add(sId);
            siteMap[sId] = {
              'projectName': (data['projectName'] ?? data['siteName'] ?? '').toString(),
              'supervisor': (data['supervisorName'] ?? '').toString(),
            };
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _siteIds = ids.toList()..sort();
          _siteDetailsMap = siteMap;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
  }

  Future<void> _fetchTools() async {
    try {
      final snapshot = await FirestoreService.getCollection('tools').get();
      if (!mounted) return;
      setState(() {
        _tools = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'docId': doc.id,
            'toolId': data['toolId'] ?? '',
            'toolName': data['toolName'] ?? '',
            'toolCode': data['toolCode'] ?? '',
            'toolOwner': data['toolOwner'] ?? 'Org',
            'availableCount': data['availableCount'] ?? data['toolCount'] ?? 0,
            'toolCount': data['toolCount'] ?? 0,
            'description': data['description'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching tools: $e');
    }
  }

  Future<void> _fetchMovementLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final List<Map<String, dynamic>> combined = [];

      try {
        final movementSnap = await FirestoreService.getCollection('toolsMovement')
            .orderBy('date', descending: true)
            .limit(50)
            .get();

        for (var doc in movementSnap.docs) {
          final data = doc.data();
          combined.add({
            'docId': doc.id,
            'type': 'Dispatched',
            'id': data['tmId'] ?? doc.id,
            'date': data['date'] ?? '',
            'siteId': data['mtSiteId'] ?? '',
            'projectName': data['projectName'] ?? '',
            'manager': data['mgrName'] ?? '',
            'supervisor': data['supervisorName'] ?? '',
            'tools': data['tools'] is List ? data['tools'] : [],
            'timestamp': doc.id,
          });
        }
      } catch (_) {}

      try {
        final returnSnap = await FirestoreService.getCollection('toolsReturn')
            .orderBy('date', descending: true)
            .limit(50)
            .get();

        for (var doc in returnSnap.docs) {
          final data = doc.data();
          combined.add({
            'docId': doc.id,
            'type': 'Returned',
            'id': data['trId'] ?? doc.id,
            'date': data['date'] ?? '',
            'siteId': data['rfSiteId'] ?? '',
            'projectName': data['projectName'] ?? '',
            'manager': data['mgrName'] ?? '',
            'supervisor': data['supervisorName'] ?? '',
            'tools': data['tools'] is List ? data['tools'] : [],
            'timestamp': doc.id,
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _movementLogs = combined;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  void _onSiteSelected(String? siteId, bool isReturn) {
    if (siteId == null) return;
    final info = _siteDetailsMap[siteId] ?? {};
    final projectName = info['projectName'] ?? '';
    final supervisor = info['supervisor'] ?? '';

    setState(() {
      if (isReturn) {
        _returnSelectedSiteId = siteId;
        _returnProjectNameController.text = projectName;
        _returnSupervisorNameController.text = supervisor;
        if (_returnSelectedTool != null) {
          _fetchAvailableCountForReturnSelectedTool(_returnSelectedTool);
        }
      } else {
        _selectedSiteId = siteId;
        _projectNameController.text = projectName;
        _supervisorNameController.text = supervisor;
      }
    });
  }

  Future<void> _fetchAvailableCountForSelectedTool(String? toolId) async {
    if (toolId == null) {
      setState(() => _selectedToolAvailableCount = null);
      return;
    }
    final tool = _tools.firstWhere(
      (t) => t['toolId'] == toolId || t['toolCode'] == toolId,
      orElse: () => {},
    );
    final toolCode = tool['toolCode'] ?? '';
    if (toolCode.isEmpty) {
      setState(() => _selectedToolAvailableCount = 0);
      return;
    }

    try {
      final querySnapshot = await FirestoreService.getCollection('toolsAtCompany')
          .where('toolCode', isEqualTo: toolCode)
          .limit(1)
          .get();

      int count = 0;
      if (querySnapshot.docs.isNotEmpty) {
        final docData = querySnapshot.docs.first.data();
        count = docData['availableCount'] ?? docData['toolCount'] ?? 0;
      } else {
        count = tool['availableCount'] ?? tool['toolCount'] ?? 0;
      }
      if (mounted) {
        setState(() => _selectedToolAvailableCount = count);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _selectedToolAvailableCount = tool['availableCount'] ?? 0);
      }
    }
  }

  Future<void> _fetchAvailableCountForReturnSelectedTool(String? toolId) async {
    if (toolId == null || _returnSelectedSiteId == null || _returnSelectedSiteId!.isEmpty) {
      setState(() => _returnSelectedToolAvailableCount = null);
      return;
    }
    final tool = _tools.firstWhere(
      (t) => t['toolId'] == toolId || t['toolCode'] == toolId,
      orElse: () => {},
    );
    final toolCode = tool['toolCode'] ?? '';
    if (toolCode.isEmpty) {
      setState(() => _returnSelectedToolAvailableCount = 0);
      return;
    }

    try {
      final querySnapshot = await FirestoreService.getCollection('toolsInventory')
          .doc(toolCode)
          .get();

      int count = 0;
      if (querySnapshot.exists) {
        final data = querySnapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> availableCountAtSites =
            Map<String, dynamic>.from(data['availableCountAtSites'] ?? {});
        count = (availableCountAtSites[_returnSelectedSiteId] as int?) ?? 0;
      }
      if (mounted) {
        setState(() => _returnSelectedToolAvailableCount = count);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _returnSelectedToolAvailableCount = 0);
      }
    }
  }

  void _addToolToStaging(bool isReturn) {
    final selectedTool = isReturn ? _returnSelectedTool : _selectedTool;
    final count = isReturn ? _returnToolCount : _toolCount;
    final available = isReturn ? _returnSelectedToolAvailableCount : _selectedToolAvailableCount;

    if (selectedTool == null || selectedTool.isEmpty) {
      AppTheme.showErrorToast(context, 'Please select a tool first');
      return;
    }
    if (count == null || count <= 0) {
      AppTheme.showErrorToast(context, 'Please enter a valid count');
      return;
    }
    if (available != null && count > available) {
      AppTheme.showErrorToast(context, 'Cannot exceed available stock of $available units');
      return;
    }

    final toolObj = _tools.firstWhere(
      (t) => t['toolId'] == selectedTool || t['toolCode'] == selectedTool,
      orElse: () => {'toolId': selectedTool, 'toolCode': selectedTool, 'toolName': selectedTool},
    );

    setState(() {
      if (isReturn) {
        final existingIdx = _returnAddedTools.indexWhere((t) => t['toolId'] == toolObj['toolId']);
        if (existingIdx >= 0) {
          _returnAddedTools[existingIdx]['count'] = count;
        } else {
          _returnAddedTools.add({
            'toolId': toolObj['toolId'],
            'toolCode': toolObj['toolCode'],
            'toolName': toolObj['toolName'],
            'count': count,
          });
        }
        _returnSelectedTool = null;
        _returnToolCount = 1;
        _returnToolCountController.text = '1';
        _returnSelectedToolAvailableCount = null;
      } else {
        final existingIdx = _addedTools.indexWhere((t) => t['toolId'] == toolObj['toolId']);
        if (existingIdx >= 0) {
          _addedTools[existingIdx]['count'] = count;
        } else {
          _addedTools.add({
            'toolId': toolObj['toolId'],
            'toolCode': toolObj['toolCode'],
            'toolName': toolObj['toolName'],
            'count': count,
          });
        }
        _selectedTool = null;
        _toolCount = 1;
        _toolCountController.text = '1';
        _selectedToolAvailableCount = null;
      }
    });

    AppTheme.showSuccessToast(context, 'Added ${toolObj['toolName']} ($count units)');
  }

  void _resetForm(bool isReturn) {
    setState(() {
      if (isReturn) {
        _returnProjectNameController.clear();
        _returnManagerNameController.text = _loggedInManagerName;
        _returnSupervisorNameController.clear();
        _returnSelectedDate = DateTime.now();
        _returnSelectedSiteId = null;
        _returnSelectedTool = null;
        _returnToolCount = 1;
        _returnToolCountController.text = '1';
        _returnAddedTools.clear();
        _returnSelectedToolAvailableCount = null;
      } else {
        _projectNameController.clear();
        _managerNameController.text = _loggedInManagerName;
        _supervisorNameController.clear();
        _selectedDate = DateTime.now();
        _selectedSiteId = null;
        _selectedTool = null;
        _toolCount = 1;
        _toolCountController.text = '1';
        _addedTools.clear();
        _selectedToolAvailableCount = null;
      }
    });
  }

  Future<void> _updateToolsInventory({
    required String toolCode,
    required String siteId,
    required int count,
  }) async {
    final docRef = FirestoreService.getCollection('toolsInventory').doc(toolCode);
    final now = DateTime.now();
    final isoString = now.toIso8601String();

    await FirestoreService.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'toolCode': toolCode,
          'availableCountAtSites': {siteId: count},
          'lastUpdated': isoString,
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> availableCountAtSites =
            Map<String, dynamic>.from(data['availableCountAtSites'] ?? {});

        final currentSiteCount = (availableCountAtSites[siteId] as int?) ?? 0;
        final newSiteCount = currentSiteCount + count;

        if (newSiteCount <= 0) {
          availableCountAtSites.remove(siteId);
        } else {
          availableCountAtSites[siteId] = newSiteCount;
        }

        transaction.update(docRef, {
          'availableCountAtSites': availableCountAtSites,
          'lastUpdated': isoString,
        });
      }
    });
  }

  Future<void> _saveCompanyToSiteMovement() async {
    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      AppTheme.showErrorToast(context, 'Please select a destination Site ID');
      return;
    }
    if (_addedTools.isEmpty) {
      AppTheme.showErrorToast(context, 'Please add at least one tool to transfer');
      return;
    }

    setState(() => _isMovingTools = true);

    final dateStr = DateFormat('ddMMyyyy_HHmmss').format(DateTime.now());
    final docId = '${_selectedSiteId}_$dateStr';
    String tmId = 'TM001';

    try {
      final snapshot = await FirestoreService.getCollection('toolsMovement')
          .orderBy('tmId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastTmId = snapshot.docs.first['tmId'] as String?;
        if (lastTmId != null && lastTmId.startsWith('TM')) {
          final lastNum = int.tryParse(lastTmId.substring(2)) ?? 0;
          tmId = 'TM${(lastNum + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (_) {}

    final formattedDate =
        '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30';

    final toolsList = _addedTools.map((tool) {
      return {
        'toolId': tool['toolId'],
        'toolCode': tool['toolCode'],
        'toolName': tool['toolName'],
        'toolCount': tool['count'],
      };
    }).toList();

    final data = {
      'tmId': tmId,
      'date': formattedDate,
      'mgrName': _managerNameController.text.trim(),
      'supervisorName': _supervisorNameController.text.trim(),
      'mtSiteId': _selectedSiteId,
      'projectName': _projectNameController.text.trim(),
      'tools': toolsList,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      for (final tool in _addedTools) {
        final toolCode = tool['toolCode'] ?? tool['toolId'];
        final enteredCount = tool['count'] as int;

        final companyQuery = await FirestoreService.getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (companyQuery.docs.isNotEmpty) {
          await companyQuery.docs.first.reference.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        final siteDocRef = FirestoreService.getCollection('toolsAtSite').doc(toolCode);
        await siteDocRef.set({'toolCode': toolCode}, SetOptions(merge: true));
        await siteDocRef.update({
          'availableCount': FieldValue.increment(enteredCount),
        });

        await _updateToolsInventory(
          toolCode: toolCode,
          siteId: _selectedSiteId!,
          count: enteredCount,
        );
      }

      await FirestoreService.getCollection('toolsMovement').doc(docId).set(data);

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tools successfully dispatched to $_selectedSiteId!\nID: $tmId',
        );
      }

      _resetForm(false);
      _loadInitialData();
      _tabController.animateTo(2);
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to save movement: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isMovingTools = false);
      }
    }
  }

  Future<void> _saveSiteToCompanyReturn() async {
    if (_returnSelectedSiteId == null || _returnSelectedSiteId!.isEmpty) {
      AppTheme.showErrorToast(context, 'Please select the origin Site ID');
      return;
    }
    if (_returnAddedTools.isEmpty) {
      AppTheme.showErrorToast(context, 'Please add at least one tool to return');
      return;
    }

    setState(() => _isReturningTools = true);

    final dateStr = DateFormat('ddMMyyyy_HHmmss').format(DateTime.now());
    final docId = '${_returnSelectedSiteId}_$dateStr';
    String trId = 'TR001';

    try {
      final snapshot = await FirestoreService.getCollection('toolsReturn')
          .orderBy('trId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastTrId = snapshot.docs.first['trId'] as String?;
        if (lastTrId != null && lastTrId.startsWith('TR')) {
          final lastNum = int.tryParse(lastTrId.substring(2)) ?? 0;
          trId = 'TR${(lastNum + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (_) {}

    final formattedDate =
        '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30';

    final toolsList = _returnAddedTools.map((tool) {
      return {
        'toolId': tool['toolId'],
        'toolCode': tool['toolCode'],
        'toolName': tool['toolName'],
        'toolCount': tool['count'],
      };
    }).toList();

    final data = {
      'trId': trId,
      'date': formattedDate,
      'mgrName': _returnManagerNameController.text.trim(),
      'supervisorName': _returnSupervisorNameController.text.trim(),
      'rfSiteId': _returnSelectedSiteId,
      'projectName': _returnProjectNameController.text.trim(),
      'tools': toolsList,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      for (final tool in _returnAddedTools) {
        final toolCode = tool['toolCode'] ?? tool['toolId'];
        final enteredCount = tool['count'] as int;

        final siteQuery = await FirestoreService.getCollection('toolsAtSite')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (siteQuery.docs.isNotEmpty) {
          await siteQuery.docs.first.reference.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        final companyQuery = await FirestoreService.getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (companyQuery.docs.isNotEmpty) {
          await companyQuery.docs.first.reference.update({
            'availableCount': FieldValue.increment(enteredCount),
          });
        }

        await _updateToolsInventory(
          toolCode: toolCode,
          siteId: _returnSelectedSiteId!,
          count: -enteredCount,
        );
      }

      await FirestoreService.getCollection('toolsReturn').doc(docId).set(data);

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tools successfully returned to company!\nID: $trId',
        );
      }

      _resetForm(true);
      _loadInitialData();
      _tabController.animateTo(2);
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to save return: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isReturningTools = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD METHOD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tools Movement & Transfer',
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
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Executive Segmented Tab Switcher ────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      _buildTabItem(0, 'DISPATCH', 'To Site', Icons.local_shipping_rounded),
                      _buildTabItem(1, 'RETURN', 'To Org', Icons.assignment_return_rounded),
                      _buildTabItem(2, 'LOGS', 'History', Icons.receipt_long_rounded),
                    ],
                  );
                },
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────
            Expanded(
              child: _isLoadingData
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransferTab(isMobile, darkAccent, false),
                        _buildTransferTab(isMobile, darkAccent, true),
                        _buildLogsTab(isMobile, darkAccent),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title, String subtitle, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSFER TABS (Company to Site & Site to Company)
  // ---------------------------------------------------------------------------

  Widget _buildTransferTab(bool isMobile, Color darkAccent, bool isReturn) {
    final currentSiteId = isReturn ? _returnSelectedSiteId : _selectedSiteId;
    final currentSelectedTool = isReturn ? _returnSelectedTool : _selectedTool;
    final currentAvailable = isReturn ? _returnSelectedToolAvailableCount : _selectedToolAvailableCount;
    final currentCountController = isReturn ? _returnToolCountController : _toolCountController;
    final currentAddedTools = isReturn ? _returnAddedTools : _addedTools;
    final isSubmitting = isReturn ? _isReturningTools : _isMovingTools;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Destination / Origin Details Card ──────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isReturn ? Icons.assignment_return_rounded : Icons.local_shipping_rounded,
                            color: primaryColor,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isReturn ? 'Return Origin & Site Details' : 'Dispatch & Destination Site',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkAccent,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1),
                    ),

                    // Site Selector
                    _buildFieldLabel(
                      isReturn ? 'Select Source Site ID *' : 'Select Target Site ID *',
                      Icons.location_on_rounded,
                    ),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentSiteId,
                          isExpanded: true,
                          hint: Text(
                            isReturn ? 'Choose site to return from...' : 'Choose site to send tools...',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          items: _siteIds.map((sId) {
                            final info = _siteDetailsMap[sId] ?? {};
                            final pName = info['projectName'] ?? '';
                            return DropdownMenuItem<String>(
                              value: sId,
                              child: Text(
                                pName.isNotEmpty ? '$sId - $pName' : sId,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => _onSiteSelected(val, isReturn),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Auto-populated Project & Supervisor
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Project Name', Icons.business_rounded),
                              _buildReadOnlyBox(
                                isReturn
                                    ? _returnProjectNameController.text
                                    : _projectNameController.text,
                                'Auto-populated',
                                prefixIcon: Icons.apartment_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Supervisor Name', Icons.badge_rounded),
                              _buildReadOnlyBox(
                                isReturn
                                    ? _returnSupervisorNameController.text
                                    : _supervisorNameController.text,
                                'Auto-populated',
                                prefixIcon: Icons.person_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Manager Name & Date Picker
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Manager Name', Icons.manage_accounts_rounded),
                              _buildCustomTextField(
                                controller: isReturn
                                    ? _returnManagerNameController
                                    : _managerNameController,
                                hint: 'Enter Manager',
                                prefixIcon: Icons.edit_note_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Movement Date', Icons.calendar_today_rounded),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: isReturn ? _returnSelectedDate : _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      if (isReturn) {
                                        _returnSelectedDate = picked;
                                      } else {
                                        _selectedDate = picked;
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded, size: 18, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(
                                            isReturn ? _returnSelectedDate : _selectedDate,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. Tool Staging Tray & Selector ───────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.04),
                      blurRadius: 12,
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
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.handyman_rounded,
                                color: primaryColor,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Select Tools to Transfer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: darkAccent,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        if (currentAvailable != null)
                          _buildStockBadge(currentAvailable),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1),
                    ),

                    // Tool Dropdown
                    _buildFieldLabel('Choose Tool *', Icons.inventory_2_rounded),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentSelectedTool,
                          isExpanded: true,
                          hint: const Text(
                            'Select tool from inventory...',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          items: _tools.map((t) {
                            final code = t['toolCode'] ?? '';
                            final name = t['toolName'] ?? '';
                            final id = t['toolId'] ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                '$id - $name ($code)',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              if (isReturn) {
                                _returnSelectedTool = val;
                              } else {
                                _selectedTool = val;
                              }
                            });
                            if (isReturn) {
                              _fetchAvailableCountForReturnSelectedTool(val);
                            } else {
                              _fetchAvailableCountForSelectedTool(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Unified Stepper & Add Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Quantity Units *', Icons.pin_rounded),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                ),
                                child: Row(
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          final cur = int.tryParse(currentCountController.text.trim()) ?? 1;
                                          if (cur > 1) {
                                            currentCountController.text = (cur - 1).toString();
                                            setState(() {
                                              if (isReturn) {
                                                _returnToolCount = cur - 1;
                                              } else {
                                                _toolCount = cur - 1;
                                              }
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.remove_rounded, size: 18, color: primaryColor),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            inputDecorationTheme: const InputDecorationTheme(
                                              filled: false,
                                              fillColor: Colors.transparent,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: currentCountController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val) ?? 1;
                                              setState(() {
                                                if (isReturn) {
                                                  _returnToolCount = parsed;
                                                } else {
                                                  _toolCount = parsed;
                                                }
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              filled: false,
                                              fillColor: Colors.transparent,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          final cur = int.tryParse(currentCountController.text.trim()) ?? 0;
                                          currentCountController.text = (cur + 1).toString();
                                          setState(() {
                                            if (isReturn) {
                                              _returnToolCount = cur + 1;
                                            } else {
                                              _toolCount = cur + 1;
                                            }
                                          });
                                        },
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.add_rounded, size: 18, color: primaryColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _addToolToStaging(isReturn),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Add To List',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: primaryColor.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),

              // ── 3. Staged Tools Summary List ──────────────────────────────
              if (currentAddedTools.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.04),
                        blurRadius: 12,
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
                          Text(
                            'Staged Tools Tray (${currentAddedTools.length})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: darkAccent,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'TOTAL: ${currentAddedTools.fold<int>(0, (accumulator, item) => accumulator + ((item['count'] as int?) ?? 0))} UNITS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentAddedTools.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = currentAddedTools[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.build_rounded, size: 16, color: primaryColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['toolName'] ?? item['toolId'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: darkAccent,
                                        ),
                                      ),
                                      Text(
                                        item['toolCode'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                                  ),
                                  child: Text(
                                    '${item['count']} Units',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded,
                                      color: Colors.redAccent, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      currentAddedTools.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── 4. Main Submit & Reset Buttons ────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => isReturn ? _saveSiteToCompanyReturn() : _saveCompanyToSiteMovement(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                          shadowColor: primaryColor.withValues(alpha: 0.35),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isReturn ? Icons.keyboard_return_rounded : Icons.local_shipping_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isReturn ? 'CONFIRM RETURN TO ORG' : 'DISPATCH TOOLS TO SITE',
                                    style: const TextStyle(
                                      fontSize: 13.5,
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
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _resetForm(isReturn),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'RESET',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 5. How It Works Guide Box ─────────────────────────────────
              _buildHowItWorksBox(
                isReturn: isReturn,
                primaryColor: primaryColor,
                items: isReturn
                    ? const [
                        'Tools are returned from Site back to Company Inventory.',
                        'Site tools inventory count decreases automatically.',
                        'Company available stock count increases automatically.',
                        'Return transaction is recorded in Movement Logs with tracking TR-ID.',
                      ]
                    : const [
                        'Tools are dispatched from Company Inventory to the selected Site.',
                        'Company available stock decreases automatically upon dispatch.',
                        'Site tools inventory count increases automatically.',
                        'Dispatch transaction is recorded in Movement Logs with tracking TM-ID.',
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorksBox({
    required bool isReturn,
    required Color primaryColor,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'How it works:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _buildInfoItem(item)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(int available) {
    Color bg;
    Color text;
    String label;

    if (available == 0) {
      bg = Colors.red.shade50;
      text = Colors.red.shade800;
      label = '0 Available (Out of stock)';
    } else if (available < 5) {
      bg = Colors.amber.shade50;
      text = Colors.amber.shade900;
      label = '$available Available (Low stock)';
    } else {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF047857);
      label = '$available Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: MOVEMENT HISTORY & LOGS TAB
  // ---------------------------------------------------------------------------

  Widget _buildLogsTab(bool isMobile, Color darkAccent) {
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredLogs = _movementLogs.where((log) {
      final id = (log['id'] ?? '').toString().toLowerCase();
      final site = (log['siteId'] ?? '').toString().toLowerCase();
      final proj = (log['projectName'] ?? '').toString().toLowerCase();
      final mgr = (log['manager'] ?? '').toString().toLowerCase();
      final type = (log['type'] ?? '').toString();

      final query = _logSearchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          id.contains(query) ||
          site.contains(query) ||
          proj.contains(query) ||
          mgr.contains(query);

      final matchesType = _selectedLogType == 'All' || type == _selectedLogType;

      return matchesQuery && matchesType;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchMovementLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        child: Column(
          children: [
            // Search & Filter Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _logSearchController,
                    onChanged: (val) => setState(() => _logSearchQuery = val),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search movement ID, site ID, project...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                      suffixIcon: _logSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _logSearchController.clear();
                                setState(() => _logSearchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLogTypeChip('All'),
                      const SizedBox(width: 6),
                      _buildLogTypeChip('Dispatched'),
                      const SizedBox(width: 6),
                      _buildLogTypeChip('Returned'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (filteredLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _logSearchQuery.isEmpty ? 'No Movement Records Yet' : 'No Matching Logs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _logSearchQuery.isEmpty
                          ? 'Tools dispatched to sites or returned to the company will show here'
                          : 'Try adjusting your search or filter keywords',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  final isDispatched = log['type'] == 'Dispatched';
                  final toolsList = log['tools'] as List<dynamic>? ?? [];

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Log Top Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDispatched
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDispatched
                                        ? Icons.arrow_outward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 13,
                                    color: isDispatched ? primaryColor : Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDispatched ? 'DISPATCHED' : 'RETURNED',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDispatched ? primaryColor : Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              log['id'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: darkAccent,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              log['date']?.toString().split(' at ').first ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Site & Project Details
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Site: ${log['siteId']} • Project: ${log['projectName']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              if ((log['supervisor'] ?? '').isNotEmpty || (log['manager'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Mgr: ${log['manager'] ?? 'N/A'} • Sup: ${log['supervisor'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tools items chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: toolsList.map((t) {
                            final code = t['toolCode'] ?? t['toolId'] ?? 'Tool';
                            final count = t['toolCount'] ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '$code × $count',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTypeChip(String label) {
    final isSelected = _selectedLogType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLogType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14.5, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            const SizedBox(width: 12),
            Icon(prefixIcon, size: 17, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 12),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBox(String text, String placeholder, {IconData? prefixIcon}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 17, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text.isNotEmpty ? text : placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
