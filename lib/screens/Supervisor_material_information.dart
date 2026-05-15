import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

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
        final source = _transferMode == 0
            ? siteMaterialsList
            : siteMaterialsList;
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
    return GlassScaffold(
      title: 'Material Information',
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          icon: Icon(Icons.help_outline, size: Responsive.scaleH(context, 22)),
          onPressed: () => _showHelpDialog(context),
        ),
        SizedBox(width: Responsive.scaleH(context, 8)),
      ],
      body: _isLoadingSites || _isLoadingMaterials
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
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
                        if (_transferMode == 0)
                          ..._buildSiteToSiteUI()
                        else
                          ..._buildSiteToCompanyUI(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleH(context, 16),
        vertical: Responsive.scaleV(context, 8),
      ),
      child: GlassCard(
        padding: EdgeInsets.all(Responsive.scaleH(context, 4)),
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
            SizedBox(width: Responsive.scaleH(context, 8)),
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
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: Responsive.scaleV(context, 10)),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
          border: isSelected
              ? null
              : Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), width: 1.5),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 13),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSiteToSiteUI() {
    return [
      _buildSectionHeader('From Site'),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildTextField(
        controller: _fromManagerController,
        label: 'Manager Name *',
        hint: 'Enter manager name',
        icon: Icons.person,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),
      _buildSiteDropdownGeneric('Site ID *', _fromSiteId, sitesList, (v) async {
        final site = sitesList.firstWhere(
          (s) => s['siteId'] == v,
          orElse: () => {},
        );
        setState(() {
          _fromSiteId = v;
          _fromSiteNameController.text = site['siteName']?.toString() ?? '';
          _fromProjectNameController.text = site['projectName']?.toString() ?? '';
          _fromSupervisorController.text =
              site['supervisorName']?.toString() ?? '';
          _selectedMaterialName = null;
          availableCount = 0;
          _neededCountController.clear();
          _isLoadingMaterials = true;
        });
        await _loadSiteMaterialData(v);
      }),
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
        controller: _fromProjectNameController,
        label: 'Project Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.business,
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
      _buildSiteDropdownGeneric('Site ID *', _toSiteId, sitesList, (v) {
        final site = sitesList.firstWhere(
          (s) => s['siteId'] == v,
          orElse: () => {},
        );
        setState(() {
          _toSiteId = v;
          _toSiteNameController.text = site['siteName']?.toString() ?? '';
          _toProjectNameController.text = site['projectName']?.toString() ?? '';
          _toSupervisorController.text =
              site['supervisorName']?.toString() ?? '';
        });
      }),
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
        controller: _toProjectNameController,
        label: 'Project Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.business,
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
              availableCount > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
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
            child: GlassButton(onPressed: _addMaterial, label: 'Add Material'),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: GlassButton(
              onPressed: _clearMaterial,
              label: 'Clear',
              isSecondary: true,
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
            child: GlassButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
              isSecondary: true,
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: GlassButton(
              onPressed: () {
                if (_validateSiteToSiteForm()) {
                  _saveSiteToSiteTransfer();
                }
              },
              label: 'Transfer',
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
      _buildSectionHeader('Site Information'),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildTextField(
        controller: _siteToCompanyManagerController,
        label: 'Manager Name *',
        hint: 'Enter manager name',
        icon: Icons.person,
      ),
      SizedBox(height: Responsive.scaleV(context, 16)),

      _buildSiteDropdownGeneric('Site ID *', _selectedSiteId, sitesList, (
        v,
      ) async {
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
          _projectNameController.text = site['projectName']?.toString() ?? '';
          _selectedMaterialName = null;
          availableCount = 0;
          _neededCountController.clear();
          _isLoadingMaterials = true;
        });
        await _loadSiteMaterialData(v);
      }),
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
        controller: _projectNameController,
        label: 'Project Name',
        hint: 'Auto-filled from selection',
        enabled: false,
        icon: Icons.business,
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
              availableCount > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
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
            child: GlassButton(onPressed: _addMaterial, label: 'Add Material'),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: GlassButton(
              onPressed: _clearMaterial,
              label: 'Clear',
              isSecondary: true,
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
            child: GlassButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
              isSecondary: true,
            ),
          ),
          SizedBox(width: Responsive.scaleH(context, 16)),
          Expanded(
            child: GlassButton(
              onPressed: () {
                if (_validateSiteToCompanyForm()) {
                  _saveSiteToCompanyTransfer();
                }
              },
              label: 'Return',
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
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassCard(
            padding: EdgeInsets.all(Responsive.scaleH(context, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: Responsive.scaleH(context, 64),
                ),
                SizedBox(height: Responsive.scaleV(context, 16)),
                Text(
                  'Transfer Successful!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 20),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 12)),
                Text(
                  'Materials have been transferred successfully between sites.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 24)),
                _buildInfoItem('From: ${_fromSiteNameController.text}'),
                _buildInfoItem('To: ${_toSiteNameController.text}'),
                _buildInfoItem('Date: ${_fromDateController.text}'),
                SizedBox(height: Responsive.scaleV(context, 24)),
                GlassButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearSiteToSiteFields();
                  },
                  label: 'OK',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialogSiteToCompany() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassCard(
            padding: EdgeInsets.all(Responsive.scaleH(context, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: Responsive.scaleH(context, 64),
                ),
                SizedBox(height: Responsive.scaleV(context, 16)),
                Text(
                  'Return Successful!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 20),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 12)),
                Text(
                  'Materials have been returned to company successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: Responsive.scaleV(context, 24)),
                _buildInfoItem(
                  'Site: ${_siteToCompanySiteNameController.text}',
                ),
                _buildInfoItem('Date: ${_siteToCompanyDateController.text}'),
                SizedBox(height: Responsive.scaleV(context, 24)),
                GlassButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearSiteToCompanyFields();
                  },
                  label: 'OK',
                ),
              ],
            ),
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
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.scaleH(context, 8)),
        ),
        margin: EdgeInsets.all(Responsive.scaleH(context, 16)),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          padding: EdgeInsets.all(Responsive.scaleH(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About Material Transfer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 18),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Responsive.scaleV(context, 16)),
              _buildHelpItem(
                Icons.sync_alt,
                'Site to Site',
                'Transfer materials between two different project sites.',
              ),
              SizedBox(height: Responsive.scaleV(context, 12)),
              _buildHelpItem(
                Icons.business,
                'Return to Company',
                'Send materials from a site back to the central company inventory.',
              ),
              SizedBox(height: Responsive.scaleV(context, 12)),
              _buildHelpItem(
                Icons.inventory,
                'Real-time Tracking',
                'Inventory levels for all sites are updated automatically upon transfer confirmation.',
              ),
              SizedBox(height: Responsive.scaleV(context, 24)),
              Align(
                alignment: Alignment.centerRight,
                child: GlassButton(
                  onPressed: () => Navigator.pop(context),
                  label: 'Got it',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: Responsive.scaleH(context, 20),
        ),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Responsive.scaleV(context, 2)),
              Text(
                description,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              child: GlassTextField(
                controller: controller,
                label: label,
                icon: icon ?? Icons.text_fields,
                keyboardType: keyboardType,
                readOnly: true,
              ),
            ),
          )
        else
          GlassTextField(
            controller: controller,
            label: label,
            icon: icon ?? Icons.text_fields,
            keyboardType: keyboardType,
            readOnly: !enabled,
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: Responsive.scaleH(context, 4),
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
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
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.scaleH(context, 4),
            bottom: Responsive.scaleV(context, 8),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 14),
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withOpacity(0.8),
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.all(Responsive.scaleH(context, 14)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.scaleH(context, 8)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: Responsive.scaleH(context, 20),
                ),
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
    return GlassCard(
      padding: EdgeInsets.all(Responsive.scaleH(context, 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
            size: Responsive.scaleH(context, 20),
          ),
          SizedBox(width: Responsive.scaleH(context, 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 12),
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.scaleH(context, 4),
            bottom: Responsive.scaleV(context, 12),
          ),
          child: Text(
            'Materials to Transfer:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 16),
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ),
        GlassCard(
          child: Column(
            children: [
              ...materialsToTransfer.asMap().entries.map((entry) {
                final index = entry.key;
                final material = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: index < materialsToTransfer.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            ),
                          )
                        : null,
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(Responsive.scaleH(context, 8)),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory,
                        color: Theme.of(context).colorScheme.primary,
                        size: Responsive.scaleH(context, 20),
                      ),
                    ),
                    title: Text(
                      material['displayName'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.fontSize(context, 14),
                      ),
                    ),
                    subtitle: Text(
                      'Quantity: ${material['neededCount']} units',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
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
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
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
          Text(
            '• ',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.scaleH(context, 4),
            bottom: Responsive.scaleV(context, 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 14),
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withOpacity(0.8),
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleH(context, 12),
            vertical: Responsive.scaleV(context, 4),
          ),
          child: _isLoadingSites
              ? Row(
                  children: [
                    SizedBox(
                      width: Responsive.scaleH(context, 16),
                      height: Responsive.scaleH(context, 16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: Responsive.scaleH(context, 12)),
                    Text(
                      'Loading sites...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: Responsive.fontSize(context, 14),
                      ),
                    ),
                  ],
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: Text(
                      'Select Site',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
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
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.scaleH(context, 4),
            bottom: Responsive.scaleV(context, 8),
          ),
          child: Text(
            'Material Name *',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 14),
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withOpacity(0.8),
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleH(context, 12),
            vertical: Responsive.scaleV(context, 4),
          ),
          child: _isLoadingMaterials
              ? Row(
                  children: [
                    SizedBox(
                      width: Responsive.scaleH(context, 16),
                      height: Responsive.scaleH(context, 16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: Responsive.scaleH(context, 12)),
                    Text(
                      'Loading materials...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: Responsive.fontSize(context, 14),
                      ),
                    ),
                  ],
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMaterialName,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: Text(
                      'Select Material',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
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
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Available: $count',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: count > 0 ? Colors.green : Theme.of(context).colorScheme.error,
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
}
