import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import '../utils/app_theme.dart';
import 'package:demo_cst/services/firestore_service.dart';

class SupervisorMaterialInfoScreen extends StatefulWidget {
  const SupervisorMaterialInfoScreen({super.key});

  @override
  State<SupervisorMaterialInfoScreen> createState() =>
      _MaterialInfoScreenState();
}

class _MaterialInfoScreenState extends State<SupervisorMaterialInfoScreen> {
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
          await FirestoreService.getCollection('siteSupervisorMap').get();

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
          await FirestoreService.getCollection('materialsavailablity').get();

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
          FirestoreService.getCollection('materialmovementhistory').doc(movementId);

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
          FirestoreService.getCollection('materialmovementhistory').doc(movementId);

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
            FirestoreService.getCollection('materialsavailablity').doc(docId);
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
            FirestoreService.getCollection('materialatsite').doc(materialAtSiteDocId);

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
      backgroundColor: AppTheme.isDark(context) ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Material Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 20),
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF772323),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: Responsive.scaleH(context, 22)),
            onPressed: () => _showHelpDialog(context),
          ),
          SizedBox(width: Responsive.scaleH(context, 8)),
        ],
      ),
      body: _isLoadingSites || _isLoadingMaterials
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF772323)))
          : Column(
              children: [
                _buildModeToggle(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(Responsive.scaleH(context, 16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_transferMode == 0) ..._buildSiteToSiteUI() else ..._buildSiteToCompanyUI(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeToggle() {
    return Card(
      color: AppTheme.isDark(context) ? Colors.grey[850] : Colors.white,
      margin: EdgeInsets.zero, // Remove default card margin
      elevation: AppTheme.isDark(context) ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
        side: BorderSide(
          color: AppTheme.isDark(context) ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.scaleH(context, 16),
          vertical: Responsive.scaleV(context, 12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                title: 'Site to Site',
                isSelected: _transferMode == 0,
                onTap: () => setState(() {
                  _transferMode = 0;
                  _selectedMaterialName = null;
                  availableCount = 0;
                  _neededCountController.clear();
                }),
              ),
            ),
            SizedBox(width: Responsive.scaleH(context, 12)),
            Expanded(
              child: _buildToggleButton(
                title: 'Return to Company',
                isSelected: _transferMode == 1,
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
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 10)),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF772323) : Colors.transparent,
          borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
          border: Border.all(
            color: const Color(0xFF772323),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF772323),
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 14),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSiteToSiteUI() {
    return [
      // SiteToSite UI
      _buildSectionHeader('From Site'),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _fromManagerController,
        label: 'Manager Name *',
        hint: 'Enter manager name',
        icon: Icons.person,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildSiteDropdownGeneric(
        'Site ID *',
        _fromSiteId,
        sitesList,
        (v) async {
          final site = sitesList.firstWhere(
            (s) => s['siteId'] == v,
            orElse: () => {},
          );
          setState(() {
            _fromSiteId = v;
            _fromSiteNameController.text = site['siteName']?.toString() ?? '';
            _fromSupervisorController.text = site['supervisorName']?.toString() ?? '';
            // Reset material selection for SiteToSite
            _selectedMaterialName = null;
            availableCount = 0;
            _neededCountController.clear();
            _isLoadingMaterials = true;
          });
          await _loadSiteMaterialData(v);
        },
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _fromSiteNameController,
        label: 'Site Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.location_on,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _fromSupervisorController,
        label: 'Supervisor Name',
        hint: '',
        enabled: false,
        icon: Icons.supervisor_account,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _fromDateController,
        label: 'Date *',
        hint: 'Select date',
        onTap: () => _selectDate(context, _fromDateController),
        icon: Icons.calendar_today,
      ),

      SizedBox(height: Responsive.scaleV(context, 24)),
      _buildSectionHeader('To Site'),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _toManagerController,
        label: 'Manager Name *',
        hint: 'Enter manager name',
        icon: Icons.person,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildSiteDropdownGeneric(
        'Site ID *',
        _toSiteId,
        sitesList,
        (v) {
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
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _toSiteNameController,
        label: 'Site Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.location_on,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _toSupervisorController,
        label: 'Supervisor Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.supervisor_account,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _toDateController,
        label: 'Date *',
        hint: 'Select date',
        onTap: () => _selectDate(context, _toDateController),
        icon: Icons.calendar_today,
      ),

      SizedBox(height: Responsive.scaleV(context, 24)),
      _buildSectionHeader('Materials'),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildMaterialDropdown(),
      SizedBox(height: Responsive.scaleV(context, 16)),
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
          SizedBox(width: Responsive.scaleH(context, 16)),
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
      SizedBox(height: Responsive.scaleV(context, 16)),

      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addMaterial,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF772323),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              icon: Icon(Icons.add_circle_outline, size: Responsive.scaleH(context, 20)),
              label: Text(
                'Add Material',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearMaterial,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 12)),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              icon: Icon(Icons.clear, size: Responsive.scaleH(context, 20)),
              label: Text(
                'Clear Material',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      if (materialsToTransfer.isNotEmpty) ...[
        _buildMaterialsList(),
        SizedBox(height: Responsive.scaleV(context, 16)),
      ],

      SizedBox(height: Responsive.scaleV(context, 24)),
      _buildSectionHeader('Final Actions'),
      SizedBox(height: Responsive.scaleV(context, 16)),

      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 16)),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
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
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
                elevation: 2,
              ),
              child: Text(
                'Transfer Materials',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: Responsive.scaleV(context, 20)),
      _buildTransferInfoBox(
        'Materials will be transferred directly between the selected sites. Inventory levels will be updated for both sites.',
      ),
    ];
  }

  List<Widget> _buildSiteToCompanyUI() {
    return [
      // SiteToCompany UI
      _buildSectionHeader('Site Information'),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildTextField(
        controller: _siteToCompanyManagerController,
        label: 'Manager Name *',
        hint: 'Enter manager name',
        icon: Icons.person,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildSiteDropdownGeneric(
        'Site ID *',
        _selectedSiteId,
        sitesList,
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
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildTextField(
        controller: _siteToCompanySiteNameController,
        label: 'Site Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.location_on,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildTextField(
        controller: _siteToCompanySupervisorController,
        label: 'Supervisor Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.supervisor_account,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildTextField(
        controller: _siteToCompanyDateController,
        label: 'Date *',
        hint: 'Select date',
        onTap: () => _selectDate(context, _siteToCompanyDateController),
        icon: Icons.calendar_today,
      ),
      SizedBox(height: Responsive.scaleV(context, 24)),

      _buildSectionHeader('Materials to Return'),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildMaterialDropdown(),
      SizedBox(height: Responsive.scaleV(context, 16)),

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
          SizedBox(width: Responsive.scaleH(context, 16)),
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
      SizedBox(height: Responsive.scaleV(context, 16)),

      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addMaterial,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF772323),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              icon: Icon(Icons.add_circle_outline, size: Responsive.scaleH(context, 20)),
              label: Text(
                'Add Material',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearMaterial,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 12)),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              icon: Icon(Icons.clear, size: Responsive.scaleH(context, 20)),
              label: Text(
                'Clear Material',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      if (materialsToTransfer.isNotEmpty) ...[
        _buildMaterialsList(),
        SizedBox(height: Responsive.scaleV(context, 16)),
      ],

      SizedBox(height: Responsive.scaleV(context, 24)),

      _buildSectionHeader('Final Actions'),
      SizedBox(height: Responsive.scaleV(context, 16)),

      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 16)),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
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
                padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                ),
                elevation: 2,
              ),
              child: Text(
                'Return to Company',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: Responsive.scaleV(context, 20)),
      _buildTransferInfoBox(
        'Materials are returned from site to company. Inventory levels will be updated automatically.',
      ),
    ];
  }

  void _showSuccessDialogSiteToSite() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12))),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: Responsive.scaleH(context, 28)),
              SizedBox(width: Responsive.scaleH(context, 12)),
              Text(
                'Transfer Successful!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 20),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  'Materials have been transferred successfully between sites.',
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                ),
                SizedBox(height: Responsive.scaleV(context, 16)),
                _buildInfoItem('From Site: ${_fromSiteNameController.text}'),
                _buildInfoItem('To Site: ${_toSiteNameController.text}'),
                _buildInfoItem('Date: ${_fromDateController.text}'),
                SizedBox(height: Responsive.scaleV(context, 12)),
                Text(
                  'Transferred Materials:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 14),
                    color: const Color(0xFF772323),
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 8)),
                ...materialsToTransfer.map((material) => Padding(
                      padding: EdgeInsets.only(bottom: Responsive.scaleV(context, 4)),
                      child: Text(
                        '• ${material['displayName']}: ${material['neededCount']} units',
                        style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                      ),
                    )),
                SizedBox(height: Responsive.scaleV(context, 16)),
                Container(
                  padding: EdgeInsets.all(Responsive.scaleH(context, 12)),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                    border: Border.all(color: Colors.green.withOpacity(0.1)),
                  ),
                  child: Text(
                    '✓ Inventories Updated\n✓ History Saved',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      color: Colors.green[800],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSiteToSiteFields();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 16),
                  color: const Color(0xFF772323),
                ),
              ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12))),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: Responsive.scaleH(context, 28)),
              SizedBox(width: Responsive.scaleH(context, 12)),
              Text(
                'Transfer Successful!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 20),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  'Materials have been returned to company successfully.',
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                ),
                SizedBox(height: Responsive.scaleV(context, 16)),
                _buildInfoItem('From Site: ${_siteToCompanySiteNameController.text}'),
                _buildInfoItem('Date: ${_siteToCompanyDateController.text}'),
                SizedBox(height: Responsive.scaleV(context, 12)),
                Text(
                  'Returned Materials:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 14),
                    color: const Color(0xFF772323),
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 8)),
                ...materialsToTransfer.map((material) => Padding(
                      padding: EdgeInsets.only(bottom: Responsive.scaleV(context, 4)),
                      child: Text(
                        '• ${material['displayName']}: ${material['neededCount']} units',
                        style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                      ),
                    )),
                SizedBox(height: Responsive.scaleV(context, 16)),
                Container(
                  padding: EdgeInsets.all(Responsive.scaleH(context, 12)),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
                    border: Border.all(color: Colors.green.withOpacity(0.1)),
                  ),
                  child: Text(
                    '✓ Company Inventory Increased\n✓ History Saved',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      color: Colors.green[800],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSiteToCompanyFields();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 16),
                  color: const Color(0xFF772323),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF772323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8))),
        margin: EdgeInsets.all(Responsive.scaleH(context, 16)),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12))),
        title: Text(
          'About Material Transfer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 18),
            color: const Color(0xFF772323),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              _buildHelpItem(Icons.sync_alt, 'Site to Site', 'Transfer materials between two different project sites.'),
              SizedBox(height: Responsive.scaleV(context, 12)),
              _buildHelpItem(Icons.business, 'Return to Company', 'Send materials from a site back to the central company inventory.'),
              SizedBox(height: Responsive.scaleV(context, 12)),
              _buildHelpItem(Icons.inventory, 'Real-time Tracking', 'Inventory levels for all sites are updated automatically upon transfer confirmation.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: Responsive.fontSize(context, 16),
                color: const Color(0xFF772323),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF772323), size: Responsive.scaleH(context, 20)),
        SizedBox(width: Responsive.scaleH(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 14),
                ),
              ),
              SizedBox(height: Responsive.scaleV(context, 2)),
              Text(
                description,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Consolidated UI Helper Methods ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    final bool isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        TextField(
          controller: controller,
          enabled: enabled,
          onTap: onTap,
          readOnly: onTap != null || !enabled,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: Responsive.fontSize(context, 14),
            ),
            prefixIcon: icon != null
                ? Icon(icon, color: const Color(0xFF772323), size: Responsive.scaleH(context, 20))
                : null,
            filled: true,
            fillColor: isDark 
                ? (enabled ? Colors.grey[850] : Colors.grey[900])
                : (enabled ? Colors.white : Colors.grey[100]),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.scaleH(context, 16),
              vertical: Responsive.scaleV(context, 12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scaleH(context, 10)),
              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scaleH(context, 10)),
              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scaleH(context, 10)),
              borderSide: const BorderSide(color: Color(0xFF772323), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scaleH(context, 10)),
              borderSide: BorderSide(color: isDark ? Colors.grey[900]! : Colors.grey[200]!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleH(context, 12),
        vertical: Responsive.scaleV(context, 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF772323).withOpacity(0.1),
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
        border: Border(
          left: BorderSide(color: const Color(0xFF772323), width: Responsive.scaleH(context, 4)),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          fontWeight: FontWeight.bold,
          color: const Color(0xFF772323),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCountBox(String title, String value, Color color, IconData icon) {
    final bool isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 14),
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(Responsive.scaleH(context, 14)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(Responsive.scaleH(context, 10)),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.scaleH(context, 8)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: Responsive.scaleH(context, 20)),
              ),
              SizedBox(width: Responsive.scaleH(context, 12)),
              Text(
                value,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
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

  Widget _buildTransferInfoBox(String text) {
    return Container(
      padding: EdgeInsets.all(Responsive.scaleH(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xFF772323).withOpacity(0.05),
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
        border: Border.all(color: const Color(0xFF772323).withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF772323), size: Responsive.scaleH(context, 20)),
          SizedBox(width: Responsive.scaleH(context, 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 12),
                color: AppTheme.isDark(context) ? Colors.grey[400] : Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList() {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Materials to Transfer:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 16),
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
            color: isDark ? Colors.grey[850] : Colors.white,
          ),
          child: Column(
            children: [
              ...materialsToTransfer.asMap().entries.map((entry) {
                final index = entry.key;
                final material = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: index < materialsToTransfer.length - 1
                        ? Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!))
                        : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory,
                      color: const Color(0xFF772323),
                      size: Responsive.scaleH(context, 24),
                    ),
                    title: Text(
                      material['displayName'],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: Responsive.fontSize(context, 14),
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Quantity: ${material['neededCount']} units',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: Responsive.scaleH(context, 20),
                      ),
                      onPressed: () => _removeMaterial(index),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        Text(
          'Total Materials: ${materialsToTransfer.length}',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 12),
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.scaleV(context, 4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: const Color(0xFF772323))),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: AppTheme.isDark(context) ? Colors.grey[300] : Colors.grey[800],
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
      ValueChanged<String?> onChanged) {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 14),
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[400]!),
            borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
            color: isDark ? Colors.grey[850] : Colors.white,
          ),
          child: _isLoadingSites
              ? Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.scaleH(context, 12),
                    vertical: Responsive.scaleV(context, 16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: Responsive.scaleH(context, 16),
                        height: Responsive.scaleH(context, 16),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF772323)),
                      ),
                      SizedBox(width: Responsive.scaleH(context, 12)),
                      Text(
                        'Loading sites...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleH(context, 12),
                      vertical: Responsive.scaleV(context, 4),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedId,
                      isExpanded: true,
                      dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                      hint: Text(
                        'Select Site',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                      items: sitesList.map((site) {
                        return DropdownMenuItem<String>(
                          value: site['siteId'],
                          child: Text(
                            site['siteName'] ?? site['siteId'],
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMaterialDropdown() {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material Name *',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 14),
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.scaleV(context, 8)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[400]!),
            borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
            color: isDark ? Colors.grey[850] : Colors.white,
          ),
          child: _isLoadingMaterials
              ? Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.scaleH(context, 12),
                    vertical: Responsive.scaleV(context, 16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: Responsive.scaleH(context, 16),
                        height: Responsive.scaleH(context, 16),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF772323)),
                      ),
                      SizedBox(width: Responsive.scaleH(context, 12)),
                      Text(
                        'Loading materials...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleH(context, 12),
                      vertical: Responsive.scaleV(context, 4),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMaterialName,
                      isExpanded: true,
                      dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                      hint: Text(
                        'Select Material',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
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
                              Text(
                                displayName ?? materialName,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 14),
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                'Available: $count',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 12),
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
        ),
      ],
    );
  }
}
