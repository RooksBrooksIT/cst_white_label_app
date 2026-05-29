import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import '../widgets/glass_scaffold.dart';

class MaterialRequestForm extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const MaterialRequestForm({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _MaterialRequestFormState createState() => _MaterialRequestFormState();
}

class _MaterialRequestFormState extends State<MaterialRequestForm> {
  // Dropdown lists
  List<String> siteDropdownItems = [];
  String? selectedSite;

  List<String> unitDropdownItems = [];
  String? selectedUnit;

  String? supervisorError;

  // Store full site mappings to support dynamic lookup on site change
  List<Map<String, dynamic>> siteMappings = [];

  // Section 1 Controllers
  final TextEditingController siteIdController = TextEditingController();
  late final TextEditingController supervisorNameController;
  final TextEditingController projectController = TextEditingController();
  final TextEditingController projectStageController = TextEditingController();
  bool isLoadingSupervisorData = true;

  // Color scheme
  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get accentColor => Theme.of(context).colorScheme.secondary;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get backgroundColor => Theme.of(context).colorScheme.surface;

  // Material dropdown data
  List<Map<String, dynamic>> materialDocs = [];
  List<String> materialDescriptions = [];

  @override
  void initState() {
    super.initState();
    supervisorNameController = TextEditingController(
      text: widget.supervisorName,
    );
    _fetchSupervisorSites(); // fetch all sites assigned to supervisor
    _fetchMaterialsFromFirestore();
    _fetchUnitsFromFirestore();
  }

  Future<void> _fetchUnitsFromFirestore() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'materialUnits',
      ).get();
      final units = snapshot.docs
          .map((doc) => doc.data()['matUnit']?.toString() ?? '')
          .where((unit) => unit.isNotEmpty)
          .toList();
      setState(() {
        unitDropdownItems = units;
      });
    } catch (e) {
      // Optionally handle error
    }
  }

  Future<void> _fetchSupervisorSites() async {
    setState(() {
      isLoadingSupervisorData = true;
      supervisorError = null;
    });
    try {
      final collection = FirestoreService.getCollection('siteSupervisorMap');

      // Try querying by Supervisor ID first
      var query = collection.where(
        'Supervisor ID',
        isEqualTo: widget.supervisorId,
      );
      var snapshot = await query.get();

      // Fallback to name if not found by ID
      if (snapshot.docs.isEmpty) {
        query = collection.where(
          'supervisor',
          isEqualTo: widget.supervisorName,
        );
        snapshot = await query.get();
      }

      if (snapshot.docs.isNotEmpty) {
        siteDropdownItems = snapshot.docs
            .map((doc) => doc.data()['site']?.toString() ?? '')
            .where((site) => site.isNotEmpty)
            .toList();

        siteMappings = snapshot.docs.map((doc) => doc.data()).toList();

        if (siteDropdownItems.isNotEmpty) {
          selectedSite = siteDropdownItems.first;
          siteIdController.text = selectedSite!;
          final firstData = snapshot.docs.first.data();
          projectController.text = firstData['projectName']?.toString() ?? '';
          projectStageController.text =
              firstData['projectStage']?.toString() ?? '';
          supervisorNameController.text =
              firstData['supervisor']?.toString() ?? widget.supervisorName;
        } else {
          supervisorError = 'No sites assigned to this supervisor.';
        }
      } else {
        supervisorError = 'No site mapping found for this supervisor.';
      }
    } catch (e) {
      supervisorError = 'Failed to load supervisor data.';
    } finally {
      setState(() {
        isLoadingSupervisorData = false;
      });
    }
  }

  Future<void> _fetchMaterialsFromFirestore() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'materialCategories',
      ).get();
      materialDocs = snapshot.docs.map((doc) => doc.data()).toList();
      materialDescriptions = materialDocs
          .map(
            (m) =>
                (m['matCategory'] ?? m['materialName'] ?? '').toString().trim(),
          )
          .where((desc) => desc.isNotEmpty)
          .toList();
      setState(() {});
    } catch (e) {
      // Optionally handle error
    }
  }

  @override
  void dispose() {
    unitController.dispose();
    supervisorNameController.dispose();
    siteIdController.dispose();
    projectController.dispose();
    projectStageController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  DateTime? selectedDate;

  // Section 2 Controllers
  String? selectedMaterial;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  String selectedPriority = 'Immediate';

  // Data Table Rows
  List<Map<String, dynamic>> addedMaterials = [];

  Future<void> _onMaterialChanged(String? value) async {
    unitController.text = '';
    setState(() {
      selectedMaterial = value;
    });
    if (value != null) {
      final mat = materialDocs.firstWhere(
        (m) =>
            (m['matCategory'] ?? m['materialName'] ?? '').toString().trim() ==
            value,
        orElse: () => {},
      );
      final unitRef = mat['materialUnit'];
      if (unitRef != null && unitRef.toString().isNotEmpty) {
        if (unitRef is String && unitRef.startsWith('materialUnits/')) {
          try {
            final unitSnap = await FirebaseFirestore.instance
                .doc(unitRef)
                .get();
            if (unitSnap.exists && unitSnap.data() != null) {
              final unitData = unitSnap.data() as Map<String, dynamic>;
              final unitName = unitData['name']?.toString() ?? '';
              if (unitName.isNotEmpty) {
                setState(() {
                  unitController.text = unitName;
                });
              }
            }
          } catch (e) {
            // Optionally handle error
          }
        } else if (unitRef is DocumentReference) {
          try {
            final unitSnap = await unitRef.get();
            if (unitSnap.exists && unitSnap.data() != null) {
              final unitData = unitSnap.data() as Map<String, dynamic>;
              final unitName = unitData['name']?.toString() ?? '';
              if (unitName.isNotEmpty) {
                setState(() {
                  unitController.text = unitName;
                });
              }
            }
          } catch (e) {
            // Optionally handle error
          }
        } else {
          setState(() {
            unitController.text = unitRef.toString();
          });
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
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

  void _addMaterial() {
    if (selectedMaterial != null &&
        quantityController.text.isNotEmpty &&
        selectedUnit != null &&
        selectedUnit!.isNotEmpty) {
      setState(() {
        addedMaterials.add({
          'material': selectedMaterial,
          'unit': selectedUnit,
          'quantity': quantityController.text,
          'priority': selectedPriority,
        });
        selectedMaterial = null;
        selectedUnit = null;
        quantityController.clear();
        selectedPriority = 'Immediate';
      });
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all material fields'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  void _removeMaterial(int index) {
    setState(() {
      addedMaterials.removeAt(index);
    });
  }

  void _cancelForm() {
    Navigator.pop(context);
  }

  void _sendForApproval() {
    if (addedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one material'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    _submitMaterialRequest();
  }

  Future<void> _submitMaterialRequest() async {
    try {
      final siteId = siteIdController.text.trim();
      final projectName = projectController.text.trim();
      final supervisorName = supervisorNameController.text.trim();
      final now = DateTime.now();
      final formattedDate =
          '${DateFormat('MMMM d, yyyy at h:mm:ss a').format(now)} UTC${now.timeZoneOffset.isNegative ? '-' : '+'}${now.timeZoneOffset.inHours.abs()}:${(now.timeZoneOffset.inMinutes % 60).toString().padLeft(2, '0')}';

      final reqCollection = FirestoreService.getCollection(
        'siteMaterialsRequest',
      );
      final querySnapshot = await reqCollection
          .orderBy('matReqId', descending: true)
          .limit(1)
          .get();
      String matReqId = "MR001";
      if (querySnapshot.docs.isNotEmpty) {
        final lastId =
            querySnapshot.docs.first.data()['matReqId']?.toString() ?? "MR000";
        final numPart =
            int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        matReqId = "MR${(numPart + 1).toString().padLeft(3, '0')}";
      }

      final List<Map<String, dynamic>> materials = addedMaterials
          .map(
            (mat) => {
              "materialName": mat['material'],
              "materialQty":
                  int.tryParse(mat['quantity'].toString()) ?? mat['quantity'],
              "materialUnit": mat['unit'],
              "priority": mat['priority'],
            },
          )
          .toList();

      final data = {
        "matReqId": matReqId,
        "date": formattedDate,
        "siteId": siteId,
        "projectName": projectName,
        "projectStage": projectStageController.text.trim(),
        "supervisorName": supervisorName,
        "status": "Processing",
        "materials": materials,
      };

      String datePart;
      if (selectedDate != null) {
        datePart = DateFormat('yyyyMMdd').format(selectedDate!);
      } else {
        datePart = DateFormat('yyyyMMdd').format(DateTime.now());
      }
      final docId = "${siteId}_$datePart";
      await reqCollection.doc(docId).set(data);

      // Build a string of requested materials
      final materialNames = addedMaterials
          .map((mat) => mat['material'])
          .join(', ');

      // Notify the organisation about the new material request
      await NotificationService.notifyOrganisation(
        title: '📦 New Material Request',
        body:
            '$supervisorName (Site: $siteId) requested $matReqId. Items: $materialNames',
        data: {
          'type': 'material_request',
          'matReqId': matReqId,
          'siteId': siteId,
          'supervisorName': supervisorName,
        },
      );

      if (!mounted) return;

      // Show alert dialog with matReqId and keep form open
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Request Submitted'),
          content: Text(
            'Material Request ID $matReqId has been sent for approval.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit request: $e"),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,

        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,

        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      icon: Icon(Icons.arrow_drop_down, color: primaryColor),
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            style: TextStyle(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.only(top: 20, bottom: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: TextEditingController(
            text: selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                : '',
          ),
          decoration: InputDecoration(
            labelText: "Date",
            labelStyle: TextStyle(color: primaryColor),
            hintText: 'Select Date',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            filled: true,

            suffixIcon: Icon(Icons.calendar_today, color: primaryColor),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Material Request Form',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      body: isLoadingSupervisorData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading site information...',
                    style: TextStyle(color: primaryColor),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// SECTION 1: Basic Details
                  _buildSectionHeader('Site Information'),
                  if (supervisorError != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: errorColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              supervisorError!,
                              style: TextStyle(color: errorColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 8),
                  _buildDropdown<String>(
                    label: "Site ID",
                    value: selectedSite,
                    items: siteDropdownItems,
                    onChanged: (value) {
                      setState(() {
                        selectedSite = value;
                        siteIdController.text = value ?? '';
                        final map = siteMappings.firstWhere(
                          (m) => m['site'] == value,
                          orElse: () => {},
                        );
                        projectController.text =
                            map['projectName']?.toString() ?? '';
                        projectStageController.text =
                            map['projectStage']?.toString() ?? '';
                        supervisorNameController.text =
                            map['supervisor']?.toString() ??
                            widget.supervisorName;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    "Supervisor Name",
                    supervisorNameController,
                    enabled: false,
                  ),
                  SizedBox(height: 12),
                  _buildTextField("Project", projectController, enabled: false),
                  SizedBox(height: 12),
                  _buildTextField(
                    "Project Stage",
                    projectStageController,
                    enabled: false,
                  ),
                  SizedBox(height: 12),
                  _buildDateField(),
                  SizedBox(height: 8),

                  /// SECTION 2: Material Entry
                  _buildSectionHeader('Add Materials'),
                  SizedBox(height: 8),
                  _buildDropdown<String>(
                    label: "Material",
                    value: selectedMaterial,
                    items: materialDescriptions,
                    onChanged: _onMaterialChanged,
                  ),
                  SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: "Unit",
                    value: selectedUnit,
                    items: unitDropdownItems,
                    onChanged: (value) => setState(() => selectedUnit = value),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField("Quantity", quantityController),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: "Priority",
                    value: selectedPriority,
                    items: ['Immediate', 'In 2 days'],
                    onChanged: (value) =>
                        setState(() => selectedPriority = value!),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      icon: Icon(Icons.add, size: 20),
                      label: Text("Add Material"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                      ),
                    ),
                  ),

                  /// SECTION 3: Data Table
                  if (addedMaterials.isNotEmpty) ...[
                    _buildSectionHeader('Requested Materials'),
                    SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            dataRowHeight: 48,
                            headingRowHeight: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            columns: [
                              DataColumn(
                                label: Text(
                                  "Material",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Unit",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Qty",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Priority",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Action",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                            rows: addedMaterials
                                .asMap()
                                .entries
                                .map(
                                  (entry) => DataRow(
                                    cells: [
                                      DataCell(Text(entry.value['material'])),
                                      DataCell(Text(entry.value['unit'] ?? '')),
                                      DataCell(Text(entry.value['quantity'])),
                                      DataCell(
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                entry.value['priority'] ==
                                                    'Immediate'
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .error
                                                      .withOpacity(0.1)
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .secondary
                                                      .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  entry.value['priority'] ==
                                                      'Immediate'
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                        .withOpacity(0.3)
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .secondary
                                                        .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            entry.value['priority'],
                                            style: TextStyle(
                                              color:
                                                  entry.value['priority'] ==
                                                      'Immediate'
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.error
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.secondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: errorColor,
                                          ),
                                          onPressed: () =>
                                              _removeMaterial(entry.key),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Total Items: ${addedMaterials.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 60,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No materials added yet',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add materials using the form above',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  /// FINAL BUTTONS
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancelForm,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _sendForApproval,
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                            backgroundColor: primaryColor,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, size: 20),
                                SizedBox(width: 8),
                                Text("Submit Request", style: TextStyle()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
