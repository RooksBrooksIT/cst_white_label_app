import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class supervisorMaterialInfoScreen extends StatefulWidget {
  const supervisorMaterialInfoScreen({super.key});

  @override
  State<supervisorMaterialInfoScreen> createState() =>
      _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<supervisorMaterialInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toManagerController = TextEditingController();
  final TextEditingController _toSiteNameController = TextEditingController();
  final TextEditingController _toSupervisorController = TextEditingController();
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

  // Loading states
  bool _isLoadingSites = true;
  bool _isLoadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _siteToCompanyDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadSiteData();
    _loadMaterialData();
  }

  @override
  void dispose() {
    // Site-to-Site controllers
    _fromManagerController.dispose();
    _fromSiteNameController.dispose();
    _fromSupervisorController.dispose();
    _fromDateController.dispose();
    _toManagerController.dispose();
    _toSiteNameController.dispose();
    _toSupervisorController.dispose();
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

  // Load site data from siteSupervisorMap collection
  Future<void> _loadSiteData() async {
    try {
      final querySnapshot =
          await _firestore.collection('siteSupervisorMap').get();

      if (mounted) {
        setState(() {
          sitesList = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'siteId': doc.id,
              'siteName': data['site'] ?? doc.id,
              'projectName': data['projectName'] ?? '',
              'supervisorName':
                  data['supervisor'] ?? data['supervisorName'] ?? '',
            };
          }).toList();
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      print('Error loading site data: $e');
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
      final querySnapshot =
          await _firestore.collection('materialsavailablity').get();

      // Group by materialname and pick the latest entry (by lastupdated) for each
      final Map<String, Map<String, dynamic>> latestByName = {};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final name = (data['materialname'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final count = _parseCount(data['count']);
        final lastUpdatedMs = _tsMillis(data['lastupdated']);

        if (!latestByName.containsKey(name)) {
          latestByName[name] = {
            'docId': doc.id,
            'materialName': name, // use field value as the logical key
            'displayName': name,
            'count': count,
            'lastupdatedMillis': lastUpdatedMs,
          };
        } else {
          final existing = latestByName[name]!;
          final existingTs = existing['lastupdatedMillis'];
          // Replace if this doc has a newer timestamp in millis
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
        ..sort((a, b) => (a['displayName'] as String)
            .toLowerCase()
            .compareTo((b['displayName'] as String).toLowerCase()));

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
      final querySnapshot = await _firestore
          .collection('materialatsite')
          .where('siteid', isEqualTo: siteId)
          .get();

      final list = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            final name = (data['materialname'] ?? '').toString().trim();
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
        ..sort((a, b) => (a['displayName'] as String)
            .toLowerCase()
            .compareTo((b['displayName'] as String).toLowerCase()));

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
        orElse: () => {},
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
        final source =
            _transferMode == 0 ? siteMaterialsList : siteMaterialsList;
        final selectedMaterial = source.firstWhere(
          (material) => material['materialName'] == materialName,
          orElse: () => {},
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
    final source = siteMaterialsList;
    final selectedMaterial = source.firstWhere(
      (material) => material['materialName'] == _selectedMaterialName,
      orElse: () => {},
    );
    final displayName =
        selectedMaterial['displayName'] ?? _selectedMaterialName!;

    // Check if material already exists in the list
    final existingIndex = materialsToTransfer
        .indexWhere((item) => item['materialName'] == _selectedMaterialName);

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
      _fromManagerController.clear();
      _toManagerController.clear();
      _fromSiteId = null;
      _toSiteId = null;
      _fromSiteNameController.clear();
      _toSiteNameController.clear();
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
      _siteToCompanyManagerController.clear();
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

  String _getSelectedSiteName(String? siteId) {
    if (siteId == null) return '';
    final selectedSite = sitesList.firstWhere(
      (site) => site['siteId'] == siteId,
      orElse: () => {},
    );
    return selectedSite['siteName'] ?? siteId;
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
      final batch = _firestore.batch();

      // 1. Process each material for materialatsite collection
      for (final material in materialsToTransfer) {
        final String matName = material['materialName'];
        final int moveCount = material['neededCount'];

        // Document references
        final fromDocRef = _firestore
            .collection('materialatsite')
            .doc('${_fromSiteId}_$matName');
        final toDocRef = _firestore
            .collection('materialatsite')
            .doc('${_toSiteId}_$matName');

        // Get current counts
        final fromSnap = await fromDocRef.get();
        final toSnap = await toDocRef.get();

        final int fromCurrent = _parseCount(fromSnap.data()?['count']);
        final int toCurrent = _parseCount(toSnap.data()?['count']);

        // Calculate new counts
        final int fromNew =
            (fromCurrent - moveCount) < 0 ? 0 : (fromCurrent - moveCount);
        final int toNew = toCurrent + moveCount;

        // Update FROM site document
        batch.set(
          fromDocRef,
          {
            'siteid': _fromSiteId,
            'Tositeid': _toSiteId,
            'count': fromNew,
            'materialName': matName,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Update TO site document
        batch.set(
          toDocRef,
          {
            'siteid': _toSiteId,
            'Tositeid': _fromSiteId,
            'count': toNew,
            'materialName': matName,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 2. Save to materialmovementhistory collection
      final movementId =
          '${_fromSiteId}_${_toSiteId}_${DateTime.now().millisecondsSinceEpoch}';
      final movementRef =
          _firestore.collection('materialmovementhistory').doc(movementId);

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
          "timestamp": FieldValue.serverTimestamp(),
        };
      }

      batch.set(movementRef, movementHistoryData);

      // Commit all batch operations
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
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
      final batch = _firestore.batch();

      // 1. Save to materialmovementhistory collection
      final movementId =
          '${_selectedSiteId}_company_${DateTime.now().millisecondsSinceEpoch}';
      final movementRef =
          _firestore.collection('materialmovementhistory').doc(movementId);

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
          orElse: () => {'count': 0, 'docId': matName},
        );
        final String docId = (latestEntry['docId'] ?? matName).toString();
        final currentAvailableCount = (latestEntry['count'] ?? 0).toInt();
        final newAvailableCount = currentAvailableCount + moveCount;

        final materialAvailabilityRef =
            _firestore.collection('materialsavailablity').doc(docId);
        batch.set(
          materialAvailabilityRef,
          {
            "count": newAvailableCount,
            "materialname": matName,
            "lastupdated": FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Update materialatsite collection (decrease count at site)
        final materialAtSiteDocId = '${_selectedSiteId}_$matName';
        final materialAtSiteRef =
            _firestore.collection('materialatsite').doc(materialAtSiteDocId);

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
            (mat) => mat['materialName'] == material['materialName']);
        if (materialIndex != -1) {
          materialsList[materialIndex]['count'] = newAvailableCount;
        }

        // Update local site materials list
        final siteMaterialIndex = siteMaterialsList.indexWhere(
            (mat) => mat['materialName'] == material['materialName']);
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
        _showSuccessDialogSiteToCompany();

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

  void _showSuccessDialogSiteToSite() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Transfer Successful!',
            style: TextStyle(color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Materials have been transferred successfully between sites.'),
              const SizedBox(height: 12),
              Text('From Site: ${_fromSiteNameController.text}'),
              Text('To Site: ${_toSiteNameController.text}'),
              Text('Date: ${_fromDateController.text}'),
              const SizedBox(height: 8),
              const Text(
                'Transferred Materials:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...materialsToTransfer
                  .map((material) => Text(
                      '- ${material['displayName']}: ${material['neededCount']} units'))
                  .toList(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '✓ From site inventory decreased\n✓ To site inventory increased\n✓ Transfer history saved',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSiteToSiteFields();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialogSiteToCompany() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Transfer Successful!',
            style: TextStyle(color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Materials have been returned to company successfully.'),
              const SizedBox(height: 12),
              Text('From Site: ${_siteToCompanySiteNameController.text}'),
              Text('Date: ${_siteToCompanyDateController.text}'),
              const SizedBox(height: 8),
              const Text(
                'Returned Materials:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...materialsToTransfer
                  .map((material) => Text(
                      '- ${material['displayName']}: ${material['neededCount']} units'))
                  .toList(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '✓ Company inventory increased\n✓ Site inventory decreased\n✓ Transfer history saved',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSiteToCompanyFields();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
      BuildContext context, TextEditingController controller) async {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _transferMode == 0
              ? 'Site To Site Transfer'
              : 'Site To Company Transfer',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF772323),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                          ? const Color(0xFF772323)
                          : Colors.white,
                      foregroundColor: _transferMode == 0
                          ? Colors.white
                          : const Color(0xFF772323),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: const Color(0xFF772323),
                          width: _transferMode == 0 ? 0 : 2,
                        ),
                      ),
                    ),
                    child: const Text('SiteToSite',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
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
                          ? const Color(0xFF772323)
                          : Colors.white,
                      foregroundColor: _transferMode == 1
                          ? Colors.white
                          : const Color(0xFF772323),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: const Color(0xFF772323),
                          width: _transferMode == 1 ? 0 : 2,
                        ),
                      ),
                    ),
                    child: const Text('SiteToCompany',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_transferMode == 0) ...[
              // SiteToSite UI
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
                  final site = sitesList.firstWhere(
                    (s) => s['siteId'] == v,
                    orElse: () => {},
                  );
                  setState(() {
                    _fromSiteId = v;
                    _fromSiteNameController.text =
                        site['siteName']?.toString() ?? '';
                    _fromSupervisorController.text =
                        site['supervisorName']?.toString() ?? '';
                    // Reset material selection for SiteToSite
                    _selectedMaterialName = null;
                    availableCount = 0;
                    _neededCountController.clear();
                    _isLoadingMaterials = true;
                  });
                  await _loadSiteMaterialData(v);
                },
                label: 'Site ID *',
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
                controller: _fromSupervisorController,
                label: 'Supervisor Name',
                hint: '',
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
                  final site = sitesList.firstWhere(
                    (s) => s['siteId'] == v,
                    orElse: () => {},
                  );
                  setState(() {
                    _toSiteId = v;
                    _toSiteNameController.text =
                        site['siteName']?.toString() ?? '';
                    _toSupervisorController.text =
                        site['supervisorName']?.toString() ?? '';
                  });
                },
                label: 'Site ID *',
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
                        backgroundColor: const Color(0xFF772323),
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
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Cancel Transfer',
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
                        backgroundColor: const Color(0xFF772323),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Transfer Materials',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_transferMode == 1) ...[
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
                    // Reset material selection
                    _selectedMaterialName = null;
                    availableCount = 0;
                    _neededCountController.clear();
                    _isLoadingMaterials = true;
                  });
                  await _loadSiteMaterialData(v);
                },
                label: 'Site ID *',
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
                        backgroundColor: const Color(0xFF772323),
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
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Cancel Transfer',
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
                        backgroundColor: const Color(0xFF772323),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Return to Company',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
                              color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildInfoItem(
                        'Materials are returned from site to company'),
                    _buildInfoItem('Company inventory increases automatically'),
                    _buildInfoItem('Site inventory decreases automatically'),
                    _buildInfoItem(
                        'Transfer history is saved with "SiteToCompany" info'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF772323),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
                      Text('Loading sites...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Select Site',
                        style: TextStyle(color: Colors.grey)),
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

  Widget _buildMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material Name *',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
                      Text('Loading materials...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedMaterialName,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Select Material',
                        style: TextStyle(color: Colors.grey)),
                    items: siteMaterialsList.map((material) {
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
                                color: count > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _onMaterialChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCountBox(
      String title, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
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
                            bottom: BorderSide(color: Colors.grey.shade200))
                        : null,
                  ),
                  child: ListTile(
                    leading:
                        const Icon(Icons.inventory, color: Color(0xFF772323)),
                    title: Text(
                      material['displayName'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle:
                        Text('Quantity: ${material['neededCount']} units'),
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
              fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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
