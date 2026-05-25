import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class MaterialAtSiteEntryPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const MaterialAtSiteEntryPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<MaterialAtSiteEntryPage> createState() =>
      _MaterialAtSiteEntryPageState();
}

class _MaterialAtSiteEntryPageState extends State<MaterialAtSiteEntryPage> {
  // Colors resolved from theme
  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get accentColor => Theme.of(context).colorScheme.secondary;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).colorScheme.surface;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get successColor => Colors.green; // Standard green for success, or use theme color if available

  // Form State
  final TextEditingController siteIdController = TextEditingController();
  final TextEditingController siteLocationController = TextEditingController();
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController projectStageController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();
  final TextEditingController joinedOnController = TextEditingController();
  final TextEditingController siteCommentsController = TextEditingController();
  final TextEditingController supervisorIdController_Internal =
      TextEditingController();
  final TextEditingController supervisorNameController =
      TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  // New state for site dropdown
  List<String> assignedSiteIds = [];
  List<Map<String, dynamic>> siteMappings = [];
  String? selectedSiteId;

  // For update, available existing dates
  List<DateTime> availableUpdateDates = [];

  // Data State
  List<String> materialOptions = [];
  List<String> unitOptions = [];
  String? selectedMaterial;
  String? selectedUnit;
  List<Map<String, dynamic>> materialEntries = [];

  // Loading States
  bool isLoading = true;
  bool dropdownsLoading = true;
  String? errorMsg;

  // Update Tab State
  List<Map<String, dynamic>> updateMaterials = [];
  List<TextEditingController> updateQuantityControllers = [];
  bool isUpdateLoading = false;
  String? updateErrorMsg;
  String? updateDocId;

  @override
  void initState() {
    super.initState();
    supervisorNameController.text = widget.supervisorName;
    fetchSiteDetails();
    fetchDropdownOptions();
  }

  Future<void> fetchSiteDetails() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      // Try querying by Supervisor ID first if it's likely an ID format
      final query = FirestoreService.siteSupervisorMap;

      // Query by Supervisor ID field which is more robust
      var snapshot = await query
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      // If nothing found by ID, fallback to searching by name
      if (snapshot.docs.isEmpty) {
        snapshot = await query
            .where('supervisor', isEqualTo: widget.supervisorName)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        setState(() {
          errorMsg = "No site mapping found for this supervisor";
        });
        return;
      }
      siteMappings = snapshot.docs.map((doc) => doc.data()).toList();
      assignedSiteIds = siteMappings
          .map((data) => data['site']?.toString() ?? '')
          .where((siteId) => siteId.isNotEmpty)
          .toList();
      if (assignedSiteIds.isNotEmpty) {
        selectedSiteId = assignedSiteIds.first;
        siteIdController.text = selectedSiteId!;
        final firstSiteData = siteMappings.firstWhere(
          (m) => m['site'] == selectedSiteId,
          orElse: () => {},
        );
        siteLocationController.text =
            firstSiteData['location']?.toString() ?? '';
        projectNameController.text =
            firstSiteData['projectName']?.toString() ?? '';
        projectStageController.text =
            firstSiteData['projectStage']?.toString() ?? '';
        startDateController.text = _formatDate(firstSiteData['startDate']);
        endDateController.text = _formatDate(firstSiteData['endDate']);
        joinedOnController.text = _formatDate(firstSiteData['joinedOn']);
        siteCommentsController.text =
            firstSiteData['siteComments']?.toString() ?? '';
        supervisorIdController_Internal.text =
            firstSiteData['Supervisor ID']?.toString() ?? widget.supervisorId;
        supervisorNameController.text =
            firstSiteData['supervisor']?.toString() ?? widget.supervisorName;
      }
    } catch (e) {
      setState(() {
        errorMsg = "Failed to load site details: ${e.toString()}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      if (date is String) {
        final dt = DateTime.parse(date);
        return DateFormat('yyyy-MM-dd').format(dt);
      } else if (date is Timestamp) {
        return DateFormat('yyyy-MM-dd').format(date.toDate());
      }
      return date.toString();
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> fetchDropdownOptions() async {
    try {
      final materialsSnapshot = await FirestoreService.materialCategories.get();
      final unitsSnapshot = await FirestoreService.materialUnits.get();

      setState(() {
        materialOptions = materialsSnapshot.docs
            .map((doc) {
              final data = doc.data();
              return (data['matCategory'] ?? data['materialName'] ?? '').toString().trim();
            })
            .where((e) => e.isNotEmpty)
            .toList();
        unitOptions = unitsSnapshot.docs
            .map(
              (doc) => doc.data().containsKey('matUnit')
                  ? doc['matUnit'].toString()
                  : '',
            )
            .where((e) => e.isNotEmpty)
            .toList();
        if (materialOptions.isNotEmpty) {
          selectedMaterial = materialOptions.first;
        }
        if (unitOptions.isNotEmpty) selectedUnit = unitOptions.first;
        dropdownsLoading = false;
      });
    } catch (e) {
      setState(() {
        dropdownsLoading = false;
        errorMsg = "Failed to load dropdown options: ${e.toString()}";
      });
    }
  }

  Future<void> fetchAvailableUpdateDates() async {
    final siteId = selectedSiteId;
    if (siteId == null) return;

    try {
      final snapshot = await FirestoreService.getCollection(
        'materialsAtSite',
      ).where('siteId', isEqualTo: siteId).get();

      setState(() {
        availableUpdateDates = snapshot.docs.map((doc) {
          final Timestamp? ts = doc['date'] as Timestamp?;
          return ts?.toDate() ?? DateTime.now();
        }).toList();
      });
    } catch (e) {
      setState(() {
        availableUpdateDates = [];
      });
      _showSnackBar(
        'Failed to fetch update dates: ${e.toString()}',
        isError: true,
      );
    }
  }

  Widget _buildUpdateDateSelector() {
    if (availableUpdateDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No dates available for update',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return DropdownButtonFormField<DateTime>(
      value: availableUpdateDates.contains(selectedDate) ? selectedDate : null,
      items: availableUpdateDates.map((date) {
        return DropdownMenuItem(
          value: date,
          child: Text(DateFormat('MMMM d, yyyy').format(date)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            selectedDate = val;
          });
          fetchMaterialsForUpdate(); // Reload materials for chosen date
        }
      },
      decoration: InputDecoration(
        labelText: 'Select Date to Update',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> fetchMaterialsForUpdate() async {
    final siteId = selectedSiteId;
    if (siteId == null) return;

    setState(() {
      isUpdateLoading = true;
      updateErrorMsg = null;
      updateMaterials = [];
      updateQuantityControllers = [];
    });

    try {
      final docId = '${siteId}_${DateFormat('yyyyMMdd').format(selectedDate)}';
      updateDocId = docId;

      final docSnap = await FirestoreService.getCollection(
        'materialsAtSite',
      ).doc(docId).get();

      if (!docSnap.exists ||
          docSnap.data() == null ||
          docSnap.data()!['materials'] == null) {
        setState(() => updateErrorMsg = 'No materials found for selected date');
        return;
      }

      final List<dynamic> mats = docSnap.data()!['materials'];
      updateMaterials = mats.map((e) => Map<String, dynamic>.from(e)).toList();
      updateQuantityControllers = updateMaterials
          .map(
            (mat) => TextEditingController(text: mat['materialQty'].toString()),
          )
          .toList();
    } catch (e) {
      setState(
        () => updateErrorMsg = 'Failed to fetch materials: ${e.toString()}',
      );
    } finally {
      setState(() => isUpdateLoading = false);
    }
  }

  Future<void> updateMaterialQuantity(int index) async {
    if (updateDocId == null) return;

    final newQty = int.tryParse(updateQuantityControllers[index].text.trim());
    if (newQty == null || newQty < 0) {
      _showSnackBar('Please enter a valid quantity', isError: true);
      return;
    }

    try {
      final docRef = FirestoreService.getCollection(
        'materialsAtSite',
      ).doc(updateDocId);
      final updatedMaterials = List<Map<String, dynamic>>.from(updateMaterials);
      updatedMaterials[index]['materialQty'] = newQty;

      // Updating entire materials array with the updated quantity of one material
      await docRef.update({'materials': updatedMaterials});

      // Update materialsInventory for this material and site
      final siteId = selectedSiteId ?? '';
      final materialName = updatedMaterials[index]['materialName'] ?? '';

      final invDocRef = FirestoreService.getCollection(
        'materialsInventory',
      ).doc(materialName);
      final invDocSnap = await invDocRef.get();

      if (invDocSnap.exists) {
        final data = invDocSnap.data() as Map<String, dynamic>;
        List sites = List.from(data['sites'] ?? []);

        bool siteFound = false;
        for (var s in sites) {
          if (s is Map && s['siteId'] == siteId) {
            s['materialQty'] = newQty;
            siteFound = true;
            break;
          }
        }
        if (!siteFound) {
          sites.add({'siteId': siteId, 'materialQty': newQty});
        }

        await invDocRef.update({
          'sites': sites,
          'lastUpdateOn': FieldValue.serverTimestamp(),
          'materialName': materialName,
        });
      } else {
        await invDocRef.set({
          'comment': '',
          'lastUpdateOn': FieldValue.serverTimestamp(),
          'materialName': materialName,
          'sites': [
            {'siteId': siteId, 'materialQty': newQty},
          ],
        });
      }

      setState(() => updateMaterials[index]['materialQty'] = newQty);
      _showSnackBar('Quantity updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update: ${e.toString()}', isError: true);
    }
  }

  void _addMaterialEntry() {
    final material = selectedMaterial ?? '';
    final unit = selectedUnit ?? '';
    final quantity = int.tryParse(quantityController.text.trim());

    if (material.isEmpty || unit.isEmpty) {
      _showSnackBar('Please select both material and unit', isError: true);
      return;
    }

    if (quantity == null || quantity <= 0) {
      _showSnackBar('Please enter a valid quantity', isError: true);
      return;
    }

    setState(() {
      materialEntries.add({
        'material': material,
        'unit': unit,
        'quantity': quantity,
      });
      quantityController.clear();
    });
  }

  void _deleteMaterialEntry(int index) {
    setState(() => materialEntries.removeAt(index));
    _showSnackBar('Material removed');
  }

  Future<void> _onSave() async {
    if (materialEntries.isEmpty) {
      _showSnackBar('Please add at least one material', isError: true);
      return;
    }

    final siteId = selectedSiteId?.trim() ?? '';
    if (siteId.isEmpty) {
      _showSnackBar('Site ID is required', isError: true);
      return;
    }

    try {
      final materialsArray = materialEntries
          .map(
            (entry) => {
              'materialName': entry['material'],
              'materialQty': entry['quantity'],
              'materialUnit': entry['unit'],
            },
          )
          .toList();

      final docId = '${siteId}_${DateFormat('yyyyMMdd').format(selectedDate)}';
      final docRef = FirestoreService.getCollection(
        'materialsAtSite',
      ).doc(docId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({
          'materials': FieldValue.arrayUnion(materialsArray),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'date': Timestamp.fromDate(selectedDate),
          'materials': materialsArray,
          'siteId': siteId,
          'siteLocation': siteLocationController.text.trim(),
          'supervisorName': supervisorNameController.text.trim(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Update materialsInventory collection
      for (final entry in materialsArray) {
        final String materialName = entry['materialName'] ?? '';
        final int materialQty = entry['materialQty'] ?? 0;
        if (materialName.isEmpty) continue;
        final invDocRef = FirestoreService.getCollection(
          'materialsInventory',
        ).doc(materialName);
        final invDocSnap = await invDocRef.get();
        final siteObj = {'materialQty': materialQty, 'siteId': siteId};
        if (invDocSnap.exists) {
          final data = invDocSnap.data() as Map<String, dynamic>;
          List sites = (data['sites'] ?? []) as List;
          bool found = false;
          for (var s in sites) {
            if (s is Map && s['siteId'] == siteId) {
              s['materialQty'] = materialQty;
              found = true;
              break;
            }
          }
          if (!found) {
            sites.add(siteObj);
          }
          await invDocRef.update({
            'sites': sites,
            'lastUpdateOn': FieldValue.serverTimestamp(),
            'materialName': materialName,
          });
        } else {
          await invDocRef.set({
            'comment': '',
            'lastUpdateOn': FieldValue.serverTimestamp(),
            'materialName': materialName,
            'sites': [siteObj],
          });
        }
      }

      _showSnackBar('Materials saved successfully');
      
      // Notify the organisation about material arrival at site
      await NotificationService.notifyOrganisation(
        title: '✅ Material Arrival Logged',
        body: '${supervisorNameController.text} logged material arrival at $siteId.',
        data: {
          'type': 'material_arrival',
          'siteId': siteId,
          'supervisorName': supervisorNameController.text,
        },
      );

      setState(() => materialEntries.clear());
    } catch (e) {
      _showSnackBar('Failed to save materials: ${e.toString()}', isError: true);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              primary: cs.primary,
              onPrimary: cs.onPrimary,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildInfoCard() {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SITE INFORMATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildSiteIdDropdown(),
            const SizedBox(height: 16),
            _buildReadOnlyField('Project Name', projectNameController),
            const SizedBox(height: 16),
            _buildReadOnlyField('Project Stage', projectStageController),
            const SizedBox(height: 16),
            _buildReadOnlyField('Start Date', startDateController),
            const SizedBox(height: 16),
            _buildReadOnlyField('End Date', endDateController),
            const SizedBox(height: 16),
            _buildReadOnlyField('Joined On', joinedOnController),
            const SizedBox(height: 16),
            _buildReadOnlyField('Location', siteLocationController),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              'Supervisor ID',
              supervisorIdController_Internal,
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField('Supervisor Name', supervisorNameController),
            const SizedBox(height: 16),
            _buildReadOnlyField('Site Comments', siteCommentsController),
            const SizedBox(height: 24),
            _buildDateField(),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteIdDropdown() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Site ID',
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedSiteId,
          items: assignedSiteIds
              .map(
                (siteId) => DropdownMenuItem(
                  value: siteId,
                  child: Text(
                    siteId,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: cs.onSurface),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) async {
            setState(() {
              selectedSiteId = val;
              siteIdController.text = val ?? '';
              if (val != null) {
                final mapping = siteMappings.firstWhere(
                  (m) => m['site'] == val,
                  orElse: () => {},
                );
                siteLocationController.text =
                    mapping['location']?.toString() ?? '';
                projectNameController.text =
                    mapping['projectName']?.toString() ?? '';
                projectStageController.text =
                    mapping['projectStage']?.toString() ?? '';
                startDateController.text = _formatDate(mapping['startDate']);
                endDateController.text = _formatDate(mapping['endDate']);
                joinedOnController.text = _formatDate(mapping['joinedOn']);
                siteCommentsController.text =
                    mapping['siteComments']?.toString() ?? '';
                supervisorIdController_Internal.text =
                    mapping['Supervisor ID']?.toString() ?? widget.supervisorId;
                supervisorNameController.text =
                    mapping['supervisor']?.toString() ?? widget.supervisorName;
              } else {
                siteLocationController.clear();
                projectNameController.clear();
                projectStageController.clear();
                startDateController.clear();
                endDateController.clear();
                joinedOnController.clear();
                siteCommentsController.clear();
                supervisorIdController_Internal.clear();
                supervisorNameController.clear();
              }
              errorMsg = null;
              updateMaterials.clear();
              updateQuantityControllers.clear();
              updateErrorMsg = null;
            });

            if (val != null) {
              await fetchAvailableUpdateDates();
            }
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            filled: true,
            fillColor: cs.surface.withOpacity(0.1),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: cs.onSurface.withOpacity(0.6),
          ),
          style: TextStyle(fontSize: 15, color: cs.onSurface),
          dropdownColor: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        filled: true,
        fillColor: cs.surface.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.6)),
      ),
      readOnly: true,
      style: TextStyle(fontSize: 15, color: cs.onSurface),
    );
  }

  Widget _buildDateField() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
              color: cs.surface.withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialInputCard() {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD MATERIALS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (dropdownsLoading)
              Center(child: CircularProgressIndicator(color: cs.primary))
            else if (materialOptions.isEmpty || unitOptions.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Text(
                  'No materials or units available. Please add them in Firestore.',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildMaterialDropdown()),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildUnitDropdown()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: quantityController,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            labelStyle: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 15, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addMaterialEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.secondary,
                          foregroundColor: cs.onSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('ADD'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedMaterial,
          items: materialOptions
              .map(
                (mat) => DropdownMenuItem(
                  value: mat,
                  child: Text(
                    mat,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => selectedMaterial = val),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            filled: true,
          ),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedUnit,
          items: unitOptions
              .map(
                (unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => selectedUnit = val),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            filled: true,
          ),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildMaterialList() {
    if (materialEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No materials added yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Add materials using the form above',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADDED MATERIALS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: materialEntries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = materialEntries[index];
            return Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),

              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['material'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry['quantity']} ${entry['unit']}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _deleteMaterialEntry(index),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface.withOpacity(0.7),
              side: BorderSide(color: cs.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('CANCEL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('SAVE MATERIALS'),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildUpdateDateSelector(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchMaterialsForUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('LOAD MATERIALS FOR SELECTED DATE'),
          ),
          const SizedBox(height: 20),
          if (isUpdateLoading)
            const Center(child: CircularProgressIndicator())
          else if (updateErrorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: errorColor.withOpacity(0.3)),
              ),
              child: Text(updateErrorMsg!, style: TextStyle(color: errorColor)),
            )
          else if (updateMaterials.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPDATE QUANTITIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: updateMaterials.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final mat = updateMaterials[index];
                    return Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(8),

                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mat['materialName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        updateQuantityControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Quantity',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () =>
                                      updateMaterialQuantity(index),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text('UPDATE'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.find_in_page_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No materials loaded',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Load materials for the selected date',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewEntryTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildMaterialInputCard(),
          const SizedBox(height: 20),
          _buildMaterialList(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        title: 'Material at Site Entry',
        body: Column(
          children: [
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.primary,
                ),
                labelColor: cs.onPrimary,
                unselectedLabelColor: cs.onSurface.withOpacity(0.7),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'New Entry'),
                  Tab(text: 'Update Entry'),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: cs.primary))
                  : errorMsg != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: cs.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMsg!,
                              style: TextStyle(color: cs.error, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: fetchSiteDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildNewEntryTabContent(),
                        _buildUpdateTabContent(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    siteIdController.dispose();
    siteLocationController.dispose();
    supervisorNameController.dispose();
    quantityController.dispose();
    for (var controller in updateQuantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
