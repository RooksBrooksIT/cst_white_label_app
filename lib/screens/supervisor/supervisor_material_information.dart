import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/firestore_service.dart';
import '/services/auth_service.dart';
import '/services/material_inventory_service.dart';
import '/utils/app_theme.dart';

class SupervisorMaterialInfoScreen extends StatefulWidget {
  const SupervisorMaterialInfoScreen({super.key});

  @override
  State<SupervisorMaterialInfoScreen> createState() =>
      _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<SupervisorMaterialInfoScreen> {
  // Logged-in manager name state
  String _loggedInManagerName = '';

  // Selected values
  String? _selectedSiteId;
  String? _selectedMaterialName;

  // Mode toggle: 0 = SiteToSite, 1 = SiteToCompany
  int _transferMode = 0;

  // Site-to-Site specific state
  String? _fromSiteId;
  String? _toSiteId;
  final TextEditingController _fromManagerController = TextEditingController();
  final TextEditingController _fromSiteNameController = TextEditingController();
  final TextEditingController _fromSupervisorController =
      TextEditingController();
  final TextEditingController _fromProjectNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toManagerController = TextEditingController();
  final TextEditingController _toSiteNameController = TextEditingController();
  final TextEditingController _toSupervisorController = TextEditingController();
  final TextEditingController _toProjectNameController = TextEditingController();
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
  final TextEditingController _projectNameController = TextEditingController();

  // Common controllers
  final TextEditingController _neededCountController = TextEditingController();

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
    _projectNameController.dispose();

    // Common controllers
    _neededCountController.dispose();

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

  // Load site data from siteSupervisorMap collection
  Future<void> _loadSiteData() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).get();

      if (mounted) {
        final List<Map<String, dynamic>> parsedSites = [];
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final loc = (data['location'] ?? '').toString().trim();
          final s = (data['site'] ?? '').toString().trim();
          final sId = (data['siteId'] ?? '').toString().trim();
          
          String resolvedSiteId = s.isNotEmpty && s != loc
              ? s
              : (sId.isNotEmpty && sId != loc ? sId : doc.id.trim());
          if (resolvedSiteId.isEmpty) resolvedSiteId = doc.id.trim();

          parsedSites.add({
            'siteId': resolvedSiteId,
            'siteName': resolvedSiteId, // Ensure clean Site ID (e.g. ST001_shek) is used, never address!
            'projectName': data['projectName'] ?? '',
            'supervisorName':
                data['supervisor'] ?? data['supervisorName'] ?? '',
          });
        }

        setState(() {
          sitesList = parsedSites;
          _isLoadingSites = false;

          // If supervisor has assigned site, auto-select it if nothing selected yet
          if (_selectedSiteId == null && parsedSites.isNotEmpty) {
            final auth = AuthService();
            if (auth.userRole == UserRole.supervisor) {
              final supName = (auth.userData['supervisorName'] ??
                      auth.userData['fullName'] ??
                      auth.userData['name'] ??
                      '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final mySite = parsedSites.firstWhere(
                (s) =>
                    (s['supervisorName'] ?? '').toString().trim().toLowerCase() == supName,
                orElse: () => parsedSites.first,
              );
              _selectedSiteId = mySite['siteId']?.toString();
              _fromSiteId = mySite['siteId']?.toString();
              _siteToCompanySiteNameController.text = mySite['siteName']?.toString() ?? '';
              _siteToCompanySupervisorController.text = mySite['supervisorName']?.toString() ?? '';
              _projectNameController.text = mySite['projectName']?.toString() ?? '';
              _fromSiteNameController.text = mySite['siteName']?.toString() ?? '';
              _fromSupervisorController.text = mySite['supervisorName']?.toString() ?? '';
              _fromProjectNameController.text = mySite['projectName']?.toString() ?? '';
            }
          }
        });

        if (_selectedSiteId != null) {
          await _loadSiteMaterialData(_selectedSiteId);
        }
      }
    } catch (e) {
      debugPrint('Error loading site data: $e');
      if (mounted) {
        setState(() {
          _isLoadingSites = false;
        });
        _showSnackBar('Error loading site data');
      }
    }
  }

  // Utility: safely parse count as int from num or string
  int _parseCount(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // Load material data using unified MaterialInventoryService
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
            'displayName': item.displayName.isNotEmpty ? item.displayName : key,
            'unit': item.unit,
            'count': item.companyAvailableCount,
          };
        }
      }

      final list = mapByDocOrName.values.toList();
      list.sort(
        (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
              (b['displayName'] as String).toLowerCase(),
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
      debugPrint('Error loading material data: $e');
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
        _showSnackBar('Error loading material data');
      }
    }
  }

  // Load material data for a specific site from unified MaterialInventoryService
  Future<void> _loadSiteMaterialData(String? siteId) async {
    if (siteId == null || siteId.isEmpty) {
      if (mounted) {
        setState(() {
          siteMaterialsList = [];
          _isLoadingMaterials = false;
        });
      }
      return;
    }

    try {
      final items = await MaterialInventoryService.fetchAllMaterialsInventory();
      final Map<String, Map<String, dynamic>> mapByDocOrName = {};
      for (final item in items) {
        final key = item.materialName.trim();
        if (key.isEmpty) continue;
        final cleanLow = siteId.trim().toLowerCase();
        final siteEntry = item.siteInventories.firstWhere(
          (s) {
            final sIdLow = s.siteId.trim().toLowerCase();
            final sNameLow = s.siteName.trim().toLowerCase();
            return sIdLow == cleanLow ||
                (sNameLow.isNotEmpty && sNameLow == cleanLow) ||
                (cleanLow.contains('_') && sIdLow.isNotEmpty && (cleanLow.startsWith('$sIdLow' '_') || cleanLow.endsWith('_$sIdLow'))) ||
                (cleanLow.contains('_') && sNameLow.isNotEmpty && (cleanLow.startsWith('$sNameLow' '_') || cleanLow.endsWith('_$sNameLow'))) ||
                (sIdLow.contains('_') && cleanLow.isNotEmpty && (sIdLow.startsWith('$cleanLow' '_') || sIdLow.endsWith('_$cleanLow')));
          },
          orElse: () => SiteInventoryEntry(siteId: siteId, availableCount: 0),
        );
        if (!mapByDocOrName.containsKey(key)) {
          mapByDocOrName[key] = {
            'materialId': item.docId,
            'materialName': key,
            'displayName': item.displayName.isNotEmpty ? item.displayName : key,
            'unit': item.unit,
            'count': siteEntry.availableCount,
          };
        }
      }

      final list = mapByDocOrName.values.toList();
      list.sort(
        (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
              (b['displayName'] as String).toLowerCase(),
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
          siteMaterialsList = [];
          _isLoadingMaterials = false;
        });
      }
      _showSnackBar('Error loading site materials');
    }
  }

  // Handle material selection change with instant in-memory lookup and live background sync
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
    final list = siteMaterialsList.isNotEmpty ? siteMaterialsList : materialsList;

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
        final targetSiteId = _transferMode == 0 ? _fromSiteId : _selectedSiteId;
        if (targetSiteId != null && targetSiteId.isNotEmpty) {
          final sEntry = freshItem.siteInventories.firstWhere(
            (s) =>
                s.siteId.trim().toLowerCase() ==
                targetSiteId.trim().toLowerCase(),
            orElse: () => SiteInventoryEntry(
              siteId: targetSiteId,
              availableCount: 0,
            ),
          );
          backendCount = sEntry.availableCount;
        } else {
          backendCount = freshItem.companyAvailableCount;
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

  // Add material to transfer list with cumulative quantity validation
  void _addMaterial() {
    if (_selectedMaterialName == null || _selectedMaterialName!.trim().isEmpty) {
      _showSnackBar('Please select a material first');
      return;
    }

    final neededCountStr = _neededCountController.text.trim();
    if (neededCountStr.isEmpty) {
      _showSnackBar('Please enter needed count');
      return;
    }

    final neededCount = int.tryParse(neededCountStr);
    if (neededCount == null || neededCount <= 0) {
      _showSnackBar('Please enter a valid positive needed count');
      return;
    }

    if (availableCount <= 0) {
      _showSnackBar('Selected material has 0 available units in inventory');
      return;
    }

    final list = siteMaterialsList.isNotEmpty ? siteMaterialsList : materialsList;
    final selectedMaterial = list.firstWhere(
      (m) =>
          (m['materialName'] ?? '').toString().trim().toLowerCase() ==
          _selectedMaterialName!.trim().toLowerCase(),
      orElse: () => <String, dynamic>{
        'materialName': _selectedMaterialName!,
        'displayName': _selectedMaterialName!,
      },
    );

    final displayName =
        (selectedMaterial['displayName'] ?? _selectedMaterialName!).toString();

    final alreadyAddedCount = materialsToTransfer
        .where(
          (m) =>
              (m['materialName'] ?? '').toString().trim().toLowerCase() ==
              _selectedMaterialName!.trim().toLowerCase(),
        )
        .fold<int>(0, (acc, m) => acc + (m['neededCount'] as int));

    final availableRemaining = availableCount - alreadyAddedCount;

    if (neededCount > availableRemaining) {
      _showSnackBar(
        alreadyAddedCount > 0
            ? 'Needed count ($neededCount) exceeds remaining available ($availableRemaining). Already added: $alreadyAddedCount, Total available: $availableCount.'
            : 'Needed count ($neededCount) cannot exceed available count ($availableCount).',
      );
      return;
    }

    final existingIndex = materialsToTransfer.indexWhere(
      (item) =>
          (item['materialName'] ?? '').toString().trim().toLowerCase() ==
          _selectedMaterialName!.trim().toLowerCase(),
    );

    if (existingIndex != -1) {
      setState(() {
        materialsToTransfer[existingIndex]['neededCount'] =
            (materialsToTransfer[existingIndex]['neededCount'] as int) + neededCount;
        materialsToTransfer[existingIndex]['availableCount'] = availableCount;
      });
      _showSnackBar('Material quantity updated in transfer list');
    } else {
      setState(() {
        materialsToTransfer.add({
          'materialName': _selectedMaterialName!,
          'displayName': displayName,
          'neededCount': neededCount,
          'availableCount': availableCount,
        });
      });
      _showSnackBar('Material added to transfer list');
    }

    // Clear material selection
    _clearMaterial();
  }

  // Remove material from transfer list
  void _removeMaterial(int index) {
    setState(() {
      materialsToTransfer.removeAt(index);
    });
    _showSnackBar('Material removed from list');
  }

  // Clear only material fields
  void _clearMaterial() {
    setState(() {
      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
    });
  }

  // Clear SiteToSite fields
  void _clearSiteToSiteFields() {
    setState(() {
      _fromManagerController.text = _loggedInManagerName;
      _toManagerController.clear();
      _fromSiteId = null;
      _toSiteId = null;
      _fromSiteNameController.clear();
      _fromProjectNameController.clear();
      _toSiteNameController.clear();
      _toProjectNameController.clear();
      _fromSupervisorController.clear();
      _toSupervisorController.clear();
      _fromDateController.clear();
      _toDateController.clear();
      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
      materialsToTransfer.clear();
    });
  }

  // Clear SiteToCompany fields
  void _clearSiteToCompanyFields() {
    setState(() {
      _siteToCompanyManagerController.text = _loggedInManagerName;
      _selectedSiteId = null;
      _siteToCompanySiteNameController.clear();
      _siteToCompanySupervisorController.clear();
      _siteToCompanyDateController.clear();
      _projectNameController.clear();
      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
      materialsToTransfer.clear();
    });
  }

  // Validation for Site-to-Site
  bool _validateSiteToSiteForm() {
    if (_fromManagerController.text.isEmpty) {
      _showSnackBar('Please enter From Site manager name');
      return false;
    }

    if (_toManagerController.text.isEmpty) {
      _showSnackBar('Please enter To Site manager name');
      return false;
    }

    if (_fromSiteId == null || _fromSiteId!.isEmpty) {
      _showSnackBar('Please select From Site');
      return false;
    }

    if (_toSiteId == null || _toSiteId!.isEmpty) {
      _showSnackBar('Please select To Site');
      return false;
    }

    if (_fromDateController.text.isEmpty) {
      _showSnackBar('Please select transfer date');
      return false;
    }

    return true;
  }

  // Validation for Site-to-Company
  bool _validateSiteToCompanyForm() {
    if (_siteToCompanyManagerController.text.isEmpty) {
      _showSnackBar('Please enter manager name');
      return false;
    }

    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      _showSnackBar('Please select a site');
      return false;
    }

    if (_siteToCompanyDateController.text.isEmpty) {
      _showSnackBar('Please select transfer date');
      return false;
    }

    return true;
  }

  // Site-to-Site transfer method
  Future<void> _saveSiteToSiteTransfer() async {
    if (_isProcessing) return;
    if (!_validateSiteToSiteForm()) {
      return;
    }

    if (materialsToTransfer.isEmpty) {
      _showSnackBar('Please add at least one material to transfer');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final date = _fromDateController.text.isNotEmpty
          ? _fromDateController.text
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      final fromSite = sitesList.firstWhere(
        (s) => s['siteId'] == _fromSiteId,
        orElse: () => <String, dynamic>{},
      );
      final toSite = sitesList.firstWhere(
        (s) => s['siteId'] == _toSiteId,
        orElse: () => <String, dynamic>{},
      );

      final fromSiteName = (fromSite['siteName'] ?? _fromSiteNameController.text).toString().trim();
      final toSiteName = (toSite['siteName'] ?? _toSiteNameController.text).toString().trim();

      for (final material in materialsToTransfer) {
        final String matName = material['materialName'];
        final int moveCount = material['neededCount'] as int;

        await MaterialInventoryService.transferSiteToSite(
          materialName: matName,
          fromSiteId: _fromSiteId!,
          toSiteId: _toSiteId!,
          quantity: moveCount,
          fromSiteName: fromSiteName.isNotEmpty ? fromSiteName : _fromSiteId!,
          toSiteName: toSiteName.isNotEmpty ? toSiteName : _toSiteId!,
          fromManagerName: _fromManagerController.text.trim(),
          toManagerName: _toManagerController.text.trim(),
          fromSupervisorName: _fromSupervisorController.text.trim(),
          toSupervisorName: _toSupervisorController.text.trim(),
          fromProjectName: _fromProjectNameController.text.trim(),
          toProjectName: _toProjectNameController.text.trim(),
          displayName: material['displayName'],
        );
      }

      // Record legacy movement history entry
      try {
        final movementId = '${_fromSiteId}_${_toSiteId}_${DateTime.now().millisecondsSinceEpoch}';
        final movementRef = FirestoreService.getCollection('materialmovementhistory').doc(movementId);
        Map<String, dynamic> movementHistoryData = {};
        for (int i = 0; i < materialsToTransfer.length; i++) {
          final material = materialsToTransfer[i];
          movementHistoryData[i.toString()] = {
            "map": i,
            "count": material['neededCount'].toString(),
            "date": date,
            "fromsiteid": _fromSiteId,
            "Tositeid": _toSiteId,
            "managername": _fromManagerController.text,
            "materialname": material['materialName'],
            "materialdisplayname": material['displayName'],
            "fromsitename": _fromSiteNameController.text,
            "fromprojectname": _fromProjectNameController.text,
            "fromsupervisorname": _fromSupervisorController.text,
            "tositename": _toSiteNameController.text,
            "toprojectname": _toProjectNameController.text,
            "tosupervisorname": _toSupervisorController.text,
            "timestamp": FieldValue.serverTimestamp(),
          };
        }
        await movementRef.set(movementHistoryData);
      } catch (e) {
        debugPrint('Error recording movement history: $e');
      }

      if (mounted) {
        _showSuccessDialogSiteToSite();

        // Clear form and reload data
        setState(() {
          materialsToTransfer.clear();
          _selectedMaterialName = null;
          availableCount = 0;
          _neededCountController.clear();
        });

        // Reload site materials for updated counts
        await _loadSiteMaterialData(_fromSiteId);
      }
    } catch (e) {
      _showSnackBar('Error saving site-to-site transfer: $e');
      debugPrint('Site-to-Site transfer error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Site-to-Company transfer method
  Future<void> _saveSiteToCompanyTransfer() async {
    if (_isProcessing) return;
    if (!_validateSiteToCompanyForm()) {
      return;
    }

    if (materialsToTransfer.isEmpty) {
      _showSnackBar('Please add at least one material to transfer');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final date = _siteToCompanyDateController.text.isNotEmpty
          ? _siteToCompanyDateController.text
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      final selSite = sitesList.firstWhere(
        (s) => s['siteId'] == _selectedSiteId,
        orElse: () => <String, dynamic>{},
      );
      final siteName = (selSite['siteName'] ?? _siteToCompanySiteNameController.text).toString().trim();

      for (final material in materialsToTransfer) {
        final String matName = material['materialName'];
        final int moveCount = material['neededCount'] as int;

        await MaterialInventoryService.transferSiteToCompany(
          materialName: matName,
          siteId: _selectedSiteId!,
          quantity: moveCount,
          siteName: siteName.isNotEmpty ? siteName : _selectedSiteId!,
          managerName: _siteToCompanyManagerController.text.trim(),
          supervisorName: _siteToCompanySupervisorController.text.trim(),
          projectName: _projectNameController.text.trim(),
          displayName: material['displayName'],
        );
      }

      // Record legacy movement history entry
      try {
        final movementId = '${_selectedSiteId}_company_${DateTime.now().millisecondsSinceEpoch}';
        final movementRef = FirestoreService.getCollection('materialmovementhistory').doc(movementId);
        Map<String, dynamic> movementHistoryData = {};
        for (int i = 0; i < materialsToTransfer.length; i++) {
          final material = materialsToTransfer[i];
          movementHistoryData[i.toString()] = {
            "count": material['neededCount'].toString(),
            "date": date,
            "fromsiteid": _selectedSiteId,
            "managername": _siteToCompanyManagerController.text,
            "materialdisplayname": material['displayName'],
            "materialname": material['materialName'],
            "projectname": _projectNameController.text,
            "sitename": _siteToCompanySiteNameController.text,
            "supervisorname": _siteToCompanySupervisorController.text,
            "timestamp": FieldValue.serverTimestamp(),
            "info": "SiteToCompany",
          };
        }
        await movementRef.set(movementHistoryData);
      } catch (e) {
        debugPrint('Error recording movement history: $e');
      }

      if (mounted) {
        _showSuccessDialogSiteToCompany();
        _clearSiteToCompanyFields();
        await _loadMaterialData();
        if (_selectedSiteId != null) {
          await _loadSiteMaterialData(_selectedSiteId);
        }
      }
    } catch (e) {
      _showSnackBar('Error saving site-to-company transfer: $e');
      debugPrint('Site-to-Company transfer error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Information',
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.white, size: 22),
            onPressed: () => _showHelpDialog(context, primaryColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoadingSites || _isLoadingMaterials
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildModeToggle(primaryColor, darkAccent),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_transferMode == 0)
                              ..._buildSiteToSiteUI(primaryColor, darkAccent)
                            else
                              ..._buildSiteToCompanyUI(primaryColor, darkAccent),
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

  Widget _buildModeToggle(Color primaryColor, Color darkAccent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: 'Site to Site',
              icon: Icons.swap_horiz_rounded,
              isSelected: _transferMode == 0,
              primaryColor: primaryColor,
              darkAccent: darkAccent,
              onTap: () async {
                setState(() {
                  _transferMode = 0;
                  _selectedMaterialName = null;
                  availableCount = 0;
                  _neededCountController.clear();
                  materialsToTransfer.clear();
                });
                if (_fromSiteId != null && _fromSiteId!.isNotEmpty) {
                  await _loadSiteMaterialData(_fromSiteId);
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildToggleButton(
              title: 'Return to Company',
              icon: Icons.assignment_return_rounded,
              isSelected: _transferMode == 1,
              primaryColor: primaryColor,
              darkAccent: darkAccent,
              onTap: () async {
                setState(() {
                  _transferMode = 1;
                  _selectedMaterialName = null;
                  availableCount = 0;
                  _neededCountController.clear();
                  materialsToTransfer.clear();
                });
                if (_selectedSiteId != null && _selectedSiteId!.isNotEmpty) {
                  await _loadSiteMaterialData(_selectedSiteId);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color primaryColor,
    required Color darkAccent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    darkAccent,
                    Color.alphaBlend(
                      primaryColor.withValues(alpha: 0.35),
                      darkAccent,
                    ),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: darkAccent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSiteToSiteUI(Color primaryColor, Color darkAccent) {
    return [
      _buildSectionHeader('From Site (Source)', Icons.outbox_rounded, primaryColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _fromManagerController,
              label: 'Manager Name *',
              hint: 'Enter manager name',
              icon: Icons.person_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildSiteDropdownGeneric(
              'Source Site ID *',
              _fromSiteId,
              sitesList,
              primaryColor,
              (v) async {
                final site = sitesList.firstWhere(
                  (s) => s['siteId'] == v,
                  orElse: () => {},
                );
                setState(() {
                  _fromSiteId = v;
                  _fromSiteNameController.text =
                      site['siteName']?.toString() ?? '';
                  _fromProjectNameController.text =
                      site['projectName']?.toString() ?? '';
                  _fromSupervisorController.text =
                      site['supervisorName']?.toString() ?? '';
                  _selectedMaterialName = null;
                  availableCount = 0;
                  _neededCountController.clear();
                  _isLoadingMaterials = true;
                });
                await _loadSiteMaterialData(v);
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fromSiteNameController,
              label: 'Site Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.location_on_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fromProjectNameController,
              label: 'Project Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.business_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fromSupervisorController,
              label: 'Supervisor Name',
              hint: '',
              enabled: false,
              icon: Icons.supervisor_account_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fromDateController,
              label: 'Transfer Date *',
              hint: 'Select date',
              onTap: () => _selectDate(context, _fromDateController),
              icon: Icons.calendar_month_rounded,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),
      _buildSectionHeader('To Site (Destination)', Icons.move_to_inbox_rounded, primaryColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _toManagerController,
              label: 'Manager Name *',
              hint: 'Enter manager name',
              icon: Icons.person_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildSiteDropdownGeneric(
              'Destination Site ID *',
              _toSiteId,
              sitesList,
              primaryColor,
              (v) {
                final site = sitesList.firstWhere(
                  (s) => s['siteId'] == v,
                  orElse: () => {},
                );
                setState(() {
                  _toSiteId = v;
                  _toSiteNameController.text =
                      site['siteName']?.toString() ?? '';
                  _toProjectNameController.text =
                      site['projectName']?.toString() ?? '';
                  _toSupervisorController.text =
                      site['supervisorName']?.toString() ?? '';
                });
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _toSiteNameController,
              label: 'Site Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.location_on_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _toProjectNameController,
              label: 'Project Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.business_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _toSupervisorController,
              label: 'Supervisor Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.supervisor_account_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _toDateController,
              label: 'Receipt Date *',
              hint: 'Select date',
              onTap: () => _selectDate(context, _toDateController),
              icon: Icons.calendar_month_rounded,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),
      _buildSectionHeader('Materials Selection', Icons.inventory_2_rounded, primaryColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildMaterialDropdown(primaryColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCountBox(
                    'Available Stock',
                    _isFetchingLiveStock ? '...' : availableCount.toString(),
                    availableCount > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    Icons.inventory_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _neededCountController,
                    label: 'Needed Quantity *',
                    hint: 'Enter quantity',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    icon: Icons.pin_rounded,
                    primaryColor: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _clearMaterial,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Add Material',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      if (materialsToTransfer.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildMaterialsList(primaryColor),
      ],

      const SizedBox(height: 20),
      _buildTransferInfoBox(
        'Materials will be transferred directly between the selected sites. Inventory levels will be updated atomically for both sites.',
      ),

      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('CANCEL',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (_validateSiteToSiteForm()) {
                          _saveSiteToSiteTransfer();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: primaryColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('TRANSFER MATERIALS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSiteToCompanyUI(Color primaryColor, Color darkAccent) {
    return [
      _buildSectionHeader('Site Information', Icons.apartment_rounded, primaryColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _siteToCompanyManagerController,
              label: 'Manager Name *',
              hint: 'Enter manager name',
              icon: Icons.person_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildSiteDropdownGeneric(
              'Site ID *',
              _selectedSiteId,
              sitesList,
              primaryColor,
              (v) async {
                final site = sitesList.firstWhere(
                  (s) => s['siteId'] == v,
                  orElse: () => {},
                );
                setState(() {
                  _selectedSiteId = v;
                  _siteToCompanySiteNameController.text =
                      site['siteName']?.toString() ?? '';
                  _siteToCompanySupervisorController.text =
                      site['supervisorName']?.toString() ?? '';
                  _projectNameController.text =
                      site['projectName']?.toString() ?? '';
                  _selectedMaterialName = null;
                  availableCount = 0;
                  _neededCountController.clear();
                  _isLoadingMaterials = true;
                });
                await _loadSiteMaterialData(v);
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _siteToCompanySiteNameController,
              label: 'Site Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.location_on_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _projectNameController,
              label: 'Project Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.business_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _siteToCompanySupervisorController,
              label: 'Supervisor Name',
              hint: 'Auto-filled from selection',
              enabled: false,
              icon: Icons.supervisor_account_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _siteToCompanyDateController,
              label: 'Return Date *',
              hint: 'Select date',
              onTap: () => _selectDate(context, _siteToCompanyDateController),
              icon: Icons.calendar_month_rounded,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),
      _buildSectionHeader('Materials to Return', Icons.inventory_2_rounded, primaryColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildMaterialDropdown(primaryColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCountBox(
                    'Available Stock',
                    _isFetchingLiveStock ? '...' : availableCount.toString(),
                    availableCount > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    Icons.inventory_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _neededCountController,
                    label: 'Return Count *',
                    hint: 'Enter return count',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    icon: Icons.pin_rounded,
                    primaryColor: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _clearMaterial,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Add Material',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      if (materialsToTransfer.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildMaterialsList(primaryColor),
      ],

      const SizedBox(height: 20),
      _buildTransferInfoBox(
        'Materials are returned from site to central company inventory. Stock counts will be updated automatically.',
      ),

      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('CANCEL',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (_validateSiteToCompanyForm()) {
                          _saveSiteToCompanyTransfer();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: primaryColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('RETURN TO COMPANY',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _showSuccessDialogSiteToSite([Color? primaryColor]) {
    final effectivePrimary =
        primaryColor ?? Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transfer Successful!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Materials have been transferred successfully between sites.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoItem('From: ${_fromSiteNameController.text}'),
              _buildInfoItem('To: ${_toSiteNameController.text}'),
              _buildInfoItem('Date: ${_fromDateController.text}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearSiteToSiteFields();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectivePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialogSiteToCompany([Color? primaryColor]) {
    final effectivePrimary =
        primaryColor ?? Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Return Successful!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Materials have been returned to company successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoItem('Site: ${_siteToCompanySiteNameController.text}'),
              _buildInfoItem('Date: ${_siteToCompanyDateController.text}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearSiteToCompanyFields();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectivePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showHelpDialog(BuildContext context, [Color? primaryColor]) {
    final effectivePrimary =
        primaryColor ?? Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectivePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.help_outline_rounded,
                      color: effectivePrimary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'About Material Transfer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              Icons.swap_horiz_rounded,
              'Site to Site',
              'Transfer materials directly between two project sites.',
              effectivePrimary,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.assignment_return_rounded,
              'Return to Company',
              'Send unused materials from site back to central inventory.',
              effectivePrimary,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.inventory_2_rounded,
              'Real-time Tracking',
              'Site & company inventory levels update automatically upon transfer.',
              effectivePrimary,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectivePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(
    IconData icon,
    String title,
    String description,
    Color primaryColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
    required Color primaryColor,
  }) {
    return TextField(
      controller: controller,
      readOnly: onTap != null || !enabled,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
        prefixIcon: icon != null
            ? Icon(icon, color: primaryColor, size: 18)
            : null,
        isDense: true,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF3B82F6),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E40AF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Materials to Transfer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${materialsToTransfer.length} items',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: materialsToTransfer.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final material = materialsToTransfer[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2_rounded,
                          color: primaryColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material['displayName'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Quantity: ${material['neededCount']} units',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      onPressed: () => _removeMaterial(index),
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

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteDropdownGeneric(
    String label,
    String? selectedId,
    List<Map<String, dynamic>> sitesList,
    Color primaryColor,
    ValueChanged<String?> onChanged,
  ) {
    final hasMatch = selectedId != null && sitesList.any((s) => s['siteId'] == selectedId);
    final currentValue = hasMatch ? selectedId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('site_${currentValue}_${sitesList.length}'),
          initialValue: currentValue,
          isExpanded: true,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            prefixIcon:
                Icon(Icons.apartment_rounded, color: primaryColor, size: 18),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
          items: sitesList.map((site) {
            final displayId = (site['siteId'] ?? site['siteName'] ?? '').toString();
            return DropdownMenuItem<String>(
              value: site['siteId']?.toString(),
              child: Text(
                displayId,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }

  Widget _buildMaterialDropdown(Color primaryColor) {
    final effectiveList = siteMaterialsList.isNotEmpty ? siteMaterialsList : materialsList;
    final hasMatch = _selectedMaterialName != null &&
        effectiveList.any((m) =>
            (m['materialName'] ?? '').toString().trim().toLowerCase() ==
                _selectedMaterialName!.trim().toLowerCase() ||
            (m['displayName'] ?? '').toString().trim().toLowerCase() ==
                _selectedMaterialName!.trim().toLowerCase());
    final currentValue = hasMatch ? _selectedMaterialName : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('mat_${currentValue}_${effectiveList.length}'),
          initialValue: currentValue,
          isExpanded: true,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Select Material *',
            labelStyle:
                const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            prefixIcon:
                Icon(Icons.inventory_2_rounded, color: primaryColor, size: 18),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
          items: effectiveList.map((material) {
            final materialName = (material['materialName'] ?? '').toString();
            final displayName = (material['displayName'] ?? materialName).toString();
            final count =
                _parseCount(material['count'] ?? material['availableCount']);

            return DropdownMenuItem<String>(
              value: materialName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName.isNotEmpty ? displayName : materialName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: $count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }
}
