import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class MaterialRequestForm extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const MaterialRequestForm({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<MaterialRequestForm> createState() => _MaterialRequestFormState();
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
  bool isSubmitting = false;

  // Dynamic branding color palette
  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get darkAccent => AppTheme.getDarkAccent(primaryColor);
  Color get errorColor => Theme.of(context).colorScheme.error;

  // Material dropdown data
  List<Map<String, dynamic>> materialDocs = [];
  List<String> materialDescriptions = [];

  DateTime? selectedDate;

  // Section 2 Controllers
  String? selectedMaterial;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  String selectedPriority = 'Immediate';

  // Data Table Rows
  List<Map<String, dynamic>> addedMaterials = [];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    supervisorNameController = TextEditingController(
      text: widget.supervisorName,
    );
    _fetchSupervisorSites();
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
      // Optional error handling
    }
  }

  Future<void> _fetchSupervisorSites() async {
    setState(() {
      isLoadingSupervisorData = true;
      supervisorError = null;
    });
    try {
      final collection = FirestoreService.getCollection('siteSupervisorMap');

      var query = collection.where(
        'Supervisor ID',
        isEqualTo: widget.supervisorId,
      );
      var snapshot = await query.get();

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
      // Optional error handling
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
            // Optional error handling
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
            // Optional error handling
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
              onPrimary: Colors.white,
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
    HapticFeedback.lightImpact();
    if (selectedMaterial != null &&
        quantityController.text.trim().isNotEmpty &&
        selectedUnit != null &&
        selectedUnit!.isNotEmpty) {
      setState(() {
        addedMaterials.add({
          'material': selectedMaterial,
          'unit': selectedUnit,
          'quantity': quantityController.text.trim(),
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
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fill in material, quantity, and unit.'),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _removeMaterial(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      addedMaterials.removeAt(index);
    });
  }

  void _sendForApproval() {
    if (addedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please add at least one material before submitting.'),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    _submitMaterialRequest();
  }

  Future<void> _submitMaterialRequest() async {
    setState(() => isSubmitting = true);
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

      final materialNames = addedMaterials
          .map((mat) => mat['material'])
          .join(', ');

      await NotificationService.notifyOrganisation(
        title: '📦 New Material Request',
        body: '$supervisorName (Site: $siteId) requested $matReqId. Items: $materialNames',
        data: {
          'type': 'material_request',
          'matReqId': matReqId,
          'siteId': siteId,
          'supervisorName': supervisorName,
        },
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              const Text('Request Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Material Request $matReqId has been successfully submitted to Organization for approval.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Dashboard'),
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
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Request Form',
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: isLoadingSupervisorData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading assigned site details...',
                        style: TextStyle(
                          color: darkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card Banner
                      _buildHeaderBanner(darkAccent),
                      const SizedBox(height: 16),

                      // Section 1: Site & Project Details Card
                      _buildSiteDetailsCard(darkAccent),
                      const SizedBox(height: 16),

                      // Section 2: Material Entry Card
                      _buildMaterialEntryCard(darkAccent),
                      const SizedBox(height: 16),

                      // Section 3: Added Materials List Card
                      _buildAddedMaterialsListCard(darkAccent),
                      const SizedBox(height: 24),

                      // Final Submit & Cancel Buttons
                      _buildActionButtons(darkAccent),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Modern Header Banner Card
  Widget _buildHeaderBanner(Color darkAccent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkAccent,
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Material Requisition',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Request raw materials & equipment for your site',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1: Site & Project Details
  Widget _buildSiteDetailsCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.domain_rounded,
            iconColor: primaryColor,
            title: 'Site & Project Information',
          ),
          const SizedBox(height: 14),
          if (supervisorError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      supervisorError!,
                      style: TextStyle(color: errorColor, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),

          // Site Dropdown Select
          _buildFormDropdown<String>(
            label: "Assigned Site ID",
            icon: Icons.location_on_rounded,
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
                projectController.text = map['projectName']?.toString() ?? '';
                projectStageController.text =
                    map['projectStage']?.toString() ?? '';
                supervisorNameController.text =
                    map['supervisor']?.toString() ?? widget.supervisorName;
              });
            },
          ),
          const SizedBox(height: 12),

          // Readonly Details Fields
          _buildFormTextField(
            label: "Supervisor Name",
            icon: Icons.person_rounded,
            controller: supervisorNameController,
            enabled: false,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildFormTextField(
                  label: "Project",
                  icon: Icons.apartment_rounded,
                  controller: projectController,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormTextField(
                  label: "Stage",
                  icon: Icons.engineering_rounded,
                  controller: projectStageController,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Picker
          _buildDateField(),
        ],
      ),
    );
  }

  /// Card 2: Material Entry Form
  Widget _buildMaterialEntryCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.add_shopping_cart_rounded,
            iconColor: primaryColor,
            title: 'Add Required Material',
          ),
          const SizedBox(height: 14),

          // Material Dropdown
          _buildFormDropdown<String>(
            label: "Select Material",
            icon: Icons.category_rounded,
            value: selectedMaterial,
            items: materialDescriptions,
            onChanged: _onMaterialChanged,
          ),
          const SizedBox(height: 12),

          // Unit & Quantity Row
          Row(
            children: [
              Expanded(
                child: _buildFormDropdown<String>(
                  label: "Unit",
                  icon: Icons.square_foot_rounded,
                  value: selectedUnit,
                  items: unitDropdownItems,
                  onChanged: (value) => setState(() => selectedUnit = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormTextField(
                  label: "Quantity",
                  icon: Icons.numbers_rounded,
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Priority Dropdown
          _buildFormDropdown<String>(
            label: "Priority Level",
            icon: Icons.priority_high_rounded,
            value: selectedPriority,
            items: const ['Immediate', 'In 2 days'],
            onChanged: (value) => setState(() => selectedPriority = value!),
          ),
          const SizedBox(height: 16),

          // Add Material Button (Branded)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMaterial,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                "Add Material to List",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: primaryColor.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: Added Materials List Card
  Widget _buildAddedMaterialsListCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardTitle(
                icon: Icons.checklist_rounded,
                iconColor: primaryColor,
                title: 'Requested Items',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${addedMaterials.length} Items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (addedMaterials.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No materials added yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use the form above to add items to your request.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addedMaterials.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = addedMaterials[index];
                final String matName = item['material'] ?? '';
                final String qty = item['quantity'] ?? '0';
                final String unit = item['unit'] ?? '';
                final String priority = item['priority'] ?? 'Immediate';
                final isImmediate = priority == 'Immediate';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isImmediate
                          ? errorColor.withValues(alpha: 0.2)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isImmediate
                              ? errorColor.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 18,
                          color: isImmediate ? errorColor : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qty: $qty $unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isImmediate
                              ? errorColor.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isImmediate ? errorColor : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: errorColor,
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

  /// Action Buttons (Cancel & Submit)
  Widget _buildActionButtons(Color darkAccent) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _sendForApproval,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              shadowColor: primaryColor.withValues(alpha: 0.4),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Submit Request",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Card Section Header Helper
  Widget _buildCardTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  /// Styled Text Form Field Helper
  Widget _buildFormTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 13.5,
        color: enabled ? const Color(0xFF0F172A) : Colors.grey.shade700,
        fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        prefixIcon: Icon(icon, size: 18, color: enabled ? primaryColor : Colors.grey.shade500),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
    );
  }

  /// Styled Dropdown Form Field Helper
  Widget _buildFormDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        prefixIcon: Icon(icon, size: 18, color: primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// Date Field Widget
  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: TextEditingController(
            text: selectedDate != null
                ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                : '',
          ),
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: "Target Request Date",
            labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            prefixIcon: Icon(Icons.calendar_month_rounded, size: 18, color: primaryColor),
            filled: true,
            fillColor: Colors.grey.shade50,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
        ),
      ),
    );
  }
}
