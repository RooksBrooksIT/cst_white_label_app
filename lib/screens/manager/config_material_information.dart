import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
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

  // Loading states
  bool _isLoadingSites = true;
  bool _isLoadingMaterials = true;

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

  int _tsMillis(dynamic v) {
    try {
      if (v == null) return -1;
      if (v is Timestamp) return v.millisecondsSinceEpoch;
      if (v is DateTime) return v.millisecondsSinceEpoch;
      if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? -1;
      return -1;
    } catch (_) {
      return -1;
    }
  }

  Future<void> _loadMaterialData() async {
    try {
      final Map<String, Map<String, dynamic>> materialMap = {};

      // Fetch exclusively from materialsavailablity collection
      try {
        final availSnapshot = await FirestoreService.getCollection('materialsavailablity').get();
        for (final doc in availSnapshot.docs) {
          final data = doc.data();
          final name = (data['materialName'] ?? data['materialname'] ?? doc.id).toString().trim();
          if (name.isEmpty) continue;
          final count = _parseCount(data['count'] ?? data['availableCount']);
          final lastUpdatedMs = _tsMillis(data['lastupdated'] ?? data['lastUpdated']);

          if (!materialMap.containsKey(name) || lastUpdatedMs > (materialMap[name]!['lastupdatedMillis'] as int? ?? -1)) {
            materialMap[name] = {
              'materialId': doc.id,
              'materialName': name,
              'displayName': name,
              'count': count,
              'lastupdatedMillis': lastUpdatedMs,
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching materialsavailablity: $e');
      }

      final list = materialMap.values.toList()
        ..sort(
          (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
                (b['displayName'] as String).toLowerCase(),
              ),
        );

      if (mounted) {
        setState(() {
          materialsList = list;
          _isLoadingMaterials = false;
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
      final Map<String, Map<String, dynamic>> siteMatMap = {};

      // 1. Fetch from materialatsite
      try {
        final snap = await FirestoreService.getCollection('materialatsite')
            .where('siteid', isEqualTo: siteId).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['materialName'] ?? data['materialname'] ?? doc.id).toString().trim();
          if (name.isEmpty) continue;
          final count = _parseCount(data['count'] ?? data['availableCount']);
          siteMatMap[name] = {
            'materialId': doc.id,
            'materialName': name,
            'displayName': name,
            'count': count,
          };
        }
      } catch (_) {}

      // 2. Fetch from siteMaterials/{siteId}/materials
      try {
        final snap = await FirestoreService.getCollection('siteMaterials')
            .doc(siteId).collection('materials').get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['materialName'] ?? data['materialname'] ?? data['displayName'] ?? doc.id).toString().trim();
          if (name.isEmpty) continue;
          final count = _parseCount(data['count'] ?? data['availableCount']);
          final existingCount = siteMatMap[name]?['count'] as int? ?? 0;
          if (!siteMatMap.containsKey(name) || count > existingCount) {
            siteMatMap[name] = {
              'materialId': doc.id,
              'materialName': name,
              'displayName': (data['displayName'] ?? name).toString().trim(),
              'count': count,
            };
          }
        }
      } catch (_) {}

      final list = siteMatMap.values.toList()
        ..sort(
          (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
                (b['displayName'] as String).toLowerCase(),
              ),
        );

      if (mounted) {
        setState(() {
          siteMaterialsList = list;
          _isLoadingMaterials = false;
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

  void _onMaterialChanged(String? materialName) {
    if (materialName != null) {
      setState(() {
        _selectedMaterialName = materialName;
        final list = _transferMode == 0 ? materialsList : siteMaterialsList;
        final material = list.firstWhere(
          (m) => (m['materialName'] ?? m['displayName']) == materialName,
          orElse: () => {'count': 0},
        );
        availableCount = _parseCount(material['count']);
      });
    }
  }

  void _addMaterial() {
    if (_selectedMaterialName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material')),
      );
      return;
    }

    final neededCountStr = _neededCountController.text.trim();
    if (neededCountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter needed count')),
      );
      return;
    }

    final neededCount = int.tryParse(neededCountStr);
    if (neededCount == null || neededCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive number')),
      );
      return;
    }

    if (neededCount > availableCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Needed count ($neededCount) cannot exceed available count ($availableCount)',
          ),
        ),
      );
      return;
    }

    final list = _transferMode == 0 ? materialsList : siteMaterialsList;
    final material = list.firstWhere(
      (m) => m['materialName'] == _selectedMaterialName,
    );

    final existingIndex = materialsToTransfer.indexWhere(
      (m) => m['materialName'] == _selectedMaterialName,
    );

    if (existingIndex >= 0) {
      final currentNeeded = materialsToTransfer[existingIndex]['neededCount'];
      final newTotal = currentNeeded + neededCount;

      if (newTotal > availableCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total count ($newTotal) would exceed available count ($availableCount)',
            ),
          ),
        );
        return;
      }

      setState(() {
        materialsToTransfer[existingIndex]['neededCount'] = newTotal;
      });
    } else {
      setState(() {
        materialsToTransfer.add({
          'materialId': material['materialId'],
          'materialName': material['materialName'],
          'displayName': material['displayName'],
          'neededCount': neededCount,
          'availableCount': availableCount,
        });
      });
    }

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
    if (!_validateCompanyToSiteForm()) return;

    try {
      final transferData = {
        'managerName': _managerNameController.text.trim(),
        'siteId': _selectedSiteId,
        'projectName': _projectNameController.text.trim(),
        'supervisorName': _supervisorNameController.text.trim(),
        'date': _dateController.text.trim(),
        'transferType': 'CompanyToSite',
        'materials': materialsToTransfer,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('materialTransfers').add(transferData);

      for (var material in materialsToTransfer) {
        final materialName = material['materialName'];
        final neededCount = material['neededCount'];

        // Update materialsavailablity collection
        try {
          final availSnapshot = await FirestoreService.getCollection('materialsavailablity').get();
          for (final doc in availSnapshot.docs) {
            final data = doc.data();
            final name = (data['materialName'] ?? data['materialname'] ?? doc.id).toString().trim();
            if (name == materialName) {
              final currentCount = _parseCount(data['count'] ?? data['availableCount']);
              final newCount = (currentCount - neededCount).clamp(0, double.infinity).toInt();
              await FirestoreService.getCollection('materialsavailablity').doc(doc.id).update({
                'count': newCount,
                'lastupdated': FieldValue.serverTimestamp(),
              });
            }
          }
        } catch (e) {
          debugPrint('Error updating materialsavailablity: $e');
        }

        final materialQuery = await FirestoreService.getCollection('materials')
            .where('materialName', isEqualTo: materialName)
            .get();

        if (materialQuery.docs.isNotEmpty) {
          final doc = materialQuery.docs.first;
          final currentAvailable = doc.data()['availableCount'] ?? doc.data()['count'] ?? 0;
          final newAvailable = (currentAvailable - neededCount).clamp(0, double.infinity).toInt();

          await FirestoreService.getCollection('materials').doc(doc.id).update({
            'availableCount': newAvailable,
            'count': newAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final siteMaterialRef = FirestoreService.getCollection('siteMaterials')
            .doc(_selectedSiteId)
            .collection('materials')
            .doc(materialName);

        final siteMaterialDoc = await siteMaterialRef.get();

        if (siteMaterialDoc.exists) {
          final currentSiteCount = siteMaterialDoc.data()?['count'] ?? 0;
          await siteMaterialRef.update({
            'count': currentSiteCount + neededCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await siteMaterialRef.set({
            'materialId': materialName,
            'materialName': materialName,
            'displayName': material['displayName'],
            'count': neededCount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Sync to materialatsite collection
        try {
          final matAtSiteRef = FirestoreService.getCollection('materialatsite')
              .doc('${_selectedSiteId}_$materialName');
          final matAtSiteDoc = await matAtSiteRef.get();
          if (matAtSiteDoc.exists) {
            final curr = _parseCount(matAtSiteDoc.data()?['count'] ?? matAtSiteDoc.data()?['availableCount']);
            await matAtSiteRef.update({
              'count': curr + neededCount,
              'availableCount': curr + neededCount,
              'siteid': _selectedSiteId,
              'materialName': materialName,
              'materialname': materialName,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await matAtSiteRef.set({
              'siteid': _selectedSiteId,
              'materialName': materialName,
              'materialname': materialName,
              'count': neededCount,
              'availableCount': neededCount,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error syncing materialatsite on company to site transfer: $e');
        }
      }

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Materials transferred successfully!',
        );
        _clearAll();
        _loadMaterialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error transferring materials: $e')));
      }
    }
  }

  Future<void> _saveSiteToSiteTransfer() async {
    try {
      final transferData = {
        'fromManagerName': _fromManagerController.text.trim(),
        'fromSiteId': _fromSiteId,
        'fromSiteName': _fromSiteNameController.text.trim(),
        'fromProjectName': _fromProjectNameController.text.trim(),
        'fromSupervisorName': _fromSupervisorController.text.trim(),
        'fromDate': _fromDateController.text.trim(),
        'toManagerName': _toManagerController.text.trim(),
        'toSiteId': _toSiteId,
        'toSiteName': _toSiteNameController.text.trim(),
        'toProjectName': _toProjectNameController.text.trim(),
        'toSupervisorName': _toSupervisorController.text.trim(),
        'toDate': _toDateController.text.trim(),
        'transferType': 'SiteToSite',
        'materials': materialsToTransfer,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('materialTransfers').add(transferData);

      for (var material in materialsToTransfer) {
        final materialName = material['materialName'];
        final neededCount = material['neededCount'];

        final fromSiteRef = FirestoreService.getCollection('siteMaterials')
            .doc(_fromSiteId)
            .collection('materials')
            .doc(materialName);

        final fromDoc = await fromSiteRef.get();
        if (fromDoc.exists) {
          final currentFromCount = fromDoc.data()?['count'] ?? 0;
          final newFromCount = (currentFromCount - neededCount).clamp(0, double.infinity).toInt();
          await fromSiteRef.update({
            'count': newFromCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final toSiteRef = FirestoreService.getCollection('siteMaterials')
            .doc(_toSiteId)
            .collection('materials')
            .doc(materialName);

        final toDoc = await toSiteRef.get();
        if (toDoc.exists) {
          final currentToCount = toDoc.data()?['count'] ?? 0;
          await toSiteRef.update({
            'count': currentToCount + neededCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await toSiteRef.set({
            'materialId': materialName,
            'materialName': materialName,
            'displayName': material['displayName'],
            'count': neededCount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Sync to materialatsite for both fromSite and toSite
        try {
          final fromMatAtSiteRef = FirestoreService.getCollection('materialatsite')
              .doc('${_fromSiteId}_$materialName');
          final fromMatAtSiteDoc = await fromMatAtSiteRef.get();
          if (fromMatAtSiteDoc.exists) {
            final curr = _parseCount(fromMatAtSiteDoc.data()?['count'] ?? fromMatAtSiteDoc.data()?['availableCount']);
            final updated = (curr - neededCount).clamp(0, double.infinity).toInt();
            await fromMatAtSiteRef.update({
              'count': updated,
              'availableCount': updated,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          final toMatAtSiteRef = FirestoreService.getCollection('materialatsite')
              .doc('${_toSiteId}_$materialName');
          final toMatAtSiteDoc = await toMatAtSiteRef.get();
          if (toMatAtSiteDoc.exists) {
            final curr = _parseCount(toMatAtSiteDoc.data()?['count'] ?? toMatAtSiteDoc.data()?['availableCount']);
            await toMatAtSiteRef.update({
              'count': curr + neededCount,
              'availableCount': curr + neededCount,
              'siteid': _toSiteId,
              'materialName': materialName,
              'materialname': materialName,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await toMatAtSiteRef.set({
              'siteid': _toSiteId,
              'materialName': materialName,
              'materialname': materialName,
              'count': neededCount,
              'availableCount': neededCount,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error syncing materialatsite on site to site transfer: $e');
        }
      }

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Site-to-Site transfer completed successfully!',
        );
        _clearAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error performing transfer: $e')));
      }
    }
  }

  Future<void> _saveSiteToCompanyTransfer() async {
    try {
      final transferData = {
        'managerName': _siteToCompanyManagerController.text.trim(),
        'siteId': _selectedSiteId,
        'siteName': _siteToCompanySiteNameController.text.trim(),
        'projectName': _projectNameController.text.trim(),
        'supervisorName': _siteToCompanySupervisorController.text.trim(),
        'date': _siteToCompanyDateController.text.trim(),
        'transferType': 'SiteToCompany',
        'materials': materialsToTransfer,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('materialTransfers').add(transferData);

      for (var material in materialsToTransfer) {
        final materialName = material['materialName'];
        final neededCount = material['neededCount'];

        final siteMaterialRef = FirestoreService.getCollection('siteMaterials')
            .doc(_selectedSiteId)
            .collection('materials')
            .doc(materialName);

        final siteMaterialDoc = await siteMaterialRef.get();
        if (siteMaterialDoc.exists) {
          final currentSiteCount = siteMaterialDoc.data()?['count'] ?? 0;
          final newSiteCount = (currentSiteCount - neededCount).clamp(0, double.infinity).toInt();
          await siteMaterialRef.update({
            'count': newSiteCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Sync to materialatsite
        try {
          final matAtSiteRef = FirestoreService.getCollection('materialatsite')
              .doc('${_selectedSiteId}_$materialName');
          final matAtSiteDoc = await matAtSiteRef.get();
          if (matAtSiteDoc.exists) {
            final curr = _parseCount(matAtSiteDoc.data()?['count'] ?? matAtSiteDoc.data()?['availableCount']);
            final updated = (curr - neededCount).clamp(0, double.infinity).toInt();
            await matAtSiteRef.update({
              'count': updated,
              'availableCount': updated,
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error syncing materialatsite on site to company transfer: $e');
        }

        // Update materialsavailablity collection
        try {
          final availSnapshot = await FirestoreService.getCollection('materialsavailablity').get();
          for (final doc in availSnapshot.docs) {
            final data = doc.data();
            final name = (data['materialName'] ?? data['materialname'] ?? doc.id).toString().trim();
            if (name == materialName) {
              final currentCount = _parseCount(data['count'] ?? data['availableCount']);
              final newCount = currentCount + neededCount;
              await FirestoreService.getCollection('materialsavailablity').doc(doc.id).update({
                'count': newCount,
                'lastupdated': FieldValue.serverTimestamp(),
              });
            }
          }
        } catch (e) {
          debugPrint('Error updating materialsavailablity on return: $e');
        }

        final materialQuery = await FirestoreService.getCollection('materials')
            .where('materialName', isEqualTo: materialName)
            .get();

        if (materialQuery.docs.isNotEmpty) {
          final doc = materialQuery.docs.first;
          final currentAvailable = doc.data()['availableCount'] ?? doc.data()['count'] ?? 0;
          final newAvailable = currentAvailable + neededCount;

          await FirestoreService.getCollection('materials').doc(doc.id).update({
            'availableCount': newAvailable,
            'count': newAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Site-to-Company return completed successfully!',
        );
        _clearAll();
        _loadMaterialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error performing return: $e')),
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        '$availableCount',
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Transfer to Site',
                                  onPressed: () {
                                    if (_validateCompanyToSiteForm()) {
                                      _saveCompanyToSiteTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
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
                                      });
                                      _fetchAndFillSiteDetails(v, mode: 1);
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
                          const SizedBox(height: 20),
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
                                      _fetchAndFillSiteDetails(v, mode: 2);
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        '$availableCount',
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Transfer Site to Site',
                                  onPressed: () {
                                    if (_validateSiteToSiteForm()) {
                                      _saveSiteToSiteTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
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
                                      });
                                      _fetchAndFillSiteDetails(v, mode: 3);
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Material Details'),
                                const SizedBox(height: 18),
                                _buildMaterialDropdown(),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCountBox(
                                        'Available Count',
                                        '$availableCount',
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
                          const SizedBox(height: 20),
                          _buildCardContainer(
                            child: Column(
                              children: [
                                _buildTransferActionsButton(
                                  primaryColor: primaryColor,
                                  actionText: 'Return to Company',
                                  onPressed: () {
                                    if (_validateSiteToCompanyForm()) {
                                      _saveSiteToCompanyTransfer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
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
            _neededCountController.clear();
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
      padding: const EdgeInsets.all(22),
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
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
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
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: _isLoadingSites
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  initialValue: selectedId,
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
                      vertical: 14,
                    ),
                  ),
                  items: sitesList.map((site) {
                    return DropdownMenuItem<String>(
                      value: site['siteId'],
                      child: Text(site['siteName'] ?? site['siteId']),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: _isLoadingMaterials
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  initialValue: _selectedMaterialName,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Select Material',
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
                      vertical: 14,
                    ),
                  ),
                  items: (_transferMode == 0 ? materialsList : siteMaterialsList)
                      .map((material) {
                        final materialName = material['materialName'];
                        final displayName = material['displayName'];
                        final count = _parseCount(material['count']);

                        return DropdownMenuItem<String>(
                          value: materialName,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName ?? materialName,
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (count > 0 ? Colors.green : Colors.red)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Avail: $count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: count > 0
                                        ? const Color(0xFF2E7D32)
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
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
        const Text(
          'Materials to Transfer:',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
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
                      material['displayName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A183D),
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Quantity: ${material['neededCount']} units',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                      onPressed: () => _removeMaterial(index),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      color: Color(0xFFCBD5E1),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Total Materials: ${materialsToTransfer.length}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTransferActionsButton({
    required Color primaryColor,
    required String actionText,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _clearAll,
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
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: Row(
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
          const Text('• ', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
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
