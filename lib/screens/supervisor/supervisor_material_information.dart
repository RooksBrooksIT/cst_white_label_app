import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/services/firestore_service.dart';
import '/utils/app_theme.dart';

class SupervisorMaterialInfoScreen extends StatefulWidget {
  const SupervisorMaterialInfoScreen({super.key});

  @override
  State<SupervisorMaterialInfoScreen> createState() =>
      _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<SupervisorMaterialInfoScreen> {
  // Removed unused _firestore field

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

  // Loading states
  bool _isLoadingSites = true;
  bool _isLoadingMaterials = true;

  @override
  void initState() {
    super.initState();
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

  // Load site data from siteSupervisorMap collection
  Future<void> _loadSiteData() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).get();

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
      final querySnapshot = await FirestoreService.getCollection(
        'materialsavailablity',
      ).get();

      // Group by materialname and pick the latest entry (by lastupdated) for each
      final Map<String, Map<String, dynamic>> latestByName = {};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Check for both materialName and materialname
        final name = (data['materialName'] ?? data['materialname'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        
        final count = _parseCount(data['count']);
        // Check for both lastupdated and lastUpdated
        final lastUpdatedMs = _tsMillis(data['lastupdated'] ?? data['lastUpdated']);

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
                final name = (data['materialName'] ?? data['materialname'] ?? '').toString().trim();
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

  // Handle material selection change
  void _onMaterialChanged(String? materialName) {
    if (materialName == _selectedMaterialName) return;

    setState(() {
      _selectedMaterialName = materialName;
      if (materialName != null) {
        Map<String, dynamic> selectedMaterial = siteMaterialsList.firstWhere(
          (material) => (material['materialName'] ?? material['displayName']) == materialName,
          orElse: () => {},
        );
        if (selectedMaterial.isEmpty) {
          selectedMaterial = materialsList.firstWhere(
            (material) => (material['materialName'] ?? material['displayName']) == materialName,
            orElse: () => {},
          );
        }
        if (selectedMaterial.isNotEmpty) {
          availableCount = _parseCount(selectedMaterial['count'] ?? selectedMaterial['availableCount']);
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
          orElse: () => {'count': 0, 'docId': matName},
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
              onTap: () => setState(() {
                _transferMode = 0;
                _selectedMaterialName = null;
                availableCount = 0;
                _neededCountController.clear();
              }),
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
              onTap: () => setState(() {
                _transferMode = 1;
                _selectedMaterialName = null;
                availableCount = 0;
                _neededCountController.clear();
              }),
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
                    availableCount.toString(),
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
                onPressed: () {
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
                child: const Text('TRANSFER MATERIALS',
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
                    availableCount.toString(),
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
                onPressed: () {
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
                child: const Text('RETURN TO COMPANY',
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
    VoidCallback? onTap,
    required Color primaryColor,
  }) {
    return TextField(
      controller: controller,
      readOnly: onTap != null || !enabled,
      onTap: onTap,
      keyboardType: keyboardType,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedId,
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
            return DropdownMenuItem<String>(
              value: site['siteId'],
              child: Text(
                site['siteName'] ?? site['siteId'],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedMaterialName,
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
          items: (siteMaterialsList.isNotEmpty
                  ? siteMaterialsList
                  : materialsList)
              .map((material) {
            final materialName = material['materialName'];
            final displayName = material['displayName'];
            final count =
                _parseCount(material['count'] ?? material['availableCount']);

            return DropdownMenuItem<String>(
              value: materialName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayName ?? materialName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
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
