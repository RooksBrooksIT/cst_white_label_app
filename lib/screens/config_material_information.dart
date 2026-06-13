import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/dialog_utils.dart';
import 'package:intl/intl.dart';

class MaterialInfoScreen extends StatefulWidget {
  const MaterialInfoScreen({super.key});

  @override
  State<MaterialInfoScreen> createState() => _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<MaterialInfoScreen> {
  // Removed unused _firestore field

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

  // Load site data from site collection with supervisor mapping left-joined
  Future<void> _loadSiteData() async {
    try {
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();
      final Map<String, Map<String, dynamic>> siteDetails = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data() as Map<String, dynamic>
      };

      final mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap').get();
      // Build lookup by 'site' field AND by plain site name (for older records)
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
            final sId = entry.key;           // e.g. "S001_MySiteName"
            final sData = entry.value;
            final siteName = sData['siteName']?.toString() ?? sId;
            // Try matching by doc ID first, then by plain site name
            final mapping = supervisorMap[sId] ?? supervisorMap[siteName];

            return <String, dynamic>{
              'siteId': sId,
              'siteName': siteName,
              'projectName': mapping?['projectName'] ?? sData['projectName'] ?? '',
              'supervisorName': mapping?['supervisor'] ?? 'Not Assigned',
            };
          }).toList();
          _isLoadingSites = false;
          debugPrint('Loaded ${sitesList.length} sites successfully');
        });
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

  // Asynchronously fetch and fill latest project and supervisor details from Firestore
  Future<void> _fetchAndFillSiteDetails(String siteId, {required int mode, bool isFromSite = true}) async {
    final trimmedId = siteId.trim();
    if (trimmedId.isEmpty) return;

    debugPrint('Auto-filling site details for ID: $trimmedId (mode: $mode)');

    String? supervisor;
    String? projectName;
    String? siteName;

    // 1. Check preloaded sitesList as a fast initial fill (instant UI update)
    final siteItem = sitesList.firstWhere(
      (s) => s['siteId']?.toString().trim() == trimmedId,
      orElse: () => <String, dynamic>{},
    );
    if (siteItem.isNotEmpty) {
      debugPrint('Found preloaded siteItem: $siteItem');
      siteName = siteItem['siteName']?.toString();
      // Only use preloaded supervisor/projectName if they are non-empty/non-default
      final preloadedProject = siteItem['projectName']?.toString() ?? '';
      final preloadedSupervisor = siteItem['supervisorName']?.toString() ?? '';
      if (preloadedProject.isNotEmpty) projectName = preloadedProject;
      if (preloadedSupervisor.isNotEmpty && preloadedSupervisor != 'Not Assigned') supervisor = preloadedSupervisor;
    } else {
      debugPrint('No preloaded siteItem found for $trimmedId');
    }

    // Fill immediately with whatever we have so far
    if (mounted) {
      setState(() {
        _applyFill(mode: mode, isFromSite: isFromSite,
          siteName: siteName ?? trimmedId,
          projectName: projectName ?? '',
          supervisor: supervisor ?? '');
      });
    }

    try {
      // 2. Always query siteSupervisorMap by 'site' field (doc IDs don't match siteId)
      // Also try plain siteName in case older records stored the name rather than doc ID
      QuerySnapshot<Map<String, dynamic>>? mapSnapshot;
      mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap')
          .where('site', isEqualTo: trimmedId)
          .limit(1)
          .get();

      if (mapSnapshot.docs.isEmpty && siteName != null && siteName != trimmedId) {
        // Fallback: try querying by the human-readable site name
        mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap')
            .where('site', isEqualTo: siteName)
            .limit(1)
            .get();
      }

      if (mapSnapshot.docs.isNotEmpty) {
        final data = mapSnapshot.docs.first.data();
        final fetchedSupervisor = data['supervisor']?.toString();
        final fetchedProject = (data['projectName'] ?? data['project_name'])?.toString();
        if (fetchedSupervisor != null && fetchedSupervisor.isNotEmpty) supervisor = fetchedSupervisor;
        if (fetchedProject != null && fetchedProject.isNotEmpty) projectName = fetchedProject;
      }

      // 3. Fetch from projects collection by siteId for the project name
      if (projectName == null || projectName.isEmpty) {
        // Try with doc ID format first
        var projectSnapshot = await FirestoreService.getCollection('projects')
            .where('siteId', isEqualTo: trimmedId)
            .limit(1)
            .get();
        // Also try with siteName if still not found
        if (projectSnapshot.docs.isEmpty && siteName != null) {
          projectSnapshot = await FirestoreService.getCollection('projects')
              .where('siteName', isEqualTo: siteName)
              .limit(1)
              .get();
        }
        if (projectSnapshot.docs.isNotEmpty) {
          final pData = projectSnapshot.docs.first.data();
          // projects docs have 'siteName' not 'projectName'
          final pName = (pData['projectName'] ?? pData['siteName'])?.toString();
          if (pName != null && pName.trim().isNotEmpty) projectName = pName;
        }
      }
    } catch (e) {
      debugPrint('Error auto-filling site details for $trimmedId: $e');
    }

    // Final fallbacks
    supervisor = (supervisor?.isNotEmpty == true) ? supervisor : 'Not Assigned';
    projectName = (projectName?.isNotEmpty == true) ? projectName : (siteName ?? trimmedId);
    siteName ??= trimmedId;

    if (mounted) {
      setState(() {
        _applyFill(mode: mode, isFromSite: isFromSite,
          siteName: siteName!,
          projectName: projectName!,
          supervisor: supervisor!);
      });
    }
  }

  // Helper to apply filled values to the correct controllers based on mode
  void _applyFill({
    required int mode,
    required bool isFromSite,
    required String siteName,
    required String projectName,
    required String supervisor,
  }) {
    if (mode == 0) {
      _projectNameController.text = projectName;
      _supervisorNameController.text = supervisor.isNotEmpty ? supervisor : 'Not Assigned';
    } else if (mode == 1) {
      if (isFromSite) {
        _fromSiteNameController.text = siteName;
        _fromProjectNameController.text = projectName;
        _fromSupervisorController.text = supervisor.isNotEmpty ? supervisor : 'Not Assigned';
      } else {
        _toSiteNameController.text = siteName;
        _toProjectNameController.text = projectName;
        _toSupervisorController.text = supervisor.isNotEmpty ? supervisor : 'Not Assigned';
      }
    } else if (mode == 2) {
      _siteToCompanySiteNameController.text = siteName;
      _siteToCompanySupervisorController.text = supervisor.isNotEmpty ? supervisor : 'Not Assigned';
      _projectNameController.text = projectName;
    }
  }

  // Utility: safely parse count as int from num or string
  int _parseCount(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // Utility: coerce a Firestore timestamp-like value to milliseconds since epoch
  int _tsMillis(dynamic v) {
    try {
      if (v == null) return -1;
      if (v is Timestamp) {
        return v.millisecondsSinceEpoch;
      }
      if (v is DateTime) {
        return v.millisecondsSinceEpoch;
      }
      if (v is String) {
        final dt = DateTime.tryParse(v);
        return dt?.millisecondsSinceEpoch ?? -1;
      }
      // Fallback not supported type
      return -1;
    } catch (_) {
      return -1;
    }
  }

  // Load material data from materialsavailablity collection
  Future<void> _loadMaterialData() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'materialsavailablity',
      ).get();

      // Group by materialname and pick the latest entry (by lastupdated) for each
      final Map<String, Map<String, dynamic>> latestByName = {};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Check for both materialName and materialname
        final name = (data['materialName'] ?? data['materialname'] ?? '')
            .toString()
            .trim();
        if (name.isEmpty) continue;

        final count = _parseCount(data['count']);
        // Check for both lastupdated and lastUpdated
        final lastUpdatedMs = _tsMillis(
          data['lastupdated'] ?? data['lastUpdated'],
        );

        if (!latestByName.containsKey(name)) {
          latestByName[name] = {
            'docId': doc.id,
            'materialName': name,
            'displayName': name,
            'count': count,
            'lastupdatedMillis': lastUpdatedMs,
          };
        } else {
          final existing = latestByName[name]!;
          final existingTs = existing['lastupdatedMillis'];
          final isNewer = lastUpdatedMs > (existingTs as int? ?? -1);
          if (isNewer) {
            latestByName[name] = {
              'docId': doc.id,
              'materialName': name,
              'displayName': name,
              'count': count,
              'lastupdatedMillis': lastUpdatedMs,
            };
          }
        }
      }

      final list = latestByName.values.toList()
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
      print('Error loading material data: $e');
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
        _showSnackBar('Error loading material data');
      }
    }
  }

  // Load material data for a specific site from materialatsite
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
      final querySnapshot = await FirestoreService.getCollection(
        'materialatsite',
      ).where('siteid', isEqualTo: siteId).get();

      final list =
          querySnapshot.docs
              .map((doc) {
                final data = doc.data();
                // Check for both materialName and materialname
                final name =
                    (data['materialName'] ?? data['materialname'] ?? '')
                        .toString()
                        .trim();
                if (name.isEmpty) return null;
                final count = _parseCount(data['count']);
                return {
                  'docId': doc.id,
                  'materialName': name,
                  'displayName': name,
                  'count': count,
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList()
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
          siteMaterialsList = [];
          _isLoadingMaterials = false;
        });
      }
      _showSnackBar('Error loading site materials');
    }
  }

  // Handle site selection change for SiteToCompany
  void _onSiteToCompanySiteChanged(String? siteId) {
    if (siteId == _selectedSiteId) return;

    setState(() {
      _selectedSiteId = siteId;

      // Find the selected site data and auto-fill site name and supervisor name
      final selectedSite = sitesList.firstWhere(
        (site) => site['siteId'] == siteId,
        orElse: () => <String, dynamic>{},
      );

      if (selectedSite.isNotEmpty) {
        _siteToCompanySiteNameController.text =
            selectedSite['siteName']?.toString() ?? '';
        _siteToCompanySupervisorController.text =
            selectedSite['supervisorName']?.toString() ?? '';
        _projectNameController.text =
            selectedSite['projectName']?.toString() ?? '';
      } else {
        _siteToCompanySiteNameController.clear();
        _siteToCompanySupervisorController.clear();
        _projectNameController.clear();
      }
    });
  }

  // Handle material selection change
  void _onMaterialChanged(String? materialName) {
    if (materialName == _selectedMaterialName) return;

    setState(() {
      _selectedMaterialName = materialName;
      if (materialName != null) {
        final source = _transferMode == 0 ? materialsList : siteMaterialsList;
        final selectedMaterial = source.firstWhere(
          (material) => material['materialName'] == materialName,
          orElse: () => <String, dynamic>{},
        );
        if (selectedMaterial.isNotEmpty) {
          availableCount = selectedMaterial['count'] ?? 0;
        } else {
          availableCount = 0;
        }
      } else {
        availableCount = 0;
      }
      _neededCountController.clear();
    });
  }

  // Add material to transfer list
  void _addMaterial() {
    if (_selectedMaterialName == null || _selectedMaterialName!.isEmpty) {
      _showSnackBar('Please select a material');
      return;
    }

    if (_neededCountController.text.isEmpty) {
      _showSnackBar('Please enter needed count');
      return;
    }

    final neededCount = int.tryParse(_neededCountController.text) ?? 0;
    if (neededCount <= 0) {
      _showSnackBar('Please enter a valid needed count');
      return;
    }

    if (neededCount > availableCount) {
      _showSnackBar('Needed count cannot exceed available count');
      return;
    }

    // Get the display name for the material
    final source = _transferMode == 0 ? materialsList : siteMaterialsList;
    final selectedMaterial = source.firstWhere(
      (material) => material['materialName'] == _selectedMaterialName,
      orElse: () => <String, dynamic>{},
    );
    final displayName =
        selectedMaterial['displayName'] ?? _selectedMaterialName!;

    // Check if material already exists in the list
    final existingIndex = materialsToTransfer.indexWhere(
      (item) => item['materialName'] == _selectedMaterialName,
    );

    if (existingIndex != -1) {
      // Update existing material
      setState(() {
        materialsToTransfer[existingIndex]['neededCount'] = neededCount;
      });
      _showSnackBar('Material quantity updated');
    } else {
      // Add new material
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

  // Clear all fields
  void _clearAll() {
    setState(() {
      _managerNameController.clear();
      _selectedSiteId = null;
      _projectNameController.clear();
      _supervisorNameController.clear();

      _fromManagerController.clear();
      _fromSiteId = null;
      _fromSiteNameController.clear();
      _fromProjectNameController.clear();
      _fromSupervisorController.clear();

      _toManagerController.clear();
      _toSiteId = null;
      _toSiteNameController.clear();
      _toProjectNameController.clear();
      _toSupervisorController.clear();

      _siteToCompanyManagerController.clear();
      _siteToCompanySiteNameController.clear();
      _siteToCompanySupervisorController.clear();
      _siteToCompanyDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());

      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
      materialsToTransfer.clear();
    });
  }

  // Clear only material fields
  void _clearMaterial() {
    setState(() {
      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
    });
  }

  // Clear SiteToCompany fields
  void _clearSiteToCompanyFields() {
    setState(() {
      _siteToCompanyManagerController.clear();
      _selectedSiteId = null;
      _siteToCompanySiteNameController.clear();
      _siteToCompanySupervisorController.clear();
      _projectNameController.clear();
      _siteToCompanyDateController.clear();
      _selectedMaterialName = null;
      _neededCountController.clear();
      availableCount = 0;
      materialsToTransfer.clear();
    });
  }

  // Transfer materials for CompanyToSite
  Future<void> _transferMaterials() async {
    if (!_validateForm()) {
      return;
    }

    if (materialsToTransfer.isEmpty) {
      _showSnackBar('Please add at least one material to transfer');
      return;
    }

    await _showTransferConfirmationDialog();
  }

  bool _validateForm() {
    if (_managerNameController.text.isEmpty) {
      _showSnackBar('Please enter manager name');
      return false;
    }

    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      _showSnackBar('Please select a site');
      return false;
    }

    if (_projectNameController.text.isEmpty) {
      _showSnackBar('Project name is required');
      return false;
    }

    if (_supervisorNameController.text.isEmpty) {
      _showSnackBar('Supervisor name is required');
      return false;
    }

    return true;
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

  Future<void> _showTransferConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Transfer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to transfer these materials?',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transfer Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Site: ${_getSelectedSiteName()}'),
                Text('Project: ${_projectNameController.text}'),
                Text('Supervisor: ${_supervisorNameController.text}'),
                const SizedBox(height: 12),
                const Text(
                  'Materials to transfer:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...materialsToTransfer
                    .map(
                      (material) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '- ${material['displayName']}: ${material['neededCount']} units',
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 12),
                const Text(
                  'Note: Available counts will be updated automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveTransferData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Transfer'),
            ),
          ],
        );
      },
    );
  }

  String _getSelectedSiteName() {
    if (_selectedSiteId == null) return '';
    final selectedSite = sitesList.firstWhere(
      (site) => site['siteId'] == _selectedSiteId,
      orElse: () => <String, dynamic>{},
    );
    return selectedSite['siteName'] ?? _selectedSiteId!;
  }

  Future<void> _saveTransferData() async {
    try {
      final date = _dateController.text;
      final siteName = _getSelectedSiteName();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Transferring materials...'),
              ],
            ),
          );
        },
      );

      // Use batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Save to materialmovementhistory collection
      final movementHistoryDocId = '${_selectedSiteId}_$date';
      final movementHistoryRef = FirestoreService.getCollection(
        'materialmovementhistory',
      ).doc(movementHistoryDocId);

      Map<String, dynamic> movementHistoryData = {};
      for (int i = 0; i < materialsToTransfer.length; i++) {
        final material = materialsToTransfer[i];
        movementHistoryData[i.toString()] = {
          "count": material['neededCount'].toString(),
          "date": date,
          "fromsiteid": _selectedSiteId,
          "managername": _managerNameController.text,
          "materialname": material['materialName'],
          "materialdisplayname": material['displayName'],
          "sitename": siteName,
          "projectname": _projectNameController.text,
          "supervisorname": _supervisorNameController.text,
          "timestamp": FieldValue.serverTimestamp(),
        };
      }
      batch.set(movementHistoryRef, movementHistoryData);

      // 2. Process each material
      for (final material in materialsToTransfer) {
        // Update materialsavailablity collection (decrease count) on the latest document for this material
        final latestEntry = materialsList.firstWhere(
          (mat) => mat['materialName'] == material['materialName'],
          orElse: () => <String, dynamic>{'count': 0, 'docId': material['materialName']},
        );
        final String docId = (latestEntry['docId'] ?? material['materialName'])
            .toString();
        final currentAvailableCount = (latestEntry['count'] ?? 0).toInt();
        final newAvailableCount =
            currentAvailableCount - material['neededCount'];

        final materialAvailabilityRef = FirestoreService.getCollection(
          'materialsavailablity',
        ).doc(docId);
        batch.update(materialAvailabilityRef, {"count": newAvailableCount});

        // Update materialatsite collection
        final materialAtSiteDocId =
            '${_selectedSiteId}_${material['materialName']}';
        final materialAtSiteRef = FirestoreService.getCollection(
          'materialatsite',
        ).doc(materialAtSiteDocId);

        // Check if we need to create or update
        final existingDoc = await materialAtSiteRef.get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data();
          final existingCount = (existingData?['count'] ?? 0).toInt();
          final newCount = existingCount + material['neededCount'];

          batch.update(materialAtSiteRef, {
            "count": newCount,
            "materialname": material['materialName'],
            "siteid": _selectedSiteId,
            "lastUpdated": FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(materialAtSiteRef, {
            "count": material['neededCount'],
            "materialname": material['materialName'],
            "siteid": _selectedSiteId,
            "timestamp": FieldValue.serverTimestamp(),
          });
        }

        // Update local materials list
        final materialIndex = materialsList.indexWhere(
          (mat) => mat['materialName'] == material['materialName'],
        );
        if (materialIndex != -1) {
          materialsList[materialIndex]['count'] = newAvailableCount;
        }
      }

      // Commit all batch operations
      await batch.commit();

      // Update UI state
      if (mounted) {
        setState(() {
          // Refresh available counts in UI
        });
      }

      // Close loading dialog and show success
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Materials have been transferred successfully.',
        );
        _clearAll();
      }
    } catch (e) {
      print('Error saving transfer data: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('Error occurred during transfer: $e');
      }
    }
  }

  // Site-to-Site transfer method
  Future<void> _saveSiteToSiteTransfer() async {
    if (!_validateSiteToSiteForm()) {
      return;
    }

    if (materialsToTransfer.isEmpty) {
      _showSnackBar('Please add at least one material to transfer');
      return;
    }

    try {
      final date = _fromDateController.text.isNotEmpty
          ? _fromDateController.text
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Processing site transfer...'),
              ],
            ),
          );
        },
      );

      // Use batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Process each material for materialatsite collection
      for (final material in materialsToTransfer) {
        final String matName = material['materialName'];
        final int moveCount = material['neededCount'];

        // Document references
        final fromDocRef = FirestoreService.getCollection(
          'materialatsite',
        ).doc('${_fromSiteId}_$matName');
        final toDocRef = FirestoreService.getCollection(
          'materialatsite',
        ).doc('${_toSiteId}_$matName');

        // Get current counts
        final fromSnap = await fromDocRef.get();
        final toSnap = await toDocRef.get();

        final int fromCurrent = _parseCount(fromSnap.data()?['count']);
        final int toCurrent = _parseCount(toSnap.data()?['count']);

        // Calculate new counts
        final int fromNew = (fromCurrent - moveCount) < 0
            ? 0
            : (fromCurrent - moveCount);
        final int toNew = toCurrent + moveCount;

        // Update FROM site document
        batch.set(fromDocRef, {
          'siteid': _fromSiteId,
          'Tositeid': _toSiteId,
          'count': fromNew,
          'materialName': matName,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update TO site document
        batch.set(toDocRef, {
          'siteid': _toSiteId,
          'Tositeid': _fromSiteId,
          'count': toNew,
          'materialName': matName,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2. Save to materialmovementhistory collection
      final movementId =
          '${_fromSiteId}_${_toSiteId}_${DateTime.now().millisecondsSinceEpoch}';
      final movementRef = FirestoreService.getCollection(
        'materialmovementhistory',
      ).doc(movementId);

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

      batch.set(movementRef, movementHistoryData);

      // Commit all batch operations
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Materials have been transferred successfully between sites.',
        );

        // Clear form and reload data
        setState(() {
          materialsToTransfer.clear();
          _selectedMaterialName = null;
          availableCount = 0;
          _neededCountController.clear();
        });

        _fromManagerController.clear();
        _toManagerController.clear();
        _fromDateController.clear();
        _toDateController.clear();

        // Reload site materials for updated counts
        await _loadSiteMaterialData(_fromSiteId);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      _showSnackBar('Error saving site-to-site transfer: $e');
      print('Site-to-Site transfer error: $e');
    }
  }

  // Site-to-Company transfer method
  Future<void> _saveSiteToCompanyTransfer() async {
    if (!_validateSiteToCompanyForm()) {
      return;
    }

    if (materialsToTransfer.isEmpty) {
      _showSnackBar('Please add at least one material to transfer');
      return;
    }

    try {
      final date = _siteToCompanyDateController.text.isNotEmpty
          ? _siteToCompanyDateController.text
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Processing site to company transfer...'),
              ],
            ),
          );
        },
      );

      // Use batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Save to materialmovementhistory collection
      final movementId =
          '${_selectedSiteId}_company_${DateTime.now().millisecondsSinceEpoch}';
      final movementRef = FirestoreService.getCollection(
        'materialmovementhistory',
      ).doc(movementId);

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

      batch.set(movementRef, movementHistoryData);

      // 2. Process each material
      for (final material in materialsToTransfer) {
        final String matName = material['materialName'];
        final int moveCount = material['neededCount'];

        // Update materialsavailablity collection (increase count)
        final latestEntry = materialsList.firstWhere(
          (mat) => mat['materialName'] == matName,
          orElse: () => <String, dynamic>{'count': 0, 'docId': matName},
        );
        final String docId = (latestEntry['docId'] ?? matName).toString();
        final currentAvailableCount = (latestEntry['count'] ?? 0).toInt();
        final newAvailableCount = currentAvailableCount + moveCount;

        final materialAvailabilityRef = FirestoreService.getCollection(
          'materialsavailablity',
        ).doc(docId);
        batch.set(materialAvailabilityRef, {
          "count": newAvailableCount,
          "materialname": matName,
          "lastupdated": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update materialatsite collection (decrease count at site)
        final materialAtSiteDocId = '${_selectedSiteId}_$matName';
        final materialAtSiteRef = FirestoreService.getCollection(
          'materialatsite',
        ).doc(materialAtSiteDocId);

        final existingDoc = await materialAtSiteRef.get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data();
          final existingCount = (existingData?['count'] ?? 0).toInt();
          final newCount = existingCount - moveCount;

          if (newCount <= 0) {
            // If count becomes 0 or negative, delete the document
            batch.delete(materialAtSiteRef);
          } else {
            batch.update(materialAtSiteRef, {
              "count": newCount,
              "materialname": matName,
              "siteid": _selectedSiteId,
              "lastUpdated": FieldValue.serverTimestamp(),
            });
          }
        }

        // Update local materials list
        final materialIndex = materialsList.indexWhere(
          (mat) => mat['materialName'] == material['materialName'],
        );
        if (materialIndex != -1) {
          materialsList[materialIndex]['count'] = newAvailableCount;
        }

        // Update local site materials list
        final siteMaterialIndex = siteMaterialsList.indexWhere(
          (mat) => mat['materialName'] == material['materialName'],
        );
        if (siteMaterialIndex != -1) {
          final newSiteCount =
              siteMaterialsList[siteMaterialIndex]['count'] - moveCount;
          if (newSiteCount <= 0) {
            siteMaterialsList.removeAt(siteMaterialIndex);
          } else {
            siteMaterialsList[siteMaterialIndex]['count'] = newSiteCount;
          }
        }
      }

      // Commit all batch operations
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Materials have been returned to company successfully.',
        );

        // Clear form
        _clearSiteToCompanyFields();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      _showSnackBar('Error saving site-to-company transfer: $e');
      print('Site-to-Company transfer error: $e');
    }
  }



  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: _transferMode == 0
          ? 'Company To Site Transfer'
          : _transferMode == 1
          ? 'Site To Site Transfer'
          : 'Site To Company Transfer',
      onBack: () => Navigator.pop(context),

      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toggle Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _transferMode = 0;
                        _selectedMaterialName = null;
                        availableCount = 0;
                        _neededCountController.clear();
                      });
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: _transferMode == 0
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      foregroundColor: _transferMode == 0
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: _transferMode == 0 ? 0 : 2,
                        ),
                      ),
                    ),
                    child: const Text(
                      'CTS',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _transferMode = 1;
                        _selectedMaterialName = null;
                        availableCount = 0;
                        _neededCountController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _transferMode == 1
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      foregroundColor: _transferMode == 1
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: _transferMode == 1 ? 0 : 2,
                        ),
                      ),
                    ),
                    child: const Text(
                      'STS',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _transferMode = 2;
                        _selectedMaterialName = null;
                        availableCount = 0;
                        _neededCountController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _transferMode == 2
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      foregroundColor: _transferMode == 2
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: _transferMode == 2 ? 0 : 2,
                        ),
                      ),
                    ),
                    child: const Text(
                      'STC',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_transferMode == 0) ...[
              // CompanyToSite UI (existing code)
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),

              // Manager Name
              _buildTextField(
                controller: _managerNameController,
                label: 'Manager Name *',
                hint: 'Enter manager name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Site ID Dropdown
              _buildSiteDropdown(),
              const SizedBox(height: 16),

              // Project Name
              _buildTextField(
                controller: _projectNameController,
                label: 'Project Name *',
                hint: 'Project name will auto-fill',
                enabled: false,
                icon: Icons.business,
              ),
              const SizedBox(height: 16),

              // Supervisor Name
              _buildTextField(
                controller: _supervisorNameController,
                label: 'Supervisor Name *',
                hint: 'Supervisor name will auto-fill',
                enabled: false,
                icon: Icons.supervisor_account,
              ),
              const SizedBox(height: 16),

              // Date
              _buildTextField(
                controller: _dateController,
                label: 'Date *',
                hint: 'Select date',
                onTap: () => _selectDate(context, _dateController),
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 24),

              // Materials Section
              _buildSectionHeader('Materials Information'),
              const SizedBox(height: 16),

              // Material Name Dropdown
              _buildMaterialDropdown(),
              const SizedBox(height: 16),

              // Count Information
              Row(
                children: [
                  Expanded(
                    child: _buildCountBox(
                      'Available Count',
                      availableCount.toString(),
                      availableCount > 0 ? Colors.green : Colors.red,
                      Icons.inventory,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _neededCountController,
                      label: 'Needed Count *',
                      hint: 'Enter count',
                      keyboardType: TextInputType.number,
                      icon: Icons.edit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add/Clear Material Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        'Add Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearMaterial,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      icon: const Icon(Icons.clear),
                      label: const Text(
                        'Clear Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Materials List
              if (materialsToTransfer.isNotEmpty) ...[
                _buildMaterialsList(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              _buildSectionHeader('Final Actions'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _transferMaterials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Transfer Materials',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Information Text
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'How it works:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildInfoItem('Available count decreases automatically'),
                    _buildInfoItem('Materials are added to site inventory'),
                    _buildInfoItem('Transfer history is saved for tracking'),
                    _buildInfoItem(
                      'Multiple materials can be transferred at once',
                    ),
                  ],
                ),
              ),
            ] else if (_transferMode == 1) ...[
              // SiteToSite UI (existing code)
              _buildSectionHeader('From Site'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fromManagerController,
                label: 'Manager Name *',
                hint: 'Enter manager name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              _buildSiteDropdownGeneric(
                selectedId: _fromSiteId,
                onChanged: (v) async {
                  if (v != null) {
                    setState(() {
                      _fromSiteId = v;
                      _selectedMaterialName = null;
                      availableCount = 0;
                      _neededCountController.clear();
                      _isLoadingMaterials = true;
                    });
                    await _fetchAndFillSiteDetails(v, mode: 1, isFromSite: true);
                    await _loadSiteMaterialData(v);
                  }
                },
                label: 'Site *',
              ),
              
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fromSiteNameController,
                label: 'Site Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fromProjectNameController,
                label: 'Project Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fromSupervisorController,
                label: 'Supervisor Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.supervisor_account,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fromDateController,
                label: 'Date *',
                hint: 'Select date',
                onTap: () => _selectDate(context, _fromDateController),
                icon: Icons.calendar_today,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('To Site'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _toManagerController,
                label: 'Manager Name *',
                hint: 'Enter manager name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
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
                label: 'Site *',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _toSiteNameController,
                label: 'Site Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _toProjectNameController,
                label: 'Project Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _toSupervisorController,
                label: 'Supervisor Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.supervisor_account,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _toDateController,
                label: 'Date *',
                hint: 'Select date',
                onTap: () => _selectDate(context, _toDateController),
                icon: Icons.calendar_today,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Materials'),
              const SizedBox(height: 16),
              _buildMaterialDropdown(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCountBox(
                      'Available Count',
                      availableCount.toString(),
                      availableCount > 0 ? Colors.green : Colors.red,
                      Icons.inventory,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _neededCountController,
                      label: 'Needed Count *',
                      hint: 'Enter count',
                      keyboardType: TextInputType.number,
                      icon: Icons.edit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        'Add Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearMaterial,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      icon: const Icon(Icons.clear),
                      label: const Text(
                        'Clear Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (materialsToTransfer.isNotEmpty) ...[
                _buildMaterialsList(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_validateSiteToSiteForm()) {
                          _saveSiteToSiteTransfer();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Transfer Materials',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_transferMode == 2) ...[
              // SiteToCompany UI
              _buildSectionHeader('Site Information'),
              const SizedBox(height: 16),

              // Manager Name
              _buildTextField(
                controller: _siteToCompanyManagerController,
                label: 'Manager Name *',
                hint: 'Enter manager name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Site ID Dropdown
              _buildSiteDropdownGeneric(
                selectedId: _selectedSiteId,
                onChanged: (v) async {
                  if (v != null) {
                    setState(() {
                      _selectedSiteId = v;
                      _selectedMaterialName = null;
                      availableCount = 0;
                      _neededCountController.clear();
                      _isLoadingMaterials = true;
                    });
                    await _fetchAndFillSiteDetails(v, mode: 2);
                    await _loadSiteMaterialData(v);
                  }
                },
                label: 'Site *',
              ),
              const SizedBox(height: 16),

              // Site Name
              _buildTextField(
                controller: _siteToCompanySiteNameController,
                label: 'Site Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),

              // Project Name
              _buildTextField(
                controller: _projectNameController,
                label: 'Project Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.business,
              ),
              const SizedBox(height: 16),

              // Supervisor Name
              _buildTextField(
                controller: _siteToCompanySupervisorController,
                label: 'Supervisor Name',
                hint: 'Auto-filled from selection',
                enabled: false,
                icon: Icons.supervisor_account,
              ),
              const SizedBox(height: 16),

              // Date
              _buildTextField(
                controller: _siteToCompanyDateController,
                label: 'Date *',
                hint: 'Select date',
                onTap: () => _selectDate(context, _siteToCompanyDateController),
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 24),

              // Materials Section
              _buildSectionHeader('Materials to Return'),
              const SizedBox(height: 16),

              // Material Name Dropdown
              _buildMaterialDropdown(),
              const SizedBox(height: 16),

              // Count Information
              Row(
                children: [
                  Expanded(
                    child: _buildCountBox(
                      'Available Count',
                      availableCount.toString(),
                      availableCount > 0 ? Colors.green : Colors.red,
                      Icons.inventory,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _neededCountController,
                      label: 'Return Count *',
                      hint: 'Enter count to return',
                      keyboardType: TextInputType.number,
                      icon: Icons.edit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add/Clear Material Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        'Add Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearMaterial,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      icon: const Icon(Icons.clear),
                      label: const Text(
                        'Clear Material',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Materials List
              if (materialsToTransfer.isNotEmpty) ...[
                _buildMaterialsList(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              _buildSectionHeader('Final Actions'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_validateSiteToCompanyForm()) {
                          _saveSiteToCompanyTransfer();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Return to Company',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Information Text
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'How it works:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildInfoItem(
                      'Materials are returned from site to company',
                    ),
                    _buildInfoItem('Company inventory increases automatically'),
                    _buildInfoItem('Site inventory decreases automatically'),
                    _buildInfoItem(
                      'Transfer history is saved with "SiteToCompany" info',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            filled: !enabled,
            fillColor: !enabled ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: Colors.grey.shade600)
                : null,
          ),
        ),
      ],
    );
  }

  // Generic site dropdown for Site-to-Site and Site-to-Company sections
  Widget _buildSiteDropdownGeneric({
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: _isLoadingSites
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text(
                      'Select Site',
                      style: TextStyle(color: Colors.grey),
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
        ),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Site *',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: _isLoadingSites
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSiteId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text(
                      'Select Site',
                      style: TextStyle(color: Colors.grey),
                    ),
                    items: sitesList.map((site) {
                      return DropdownMenuItem<String>(
                        value: site['siteId'],
                        child: Text(site['siteName'] ?? site['siteId']),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedSiteId = v;
                        });
                        _fetchAndFillSiteDetails(v, mode: 0);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material Name *',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: _isLoadingMaterials
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedMaterialName,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text(
                      'Select Material',
                      style: TextStyle(color: Colors.grey),
                    ),
                    items:
                        (_transferMode == 0 ? materialsList : siteMaterialsList)
                            .map((material) {
                              final materialName = material['materialName'];
                              final displayName = material['displayName'];
                              final count = material['count'] ?? 0;

                              return DropdownMenuItem<String>(
                                value: materialName,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(displayName ?? materialName),
                                    Text(
                                      'Available: $count',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: count > 0
                                            ? Colors.green
                                            : Colors.red,
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8.0),
            color: color.withOpacity(0.1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              ...materialsToTransfer.asMap().entries.map((entry) {
                final index = entry.key;
                final material = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: index < materialsToTransfer.length - 1
                        ? Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          )
                        : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      material['displayName'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Quantity: ${material['neededCount']} units',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeMaterial(index),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total Materials: ${materialsToTransfer.length}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
