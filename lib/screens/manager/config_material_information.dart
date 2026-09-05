import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/material_inventory_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaterialInfoScreen extends StatefulWidget {
  const MaterialInfoScreen({super.key});

  @override
  State<MaterialInfoScreen> createState() => _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<MaterialInfoScreen> {
  // Logged-in manager name state
  String _loggedInManagerName = '';

  // Form controllers
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _neededCountController = TextEditingController();

  // Selected values
  String? _selectedSiteId;
  String? _selectedMaterialName;

  // Mode toggle: 0 = CompanyToSite, 1 = SiteToSite, 2 = SiteToCompany
  int _transferMode = 0;

  // Site-to-Site specific state
  String? _fromSiteId;
  String? _toSiteId;
  final TextEditingController _fromManagerController = TextEditingController();
  final TextEditingController _fromSiteNameController = TextEditingController();
  final TextEditingController _fromSupervisorController =
      TextEditingController();
  final TextEditingController _fromProjectNameController =
      TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toManagerController = TextEditingController();
  final TextEditingController _toSiteNameController = TextEditingController();
  final TextEditingController _toSupervisorController = TextEditingController();
  final TextEditingController _toProjectNameController =
      TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Site-to-Company specific state
  final TextEditingController _siteToCompanyManagerController =
      TextEditingController();
  final TextEditingController _siteToCompanySiteNameController =
      TextEditingController();
  final TextEditingController _siteToCompanySupervisorController =
      TextEditingController();
  final TextEditingController _siteToCompanyDateController =
      TextEditingController();

  // Lists for dropdowns
  List<Map<String, dynamic>> sitesList = [];
  List<Map<String, dynamic>> materialsList = [];
  List<Map<String, dynamic>> siteMaterialsList = [];

  // Current available count
  int availableCount = 0;

  // List to store multiple materials for transfer
  List<Map<String, dynamic>> materialsToTransfer = [];

  // Loading and processing states
  bool _isLoadingSites = true;
  bool _isLoadingMaterials = true;
  bool _isProcessing = false;
  bool _isFetchingLiveStock = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _siteToCompanyDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _fetchCurrentManagerName();
    _loadSiteData();
    _loadMaterialData();
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _projectNameController.dispose();
    _supervisorNameController.dispose();
    _dateController.dispose();
    _neededCountController.dispose();

    // Site-to-Site controllers
    _fromManagerController.dispose();
    _fromSiteNameController.dispose();
    _fromSupervisorController.dispose();
    _fromProjectNameController.dispose();
    _fromDateController.dispose();
    _toManagerController.dispose();
    _toSiteNameController.dispose();
    _toSupervisorController.dispose();
    _toProjectNameController.dispose();
    _toDateController.dispose();

    // Site-to-Company controllers
    _siteToCompanyManagerController.dispose();
    _siteToCompanySiteNameController.dispose();
    _siteToCompanySupervisorController.dispose();
    _siteToCompanyDateController.dispose();

    super.dispose();
  }

  Future<void> _fetchCurrentManagerName() async {
    try {
      final auth = AuthService();
      String resolvedName = '';

      if (auth.userRole == UserRole.organization) {
        resolvedName = (auth.userData['org_name'] ??
                auth.userData['username'] ??
                'Organization Administrator')
            .toString()
            .trim();
      } else if (auth.userRole == UserRole.manager) {
        final data = auth.userData;
        resolvedName = (data['FullName'] ??
                data['fullName'] ??
                data['name'] ??
                data['managerName'] ??
                data['UserName'] ??
                data['username'] ??
                '')
            .toString()
            .trim();

        final username = (data['username'] ?? data['UserName'] ?? '')
            .toString()
            .trim();

        if (resolvedName.isEmpty ||
            resolvedName.toLowerCase() == 'manager' ||
            resolvedName == username) {
          if (username.isNotEmpty) {
            try {
              final q = await FirestoreService.getCollection('manager')
                  .where('UserName', isEqualTo: username)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) {
                final docData = q.docs.first.data();
                final name = (docData['FullName'] ??
                        docData['fullName'] ??
                        docData['name'] ??
                        '')
                    .toString()
                    .trim();
                if (name.isNotEmpty) {
                  resolvedName = name;
                }
              }
            } catch (e) {
              debugPrint('Error fetching manager details: $e');
            }

            if (resolvedName.isEmpty ||
                resolvedName.toLowerCase() == 'manager' ||
                resolvedName == username) {
              try {
                final qConfig = await FirestoreService.configUsers
                    .where('UserName', isEqualTo: username)
                    .limit(1)
                    .get();
                if (qConfig.docs.isNotEmpty) {
                  final docData = qConfig.docs.first.data();
                  final name = (docData['FullName'] ??
                          docData['fullName'] ??
                          docData['name'] ??
                          '')
                      .toString()
                      .trim();
                  if (name.isNotEmpty) {
                    resolvedName = name;
                  }
                }
              } catch (e) {
                debugPrint('Error fetching config user details: $e');
              }
            }
          }
        }
      } else if (auth.userRole == UserRole.supervisor) {
        final data = auth.userData;
        resolvedName = (data['supervisorName'] ??
                data['fullName'] ??
                data['FullName'] ??
                data['name'] ??
                data['username'] ??
                '')
            .toString()
            .trim();
      }

      if (resolvedName.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final configUsername = prefs.getString('config_username') ?? '';
        if (configUsername.isNotEmpty) {
          try {
            final q = await FirestoreService.getCollection('manager')
                .where('UserName', isEqualTo: configUsername)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final docData = q.docs.first.data();
              final name = (docData['FullName'] ??
                      docData['fullName'] ??
                      docData['name'] ??
                      '')
                  .toString()
                  .trim();
              if (name.isNotEmpty) resolvedName = name;
            }
          } catch (_) {}
          if (resolvedName.isEmpty) {
            resolvedName = configUsername;
          }
        }
      }

      if (resolvedName.isNotEmpty && mounted) {
        setState(() {
          _loggedInManagerName = resolvedName;
          if (_managerNameController.text.trim().isEmpty) {
            _managerNameController.text = resolvedName;
          }
          if (_fromManagerController.text.trim().isEmpty) {
            _fromManagerController.text = resolvedName;
          }
          if (_siteToCompanyManagerController.text.trim().isEmpty) {
            _siteToCompanyManagerController.text = resolvedName;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching logged in manager name: $e');
    }
  }

  Future<void> _loadSiteData() async {
    try {
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();
      final Map<String, Map<String, dynamic>> siteDetails = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()
      };

      final mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap').get();
      final Map<String, Map<String, dynamic>> supervisorMap = {};
      for (var doc in mapSnapshot.docs) {
        final data = doc.data();
        final siteField = data['site']?.toString().trim();
        if (siteField != null && siteField.isNotEmpty) {
          supervisorMap[siteField] = data;
        }
      }

      if (mounted) {
        setState(() {
          sitesList = siteDetails.entries.map<Map<String, dynamic>>((entry) {
            final sId = entry.key;
            final sData = entry.value;
            final siteName = sData['siteName']?.toString() ?? sId;
            final mapping = supervisorMap[sId] ?? supervisorMap[siteName];

            return <String, dynamic>{
              'siteId': sId,
              'siteName': siteName,
              'projectName': mapping?['projectName'] ?? sData['projectName'] ?? '',
              'supervisorName': mapping?['supervisorName'] ?? sData['supervisorName'] ?? '',
            };
          }).toList();
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSites = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading site data: $e')),
        );
      }
    }
  }

  int _parseCount(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _loadMaterialData() async {
    try {
      final items = await MaterialInventoryService.fetchAllMaterialsInventory();
      final Map<String, Map<String, dynamic>> mapByDocOrName = {};
      for (final item in items) {
        final key = item.materialName.trim();
        if (key.isEmpty) continue;
        if (!mapByDocOrName.containsKey(key)) {
          mapByDocOrName[key] = {
            'materialId': item.docId,
            'materialName': key,
            'displayName': key,
            'unit': item.unit,
            'count': item.companyAvailableCount,
          };
        }
      }

      final list = mapByDocOrName.values.toList();
      list.sort(
        (a, b) => (a['materialName'] as String).toLowerCase().compareTo(
              (b['materialName'] as String).toLowerCase(),
            ),
      );

      if (mounted) {
        setState(() {
          materialsList = list;
          _isLoadingMaterials = false;
          if (_selectedMaterialName != null) {
            final match = list.firstWhere(
              (m) =>
                  (m['materialName'] ?? '').toString().trim().toLowerCase() ==
                  _selectedMaterialName!.trim().toLowerCase(),
              orElse: () => <String, dynamic>{'count': 0},
            );
            availableCount = _parseCount(match['count']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading material data: $e')),
        );
      }
    }
  }

  Future<void> _loadSiteMaterialData(String siteId) async {
    try {
      final items = await MaterialInventoryService.fetchAllMaterialsInventory();
      final Map<String, Map<String, dynamic>> mapByDocOrName = {};
      for (final item in items) {
        final key = item.materialName.trim();
        if (key.isEmpty) continue;
        final siteEntry = item.siteInventories.firstWhere(
          (s) => s.siteId.trim().toLowerCase() == siteId.trim().toLowerCase(),
          orElse: () => SiteInventoryEntry(siteId: siteId, availableCount: 0),
        );
        if (!mapByDocOrName.containsKey(key)) {
          mapByDocOrName[key] = {
            'materialId': item.docId,
            'materialName': key,
            'displayName': key,
            'unit': item.unit,
            'count': siteEntry.availableCount,
          };
        }
      }

      final list = mapByDocOrName.values.toList();
      list.sort(
        (a, b) => (a['materialName'] as String).toLowerCase().compareTo(
              (b['materialName'] as String).toLowerCase(),
            ),
      );

      if (mounted) {
        setState(() {
          siteMaterialsList = list;
          _isLoadingMaterials = false;
          if (_selectedMaterialName != null) {
            final match = list.firstWhere(
              (m) =>
                  (m['materialName'] ?? '').toString().trim().toLowerCase() ==
                  _selectedMaterialName!.trim().toLowerCase(),
              orElse: () => <String, dynamic>{'count': 0},
            );
            availableCount = _parseCount(match['count']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading site material data: $e')),
        );
      }
    }
  }

  Future<void> _fetchAndFillSiteDetails(
    String siteId, {
    required int mode,
    bool isFromSite = true,
  }) async {
    final site = sitesList.firstWhere(
      (s) => s['siteId'] == siteId,
      orElse: () => {},
    );

    if (site.isEmpty) return;

    if (mode == 0) {
      _projectNameController.text = site['projectName'] ?? '';
      _supervisorNameController.text = site['supervisorName'] ?? '';
    } else if (mode == 1) {
      if (isFromSite) {
        _fromSiteNameController.text = site['siteName'] ?? '';
        _fromProjectNameController.text = site['projectName'] ?? '';
        _fromSupervisorController.text = site['supervisorName'] ?? '';
      } else {
        _toSiteNameController.text = site['siteName'] ?? '';
        _toProjectNameController.text = site['projectName'] ?? '';
        _toSupervisorController.text = site['supervisorName'] ?? '';
      }
    } else if (mode == 2) {
      _siteToCompanySiteNameController.text = site['siteName'] ?? '';
      _projectNameController.text = site['projectName'] ?? '';
      _siteToCompanySupervisorController.text = site['supervisorName'] ?? '';
    }
  }

  void _onMaterialChanged(String? materialName) async {
    if (materialName == null || materialName.trim().isEmpty) {
      setState(() {
        _selectedMaterialName = null;
        availableCount = 0;
        _isFetchingLiveStock = false;
      });
      return;
    }

    final trimmed = materialName.trim();
    final list = _transferMode == 0 ? materialsList : siteMaterialsList;

    final match = list.firstWhere(
      (m) =>
          (m['materialName'] ?? '').toString().trim().toLowerCase() ==
              trimmed.toLowerCase() ||
          (m['displayName'] ?? '').toString().trim().toLowerCase() ==
              trimmed.toLowerCase(),
      orElse: () => <String, dynamic>{'count': 0},
    );

    final initialCount = _parseCount(match['count']);

    setState(() {
      _selectedMaterialName = trimmed;
      availableCount = initialCount;
      _isFetchingLiveStock = true;
    });

    try {
      final freshItem =
          await MaterialInventoryService.fetchMaterialInventory(trimmed);
      if (freshItem != null && mounted && _selectedMaterialName == trimmed) {
        int backendCount = 0;
        if (_transferMode == 0) {
          backendCount = freshItem.companyAvailableCount;
        } else if (_transferMode == 1) {
          if (_fromSiteId != null && _fromSiteId!.isNotEmpty) {
            final sEntry = freshItem.siteInventories.firstWhere(
              (s) =>
                  s.siteId.trim().toLowerCase() ==
                  _fromSiteId!.trim().toLowerCase(),
              orElse: () => SiteInventoryEntry(
                siteId: _fromSiteId!,
                availableCount: 0,
              ),
            );
            backendCount = sEntry.availableCount;
          }
        } else if (_transferMode == 2) {
          if (_selectedSiteId != null && _selectedSiteId!.isNotEmpty) {
            final sEntry = freshItem.siteInventories.firstWhere(
              (s) =>
                  s.siteId.trim().toLowerCase() ==
                  _selectedSiteId!.trim().toLowerCase(),
              orElse: () => SiteInventoryEntry(
                siteId: _selectedSiteId!,
                availableCount: 0,
              ),
            );
            backendCount = sEntry.availableCount;
          }
        }

        setState(() {
          availableCount = backendCount;
          _isFetchingLiveStock = false;
        });
      } else if (mounted) {
        setState(() {
          _isFetchingLiveStock = false;
        });
      }
    } catch (e) {
      debugPrint('Error syncing live stock for $trimmed: $e');
      if (mounted) {
        setState(() {
          _isFetchingLiveStock = false;
        });
      }
    }
  }

  void _addMaterial() {
    if (_selectedMaterialName == null || _selectedMaterialName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a material first'),
          backgroundColor: Color(0xFF0A183D),
        ),
      );
      return;
    }

    final neededCountStr = _neededCountController.text.trim();
    if (neededCountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter transfer count'),
          backgroundColor: Color(0xFF0A183D),
        ),
      );
      return;
    }

    final neededCount = int.tryParse(neededCountStr);
    if (neededCount == null || neededCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive transfer quantity'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (availableCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected material has 0 available units in inventory'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final list = _transferMode == 0 ? materialsList : siteMaterialsList;
    final material = list.firstWhere(
      (m) =>
          (m['materialName'] ?? '').toString().trim().toLowerCase() ==
          _selectedMaterialName!.trim().toLowerCase(),
      orElse: () => <String, dynamic>{
        'materialId': _selectedMaterialName!,
        'materialName': _selectedMaterialName!,
        'displayName': _selectedMaterialName!,
        'unit': 'Units',
      },
    );

    final alreadyAddedCount = materialsToTransfer
        .where(
          (m) =>
              (m['materialName'] ?? '').toString().trim().toLowerCase() ==
              _selectedMaterialName!.trim().toLowerCase(),
        )
        .fold<int>(0, (acc, m) => acc + (m['neededCount'] as int));

    final availableRemaining = availableCount - alreadyAddedCount;

    if (neededCount > availableRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyAddedCount > 0
                ? 'Needed count ($neededCount) exceeds remaining available ($availableRemaining). Already added: $alreadyAddedCount, Total available: $availableCount.'
                : 'Needed count ($neededCount) cannot exceed available count ($availableCount).',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final existingIndex = materialsToTransfer.indexWhere(
      (m) =>
          (m['materialName'] ?? '').toString().trim().toLowerCase() ==
          _selectedMaterialName!.trim().toLowerCase(),
    );

    if (existingIndex >= 0) {
      final currentNeeded =
          materialsToTransfer[existingIndex]['neededCount'] as int;
      setState(() {
        materialsToTransfer[existingIndex]['neededCount'] =
            currentNeeded + neededCount;
        materialsToTransfer[existingIndex]['availableCount'] = availableCount;
      });
    } else {
      setState(() {
        materialsToTransfer.add({
          'materialId': material['materialId'] ?? _selectedMaterialName!,
          'materialName': material['materialName'] ?? _selectedMaterialName!,
          'displayName': material['displayName'] ??
              material['materialName'] ??
              _selectedMaterialName!,
          'unit': material['unit'] ?? 'Units',
          'neededCount': neededCount,
          'availableCount': availableCount,
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${material['displayName'] ?? _selectedMaterialName} ($neededCount) to transfer list',
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );

    _clearMaterial();
  }

  void _removeMaterial(int index) {
    setState(() {
      materialsToTransfer.removeAt(index);
    });
  }

  void _clearMaterial() {
    setState(() {
      _selectedMaterialName = null;
      availableCount = 0;
      _isFetchingLiveStock = false;
      _neededCountController.clear();
    });
  }

  void _clearAll() {
    setState(() {
      _managerNameController.text = _loggedInManagerName;
      _projectNameController.clear();
      _supervisorNameController.clear();
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedSiteId = null;
      _clearMaterial();
      materialsToTransfer.clear();

      _fromSiteId = null;
      _toSiteId = null;
      _fromManagerController.text = _loggedInManagerName;
      _fromSiteNameController.clear();
      _fromSupervisorController.clear();
      _fromProjectNameController.clear();
      _fromDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());

      _toManagerController.clear();
      _toSiteNameController.clear();
      _toSupervisorController.clear();
      _toProjectNameController.clear();
      _toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

      _siteToCompanyManagerController.text = _loggedInManagerName;
      _siteToCompanySiteNameController.clear();
      _siteToCompanySupervisorController.clear();
      _siteToCompanyDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  bool _validateCompanyToSiteForm() {
    if (_managerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter manager name')),
      );
      return false;
    }
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site')));
      return false;
    }
    if (materialsToTransfer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one material')),
      );
      return false;
    }
    return true;
  }

  bool _validateSiteToSiteForm() {
    if (_fromManagerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter "From Site" manager name')),
      );
      return false;
    }
    if (_fromSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select "From Site"')),
      );
      return false;
    }
    if (_toManagerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter "To Site" manager name')),
      );
      return false;
    }
    if (_toSiteId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select "To Site"')));
      return false;
    }
    if (_fromSiteId == _toSiteId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('"From Site" and "To Site" cannot be the same'),
        ),
      );
      return false;
    }
    if (materialsToTransfer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one material')),
      );
      return false;
    }
    return true;
  }

  bool _validateSiteToCompanyForm() {
    if (_siteToCompanyManagerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter manager name')),
      );
      return false;
    }
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site')));
      return false;
    }
    if (materialsToTransfer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one material')),
      );
      return false;
    }
    return true;
  }

  Future<void> _saveCompanyToSiteTransfer() async {
    if (!_validateCompanyToSiteForm() || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final siteObj = sitesList.firstWhere(
        (s) => s['siteId'] == _selectedSiteId,
        orElse: () => <String, dynamic>{},
      );
      final resolvedSiteName = (siteObj['siteName'] ?? _selectedSiteId!).toString().trim();

      for (var material in materialsToTransfer) {
        final materialName = material['materialName'] as String;
        final neededCount = material['neededCount'] as int;

        await MaterialInventoryService.transferCompanyToSite(
          materialName: materialName,
          siteId: _selectedSiteId!,
          quantity: neededCount,
          siteName: resolvedSiteName,
          managerName: _managerNameController.text.trim(),
          supervisorName: _supervisorNameController.text.trim(),
          projectName: _projectNameController.text.trim(),
          displayName: material['displayName'],
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Materials transferred to site successfully!',
        );
        _clearAll();
        await _loadMaterialData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring materials: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _saveSiteToSiteTransfer() async {
    if (!_validateSiteToSiteForm() || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      for (var material in materialsToTransfer) {
        final materialName = material['materialName'] as String;
        final neededCount = material['neededCount'] as int;

        await MaterialInventoryService.transferSiteToSite(
          materialName: materialName,
          fromSiteId: _fromSiteId!,
          toSiteId: _toSiteId!,
          quantity: neededCount,
          fromSiteName: _fromSiteNameController.text.trim(),
          toSiteName: _toSiteNameController.text.trim(),
          fromManagerName: _fromManagerController.text.trim(),
          toManagerName: _toManagerController.text.trim(),
          fromSupervisorName: _fromSupervisorController.text.trim(),
          toSupervisorName: _toSupervisorController.text.trim(),
          fromProjectName: _fromProjectNameController.text.trim(),
          toProjectName: _toProjectNameController.text.trim(),
          displayName: material['displayName'],
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Site-to-Site transfer completed successfully!',
        );
        _clearAll();
        if (_fromSiteId != null) {
          await _loadSiteMaterialData(_fromSiteId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error performing transfer: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _saveSiteToCompanyTransfer() async {
    if (!_validateSiteToCompanyForm() || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final siteObj = sitesList.firstWhere(
        (s) => s['siteId'] == _selectedSiteId,
        orElse: () => <String, dynamic>{},
      );
      final siteNameFromCtrl = _siteToCompanySiteNameController.text.trim();
      final resolvedSiteName = (siteObj['siteName'] != null &&
              siteObj['siteName'].toString().trim().isNotEmpty)
          ? siteObj['siteName'].toString().trim()
          : (siteNameFromCtrl.isNotEmpty ? siteNameFromCtrl : _selectedSiteId!);

      for (var material in materialsToTransfer) {
        final materialName = material['materialName'] as String;
        final neededCount = material['neededCount'] as int;

        await MaterialInventoryService.transferSiteToCompany(
          materialName: materialName,
          siteId: _selectedSiteId!,
          quantity: neededCount,
          siteName: resolvedSiteName,
          managerName: _siteToCompanyManagerController.text.trim(),
          supervisorName: _siteToCompanySupervisorController.text.trim(),
          projectName: _projectNameController.text.trim(),
          displayName: material['displayName'],
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Site-to-Company return completed successfully!',
        );
        _clearAll();
        if (_selectedSiteId != null) {
          await _loadSiteMaterialData(_selectedSiteId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error performing return: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final String pageTitle = _transferMode == 0
        ? 'Company To Site Transfer'
        : _transferMode == 1
            ? 'Site To Site Transfer'
            : 'Site To Company Transfer';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          pageTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        child: Column(
          children: [
            // ── Pill Mode Switcher (CTS / STS / STC) ───────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTabOption(0, 'CTS', primaryColor),
                  _buildTabOption(1, 'STS', primaryColor),
                  _buildTabOption(2, 'STC', primaryColor),
                ],
              ),
            ),

            // ── Main Scrollable Body ────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_transferMode == 0) ...[
                          // ── CTS: Company To Site UI ──────────────────────
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Basic Information'),
                                const SizedBox(height: 18),
                                _buildTextField(
                                  controller: _managerNameController,
                                  label: 'Manager Name *',
                                  hint: 'Enter manager name',
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildSiteDropdown(),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _projectNameController,
                                  label: 'Project Name',
                                  hint: 'Auto-filled project name',
                                  enabled: false,
                                  icon: Icons.business_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _supervisorNameController,
                                  label: 'Supervisor Name',
                                  hint: 'Auto-filled supervisor name',
                                  enabled: false,
                                  icon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _dateController,
                                  label: 'Date *',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today_rounded,
                                  onTap: () => _selectDate(context, _dateController),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        _isFetchingLiveStock
                                            ? 'Syncing...'
                                            : '$availableCount',
                                        const Color(0xFF10B981),
                                        Icons.check_circle_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _neededCountController,
                                        label: 'Transfer Count *',
                                        hint: 'Enter count',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        icon: Icons.numbers_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildAddClearMaterialButtons(primaryColor),
                                if (materialsToTransfer.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildMaterialsList(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Transfer to Site',
                                  isProcessing: _isProcessing,
                                  onPressed: () {
                                    if (_validateCompanyToSiteForm()) {
                                      _saveCompanyToSiteTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 18),
                                _buildHowItWorksBox(
                                  primaryColor: primaryColor,
                                  items: const [
                                    'Materials are transferred from Company Inventory to Site',
                                    'Company available count decreases automatically',
                                    'Site material count increases automatically',
                                    'Transfer history is saved with "CompanyToSite" info',
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else if (_transferMode == 1) ...[
                          // ── STS: Site To Site UI ─────────────────────────
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('From Site (Source)'),
                                const SizedBox(height: 18),
                                _buildSiteDropdownGeneric(
                                  selectedId: _fromSiteId,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _fromSiteId = v;
                                        _selectedMaterialName = null;
                                        availableCount = 0;
                                      });
                                      _fetchAndFillSiteDetails(v, mode: 1, isFromSite: true);
                                      _loadSiteMaterialData(v);
                                    }
                                  },
                                  label: 'From Site *',
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fromSiteNameController,
                                  label: 'From Site Name',
                                  hint: 'Auto-filled site name',
                                  enabled: false,
                                  icon: Icons.location_city_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fromManagerController,
                                  label: 'From Manager Name',
                                  hint: 'Enter manager name',
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fromSupervisorController,
                                  label: 'From Supervisor Name',
                                  hint: 'Auto-filled supervisor name',
                                  enabled: false,
                                  icon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fromProjectNameController,
                                  label: 'From Project Name',
                                  hint: 'Auto-filled project name',
                                  enabled: false,
                                  icon: Icons.business_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fromDateController,
                                  label: 'From Date *',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today_rounded,
                                  onTap: () => _selectDate(context, _fromDateController),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('To Site (Destination)'),
                                const SizedBox(height: 18),
                                _buildSiteDropdownGeneric(
                                  selectedId: _toSiteId,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _toSiteId = v;
                                      });
                                      _fetchAndFillSiteDetails(v, mode: 1, isFromSite: false);
                                    }
                                  },
                                  label: 'To Site *',
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _toSiteNameController,
                                  label: 'To Site Name',
                                  hint: 'Auto-filled site name',
                                  enabled: false,
                                  icon: Icons.location_city_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _toManagerController,
                                  label: 'To Manager Name',
                                  hint: 'Enter manager name',
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _toSupervisorController,
                                  label: 'To Supervisor Name',
                                  hint: 'Auto-filled supervisor name',
                                  enabled: false,
                                  icon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _toProjectNameController,
                                  label: 'To Project Name',
                                  hint: 'Auto-filled project name',
                                  enabled: false,
                                  icon: Icons.business_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _toDateController,
                                  label: 'To Date *',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today_rounded,
                                  onTap: () => _selectDate(context, _toDateController),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        _isFetchingLiveStock
                                            ? 'Syncing...'
                                            : '$availableCount',
                                        const Color(0xFF10B981),
                                        Icons.check_circle_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _neededCountController,
                                        label: 'Transfer Count *',
                                        hint: 'Enter count',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        icon: Icons.numbers_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildAddClearMaterialButtons(primaryColor),
                                if (materialsToTransfer.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildMaterialsList(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Transfer Site to Site',
                                  isProcessing: _isProcessing,
                                  onPressed: () {
                                    if (_validateSiteToSiteForm()) {
                                      _saveSiteToSiteTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 18),
                                _buildHowItWorksBox(
                                  primaryColor: primaryColor,
                                  items: const [
                                    'Materials are transferred directly between two construction sites',
                                    'Source Site material count decreases automatically',
                                    'Destination Site material count increases automatically',
                                    'Transfer history is saved with "SiteToSite" info',
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // ── STC: Site To Company UI ──────────────────────
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Basic Information'),
                                const SizedBox(height: 18),
                                _buildSiteDropdownGeneric(
                                  selectedId: _selectedSiteId,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedSiteId = v;
                                        _selectedMaterialName = null;
                                        availableCount = 0;
                                      });
                                      _fetchAndFillSiteDetails(v, mode: 2);
                                      _loadSiteMaterialData(v);
                                    }
                                  },
                                  label: 'From Site *',
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _siteToCompanySiteNameController,
                                  label: 'Site Name',
                                  hint: 'Auto-filled site name',
                                  enabled: false,
                                  icon: Icons.location_city_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _siteToCompanyManagerController,
                                  label: 'Manager Name',
                                  hint: 'Enter manager name',
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _siteToCompanySupervisorController,
                                  label: 'Supervisor Name',
                                  hint: 'Auto-filled supervisor name',
                                  enabled: false,
                                  icon: Icons.badge_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _siteToCompanyDateController,
                                  label: 'Date *',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today_rounded,
                                  onTap: () => _selectDate(context, _siteToCompanyDateController),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        _isFetchingLiveStock
                                            ? 'Syncing...'
                                            : '$availableCount',
                                        const Color(0xFF10B981),
                                        Icons.check_circle_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _neededCountController,
                                        label: 'Transfer Count *',
                                        hint: 'Enter count',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        icon: Icons.numbers_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildAddClearMaterialButtons(primaryColor),
                                if (materialsToTransfer.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildMaterialsList(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Return to Company',
                                  isProcessing: _isProcessing,
                                  onPressed: () {
                                    if (_validateSiteToCompanyForm()) {
                                      _saveSiteToCompanyTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 18),
                                _buildHowItWorksBox(
                                  primaryColor: primaryColor,
                                  items: const [
                                    'Materials are returned from site to company',
                                    'Company inventory increases automatically',
                                    'Site inventory decreases automatically',
                                    'Transfer history is saved with "SiteToCompany" info',
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────

  Widget _buildTabOption(int modeIndex, String label, Color primaryColor) {
    final isSelected = _transferMode == modeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _transferMode = modeIndex;
            _selectedMaterialName = null;
            availableCount = 0;
            _isFetchingLiveStock = false;
            _neededCountController.clear();
            materialsToTransfer.clear();
            if (_loggedInManagerName.isNotEmpty) {
              if (_managerNameController.text.trim().isEmpty) {
                _managerNameController.text = _loggedInManagerName;
              }
              if (_fromManagerController.text.trim().isEmpty) {
                _fromManagerController.text = _loggedInManagerName;
              }
              if (_siteToCompanyManagerController.text.trim().isEmpty) {
                _siteToCompanyManagerController.text = _loggedInManagerName;
              }
            }
          });
          if (modeIndex == 0) {
            _loadMaterialData();
          } else if (modeIndex == 1 && _fromSiteId != null) {
            _loadSiteMaterialData(_fromSiteId!);
          } else if (modeIndex == 2 && _selectedSiteId != null) {
            _loadSiteMaterialData(_selectedSiteId!);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isSelected ? Colors.white : const Color(0xFF0A183D),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0A183D),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onTap: onTap,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 20),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSiteDropdownGeneric({
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);
    final hasSelected = sitesList.any((s) => s['siteId'] == selectedId);
    final currentVal = hasSelected ? selectedId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: _isLoadingSites
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading sites...',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey('site_${currentVal}_${sitesList.length}'),
                  initialValue: currentVal,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Select Site',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: brandIconColor,
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: sitesList.map((site) {
                    return DropdownMenuItem<String>(
                      value: site['siteId'],
                      child: Text(
                        site['siteName'] ?? site['siteId'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
        ),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    return _buildSiteDropdownGeneric(
      selectedId: _selectedSiteId,
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _selectedSiteId = v;
          });
          _fetchAndFillSiteDetails(v, mode: 0);
        }
      },
      label: 'Site *',
    );
  }

  Widget _buildMaterialDropdown() {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);
    final validList = _transferMode == 0 ? materialsList : siteMaterialsList;
    final hasSelected = validList.any(
      (m) =>
          (m['materialName'] ?? '').toString().trim().toLowerCase() ==
          (_selectedMaterialName ?? '').trim().toLowerCase(),
    );
    final currentSelectedValue = hasSelected ? _selectedMaterialName : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Material Name *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: _isLoadingMaterials
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading materials...',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey('mat_${currentSelectedValue}_${validList.length}'),
                  initialValue: currentSelectedValue,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: validList.isEmpty
                        ? (_transferMode != 0 && (_fromSiteId == null && _selectedSiteId == null)
                            ? 'Select site first'
                            : 'No materials available')
                        : 'Select Material',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: brandIconColor,
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: validList.map((material) {
                    final materialName =
                        (material['materialName'] ?? '').toString().trim();
                    final count = _parseCount(material['count']);

                    return DropdownMenuItem<String>(
                      value: materialName,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              materialName,
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (count > 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Available: $count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: count > 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onMaterialChanged,
                ),
        ),
      ],
    );
  }

  Widget _buildCountBox(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddClearMaterialButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _addMaterial,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Add Material',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _clearMaterial,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A183D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF0A183D),
              ),
              label: const Text(
                'Clear Material',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Materials to Transfer:',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0A183D),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${materialsToTransfer.length} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            children: materialsToTransfer.asMap().entries.map((entry) {
              final index = entry.key;
              final material = entry.value;
              final isLast = index == materialsToTransfer.length - 1;
              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      material['displayName'] ?? material['materialName'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A183D),
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Quantity: ${material['neededCount']} ${material['unit'] ?? 'units'} (Available: ${material['availableCount']})',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444)),
                      tooltip: 'Remove material',
                      onPressed: () => _removeMaterial(index),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      color: Color(0xFFE2E8F0),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferActionsButton({
    required Color primaryColor,
    required String actionText,
    required VoidCallback onPressed,
    bool isProcessing = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isProcessing ? null : _clearAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A183D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                elevation: 0,
              ),
              child: const Text(
                'CLEAR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actionText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksBox({
    required Color primaryColor,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
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
                  fontSize: 13,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildInfoItem(item)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
