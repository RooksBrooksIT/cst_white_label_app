import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key});

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Selected State
  DocumentReference? selectedCategoryRef;
  String? selectedCategoryName;
  DocumentReference? selectedSubCategoryRef;
  String? selectedSubCategoryName;
  DocumentReference? selectedUnitRef;
  String? selectedUnitName;

  // Form Controllers
  final materialIdController = TextEditingController();
  final materialNameController = TextEditingController();
  final unitPriceController = TextEditingController();
  final descriptionController = TextEditingController();

  // Loaded Options
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subCategories = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> materials = [];

  // Loading States
  bool isLoadingCategories = true;
  bool isLoadingSubCategories = false;
  bool isLoadingUnits = true;
  bool isLoadingMaterialId = false;
  bool isLoadingMaterials = false;
  bool _isSaving = false;

  // Update Tab State
  final searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? selectedMaterialForUpdate;
  final updatePriceController = TextEditingController();
  bool isEditingPrice = false;
  bool isSavingPriceUpdate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeAllData();
  }

  @override
  void dispose() {
    materialIdController.dispose();
    materialNameController.dispose();
    unitPriceController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    updatePriceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeAllData() async {
    await FirestoreService.initialize();
    await Future.wait([
      _fetchCategories(),
      _fetchUnits(),
      _fetchNextMaterialId(),
      _fetchMaterials(),
    ]);
  }

  int _getNextIdNumber(QuerySnapshot snapshot, String prefix) {
    final ids = snapshot.docs
        .map((doc) {
          final docId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          final fieldId = data?['materialId']?.toString() ?? '';
          if (docId.startsWith(prefix)) return docId;
          if (fieldId.startsWith(prefix)) return fieldId;
          return docId;
        })
        .where((id) => id.startsWith(prefix))
        .map((id) => int.tryParse(id.substring(prefix.length)) ?? 0)
        .toList();

    if (ids.isEmpty) return 1;
    ids.sort();
    return ids.last + 1;
  }

  // --- 1. FETCH DATA ---

  Future<void> _fetchCategories({DocumentReference? selectRef}) async {
    if (mounted) setState(() => isLoadingCategories = true);
    try {
      final snapshot = await FirestoreService.materialCategories.get();
      if (!mounted) return;

      final loadedCategories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'ref': doc.reference,
              'id': doc.id,
              'name': (data['matCategory'] ?? data['materialName'] ?? '').toString().trim(),
            };
          })
          .where((c) => (c['name'] as String).isNotEmpty)
          .toList();

      loadedCategories.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
      );

      categories = loadedCategories;

      if (selectRef != null &&
          categories.any((c) => (c['ref'] as DocumentReference).path == selectRef.path)) {
        final cat = categories.firstWhere(
          (c) => (c['ref'] as DocumentReference).path == selectRef.path,
        );
        selectedCategoryRef = cat['ref'];
        selectedCategoryName = cat['name'];
      } else if (selectedCategoryRef != null &&
          categories.any(
            (c) => (c['ref'] as DocumentReference).path == selectedCategoryRef!.path,
          )) {
        final cat = categories.firstWhere(
          (c) => (c['ref'] as DocumentReference).path == selectedCategoryRef!.path,
        );
        selectedCategoryName = cat['name'];
      } else if (categories.isNotEmpty) {
        selectedCategoryRef = categories.first['ref'];
        selectedCategoryName = categories.first['name'];
      } else {
        selectedCategoryRef = null;
        selectedCategoryName = null;
      }

      await _fetchSubCategories();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> _fetchSubCategories({DocumentReference? selectRef}) async {
    if (selectedCategoryRef == null) {
      if (mounted) {
        setState(() {
          subCategories = [];
          selectedSubCategoryRef = null;
          selectedSubCategoryName = null;
          _updateMaterialMasterName();
        });
      }
      return;
    }

    if (mounted) setState(() => isLoadingSubCategories = true);
    try {
      final snapshot = await FirestoreService.materialSubCategories
          .where('matCategory', isEqualTo: selectedCategoryRef)
          .get();

      if (!mounted) return;

      final loadedSubCategories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'ref': doc.reference,
              'id': doc.id,
              'name': (data['matSubCategory'] ?? '').toString().trim(),
              'unitRef': data['matUnit'] as DocumentReference?,
            };
          })
          .where((s) => (s['name'] as String).isNotEmpty)
          .toList();

      loadedSubCategories.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
      );

      subCategories = loadedSubCategories;

      if (selectRef != null &&
          subCategories.any((s) => (s['ref'] as DocumentReference).path == selectRef.path)) {
        final sub = subCategories.firstWhere(
          (s) => (s['ref'] as DocumentReference).path == selectRef.path,
        );
        selectedSubCategoryRef = sub['ref'];
        selectedSubCategoryName = sub['name'];
        if (sub['unitRef'] != null) {
          _matchAndSelectUnit(sub['unitRef']);
        }
      } else if (selectedSubCategoryRef != null &&
          subCategories.any(
            (s) => (s['ref'] as DocumentReference).path == selectedSubCategoryRef!.path,
          )) {
        final sub = subCategories.firstWhere(
          (s) => (s['ref'] as DocumentReference).path == selectedSubCategoryRef!.path,
        );
        selectedSubCategoryName = sub['name'];
      } else if (subCategories.isNotEmpty) {
        selectedSubCategoryRef = subCategories.first['ref'];
        selectedSubCategoryName = subCategories.first['name'];
        if (subCategories.first['unitRef'] != null) {
          _matchAndSelectUnit(subCategories.first['unitRef']);
        }
      } else {
        selectedSubCategoryRef = null;
        selectedSubCategoryName = null;
      }

      _updateMaterialMasterName();
    } catch (e) {
      debugPrint('Error fetching subcategories: $e');
    } finally {
      if (mounted) setState(() => isLoadingSubCategories = false);
    }
  }

  Future<void> _fetchUnits({DocumentReference? selectRef}) async {
    if (mounted) setState(() => isLoadingUnits = true);
    try {
      final snapshot = await FirestoreService.materialUnits.get();
      if (!mounted) return;

      final loadedUnits = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'ref': doc.reference,
              'id': doc.id,
              'name': (data['matUnit'] ?? data['name'] ?? '').toString().trim(),
            };
          })
          .where((u) => (u['name'] as String).isNotEmpty)
          .toList();

      loadedUnits.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
      );

      units = loadedUnits;

      if (selectRef != null &&
          units.any((u) => (u['ref'] as DocumentReference).path == selectRef.path)) {
        final u = units.firstWhere(
          (u) => (u['ref'] as DocumentReference).path == selectRef.path,
        );
        selectedUnitRef = u['ref'];
        selectedUnitName = u['name'];
      } else if (selectedUnitRef != null &&
          units.any(
            (u) => (u['ref'] as DocumentReference).path == selectedUnitRef!.path,
          )) {
        final u = units.firstWhere(
          (u) => (u['ref'] as DocumentReference).path == selectedUnitRef!.path,
        );
        selectedUnitName = u['name'];
      } else if (units.isNotEmpty && selectedUnitRef == null) {
        selectedUnitRef = units.first['ref'];
        selectedUnitName = units.first['name'];
      }
    } catch (e) {
      debugPrint('Error fetching units: $e');
    } finally {
      if (mounted) setState(() => isLoadingUnits = false);
    }
  }

  void _matchAndSelectUnit(DocumentReference? unitRef) {
    if (unitRef == null) return;
    if (units.any((u) => (u['ref'] as DocumentReference).path == unitRef.path)) {
      final u = units.firstWhere(
        (u) => (u['ref'] as DocumentReference).path == unitRef.path,
      );
      selectedUnitRef = u['ref'];
      selectedUnitName = u['name'];
    }
  }

  Future<void> _fetchNextMaterialId() async {
    if (mounted) setState(() => isLoadingMaterialId = true);
    try {
      final snapshot = await FirestoreService.materials.get();
      if (!mounted) return;

      final nextNum = _getNextIdNumber(snapshot, 'MT');
      materialIdController.text = 'MT${nextNum.toString().padLeft(3, '0')}';
    } catch (e) {
      materialIdController.text = 'MT001';
    } finally {
      if (mounted) setState(() => isLoadingMaterialId = false);
    }
  }

  Future<void> _fetchMaterials() async {
    if (mounted) setState(() => isLoadingMaterials = true);
    try {
      final snapshot = await FirestoreService.materials.get();
      if (!mounted) return;

      final loadedMaterials = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String unitDisplay = data['materialUnit']?.toString() ?? '';

        if (unitDisplay.isEmpty && data['materialUnitRef'] != null) {
          try {
            final uDoc = await (data['materialUnitRef'] as DocumentReference).get();
            if (uDoc.exists && uDoc.data() != null) {
              final uData = uDoc.data() as Map<String, dynamic>;
              unitDisplay = uData['matUnit'] ?? uData['name'] ?? '';
            }
          } catch (_) {}
        }

        loadedMaterials.add({
          'ref': doc.reference,
          'id': doc.id,
          'materialId': data['materialId'] ?? doc.id,
          'materialName': data['materialName'] ?? '',
          'materialCategory': data['materialCategory'] ?? '',
          'materialCategoryRef': data['materialCategoryRef'] as DocumentReference?,
          'materialSubCategory': data['materialSubCategory'] ?? '',
          'materialSubCategoryRef': data['materialSubCategoryRef'] as DocumentReference?,
          'materialPrice': data['materialPrice']?.toString() ?? data['unitPrice']?.toString() ?? '0',
          'materialUnit': unitDisplay,
          'materialUnitRef': data['materialUnitRef'] as DocumentReference?,
          'description': data['description'] ?? '',
        });
      }

      loadedMaterials.sort(
        (a, b) => (a['materialName'] as String).toLowerCase().compareTo(
              (b['materialName'] as String).toLowerCase(),
            ),
      );

      if (mounted) {
        setState(() {
          materials = loadedMaterials;
          if (selectedMaterialForUpdate != null) {
            final updated = materials.firstWhere(
              (m) => (m['ref'] as DocumentReference).path == (selectedMaterialForUpdate!['ref'] as DocumentReference).path,
              orElse: () => materials.isNotEmpty ? materials.first : {},
            );
            if (updated.isNotEmpty) {
              _onSelectMaterialForUpdate(updated);
            }
          } else if (materials.isNotEmpty) {
            _onSelectMaterialForUpdate(materials.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching materials: $e');
    } finally {
      if (mounted) setState(() => isLoadingMaterials = false);
    }
  }

  void _updateMaterialMasterName() {
    final catName = selectedCategoryName?.trim() ?? '';
    final subName = selectedSubCategoryName?.trim() ?? '';

    if (catName.isNotEmpty && subName.isNotEmpty) {
      materialNameController.text = '${catName}_$subName';
    } else if (catName.isNotEmpty) {
      materialNameController.text = catName;
    } else {
      materialNameController.text = '';
    }
  }

  void _onSelectMaterialForUpdate(Map<String, dynamic> mat) {
    setState(() {
      selectedMaterialForUpdate = mat;
      updatePriceController.text = mat['materialPrice'] ?? '';
      isEditingPrice = false;
    });
  }

  // --- 2. ADD NEW MODALS (PLUS BUTTONS) ---

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final primaryColor = theme.primaryColor;

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.inventory_2_rounded, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Material Name',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                  Text(
                                    'Master Material Category (e.g. Cement, Steel, Sand)',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('Material Name / Category *'),
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A183D),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. Cement, Steel, Bricks, Sand',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 12, right: 8),
                              child: Icon(Icons.category_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return 'Please enter material name';
                            final exists = categories.any(
                              (c) => (c['name'] as String).toLowerCase() == text.toLowerCase(),
                            );
                            if (exists) return 'Material category already exists';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: isSavingLocal
                                      ? null
                                      : () async {
                                          if (!dialogFormKey.currentState!.validate()) return;
                                          setDialogState(() => isSavingLocal = true);

                                          final catName = nameController.text.trim();
                                          final messenger = ScaffoldMessenger.of(context);
                                          final navigator = Navigator.of(ctx);

                                          try {
                                            final catCol = FirestoreService.materialCategories;
                                            final snap = await catCol.get();
                                            final nextId = _getNextIdNumber(snap, 'MC');
                                            final docId = 'MC${nextId.toString().padLeft(3, '0')}';
                                            final docRef = catCol.doc(docId);

                                            await docRef.set({
                                              'matCategory': catName,
                                              'created_at': FieldValue.serverTimestamp(),
                                            });

                                            if (mounted) {
                                              navigator.pop();
                                              await _fetchCategories(selectRef: docRef);
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Material Name "$catName" added successfully!'),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('Failed to add category: $e')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setDialogState(() => isSavingLocal = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 1,
                                  ),
                                  child: isSavingLocal
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'SAVE NAME',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddSubCategoryDialog() async {
    if (selectedCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a Material Name first'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final subCatController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final primaryColor = theme.primaryColor;

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.subdirectory_arrow_right_rounded, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Subcategory',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                  Text(
                                    'Under "${selectedCategoryName ?? ''}" (e.g. OPC, PPC, 12mm)',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('Subcategory Name *'),
                        TextFormField(
                          controller: subCatController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A183D),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. OPC 53 Grade, TMT 12mm, Fine Sand',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 12, right: 8),
                              child: Icon(Icons.label_important_outline_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return 'Please enter subcategory name';
                            final exists = subCategories.any(
                              (s) => (s['name'] as String).toLowerCase() == text.toLowerCase(),
                            );
                            if (exists) return 'Subcategory already exists under this material';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: isSavingLocal
                                      ? null
                                      : () async {
                                          if (!dialogFormKey.currentState!.validate()) return;
                                          setDialogState(() => isSavingLocal = true);

                                          final subCatName = subCatController.text.trim();
                                          final messenger = ScaffoldMessenger.of(context);
                                          final navigator = Navigator.of(ctx);

                                          try {
                                            final subCol = FirestoreService.materialSubCategories;
                                            final snap = await subCol.get();
                                            final nextId = _getNextIdNumber(snap, 'MSC');
                                            final docId = 'MSC${nextId.toString().padLeft(3, '0')}';
                                            final docRef = subCol.doc(docId);

                                            await docRef.set({
                                              'matCategory': selectedCategoryRef,
                                              'matSubCategory': subCatName,
                                              'created_at': FieldValue.serverTimestamp(),
                                            });

                                            if (mounted) {
                                              navigator.pop();
                                              await _fetchSubCategories(selectRef: docRef);
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Subcategory "$subCatName" added successfully!'),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('Failed to add subcategory: $e')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setDialogState(() => isSavingLocal = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 1,
                                  ),
                                  child: isSavingLocal
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'SAVE SUB',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddUnitDialog() async {
    final unitController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final primaryColor = theme.primaryColor;

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.straighten_rounded, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Measurement Unit',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                  Text(
                                    'e.g. Bags, Kg, Ton, Liters, SqFt, Cubic Feet, Nos',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('Unit Name / Symbol *'),
                        TextFormField(
                          controller: unitController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A183D),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. Bags, Ton, Liters, Bundle',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 12, right: 8),
                              child: Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return 'Please enter unit name';
                            final exists = units.any(
                              (u) => (u['name'] as String).toLowerCase() == text.toLowerCase(),
                            );
                            if (exists) return 'Unit already exists';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: isSavingLocal
                                      ? null
                                      : () async {
                                          if (!dialogFormKey.currentState!.validate()) return;
                                          setDialogState(() => isSavingLocal = true);

                                          final unitName = unitController.text.trim();
                                          final messenger = ScaffoldMessenger.of(context);
                                          final navigator = Navigator.of(ctx);

                                          try {
                                            final unitCol = FirestoreService.materialUnits;
                                            final snap = await unitCol.get();
                                            final nextId = _getNextIdNumber(snap, 'MU');
                                            final docId = 'MU${nextId.toString().padLeft(3, '0')}';
                                            final docRef = unitCol.doc(docId);

                                            await docRef.set({
                                              'matUnit': unitName,
                                              'created_at': FieldValue.serverTimestamp(),
                                            });

                                            if (mounted) {
                                              navigator.pop();
                                              await _fetchUnits(selectRef: docRef);
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Unit "$unitName" added successfully!'),
                                                  backgroundColor: const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('Failed to add unit: $e')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setDialogState(() => isSavingLocal = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 1,
                                  ),
                                  child: isSavingLocal
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'SAVE UNIT',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 3. SAVE MATERIAL ---

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a Material Name'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (selectedSubCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a Subcategory'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (selectedUnitRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a Material Unit'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final masterName = materialNameController.text.trim();
    final priceStr = unitPriceController.text.trim();
    final priceNum = num.tryParse(priceStr) ?? 0;
    final description = descriptionController.text.trim();

    try {
      // Check duplicate
      final duplicateQuery = await FirestoreService.materials
          .where('materialName', isEqualTo: masterName)
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material "$masterName" is already configured!'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final materialId = materialIdController.text.trim().isNotEmpty
          ? materialIdController.text.trim()
          : 'MT001';
      final docRef = FirestoreService.materials.doc(materialId);

      await docRef.set({
        'materialId': materialId,
        'materialCategoryRef': selectedCategoryRef,
        'materialCategory': selectedCategoryName,
        'materialSubCategoryRef': selectedSubCategoryRef,
        'materialSubCategory': selectedSubCategoryName,
        'materialName': masterName,
        'materialUnitRef': selectedUnitRef,
        'materialUnit': selectedUnitName,
        'materialPrice': priceStr,
        'unitPrice': priceNum,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Material "$masterName" saved successfully!',
        );

        _resetForm();
        await _fetchNextMaterialId();
        await _fetchMaterials();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save material: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      unitPriceController.clear();
      descriptionController.clear();
      if (categories.isNotEmpty) {
        selectedCategoryRef = categories.first['ref'];
        selectedCategoryName = categories.first['name'];
      }
    });
    _fetchSubCategories();
  }

  // --- 4. BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.2),
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
            // Tab Switcher Container
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
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF0A183D),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'CONFIGURE MATERIAL'),
                  Tab(text: 'SEARCH & UPDATE'),
                ],
              ),
            ),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConfigurationTab(),
                      _buildUpdateTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. CONFIGURATION TAB (COMBINED SCREEN) ---

  Widget _buildConfigurationTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Unified Configuration Card
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Material Specifications',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A183D),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Set category, subcategory, master name, unit & pricing',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Material ID (Auto Generated)
                  _buildCustomTextField(
                    controller: materialIdController,
                    label: 'Material ID',
                    icon: Icons.tag_rounded,
                    readOnly: true,
                    helperText: 'Auto-generated sequence ID',
                  ),
                  const SizedBox(height: 18),

                  // Field 1: Material Name (Category) + (+) Button
                  _buildDropdownWithAddButton(
                    label: 'Material Name',
                    hintText: isLoadingCategories ? 'Loading categories...' : 'Select Material Name',
                    value: selectedCategoryRef?.path,
                    icon: Icons.inventory_2_rounded,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: (c['ref'] as DocumentReference).path,
                            child: Text(
                              c['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final cat = categories.firstWhere(
                        (c) => (c['ref'] as DocumentReference).path == val,
                      );
                      setState(() {
                        selectedCategoryRef = cat['ref'];
                        selectedCategoryName = cat['name'];
                      });
                      _fetchSubCategories();
                    },
                    onAddPressed: _showAddCategoryDialog,
                    tooltip: 'Add new Material Name / Category',
                  ),
                  const SizedBox(height: 18),

                  // Field 2: Material Sub Name / Subcategory + (+) Button
                  _buildDropdownWithAddButton(
                    label: 'Material Sub Name / Subcategory',
                    hintText: isLoadingSubCategories
                        ? 'Loading subcategories...'
                        : (subCategories.isEmpty
                            ? 'No subcategories (Click + to add)'
                            : 'Select Subcategory'),
                    value: selectedSubCategoryRef?.path,
                    icon: Icons.subdirectory_arrow_right_rounded,
                    items: subCategories
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: (s['ref'] as DocumentReference).path,
                            child: Text(
                              s['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final sub = subCategories.firstWhere(
                        (s) => (s['ref'] as DocumentReference).path == val,
                      );
                      setState(() {
                        selectedSubCategoryRef = sub['ref'];
                        selectedSubCategoryName = sub['name'];
                      });
                      if (sub['unitRef'] != null) {
                        _matchAndSelectUnit(sub['unitRef']);
                      }
                      _updateMaterialMasterName();
                    },
                    onAddPressed: _showAddSubCategoryDialog,
                    tooltip: 'Add new Subcategory under $selectedCategoryName',
                  ),
                  const SizedBox(height: 18),

                  // Field 3: Material Master Name (Generated / Configured)
                  _buildCustomTextField(
                    controller: materialNameController,
                    label: 'Material Master Name',
                    icon: Icons.auto_awesome_rounded,
                    readOnly: false,
                    helperText: 'Auto-combined: [Material]_[Subcategory]',
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Material Master Name is required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Field 4: Material Unit + (+) Button
                  _buildDropdownWithAddButton(
                    label: 'Material Unit',
                    hintText: isLoadingUnits ? 'Loading units...' : 'Select Material Unit',
                    value: selectedUnitRef?.path,
                    icon: Icons.straighten_rounded,
                    items: units
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: (u['ref'] as DocumentReference).path,
                            child: Text(
                              u['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final u = units.firstWhere(
                        (u) => (u['ref'] as DocumentReference).path == val,
                      );
                      setState(() {
                        selectedUnitRef = u['ref'];
                        selectedUnitName = u['name'];
                      });
                    },
                    onAddPressed: _showAddUnitDialog,
                    tooltip: 'Add new measurement unit',
                  ),
                  const SizedBox(height: 18),

                  // Field 5: Material Price
                  _buildCustomTextField(
                    controller: unitPriceController,
                    label: 'Material Price',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    hintText: 'Enter unit price (e.g. 380)',
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Please enter material price';
                      final numVal = num.tryParse(text);
                      if (numVal == null || numVal < 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Field 6: Description (Optional)
                  _buildCustomTextField(
                    controller: descriptionController,
                    label: 'Description / Notes (Optional)',
                    icon: Icons.description_outlined,
                    maxLines: 2,
                    hintText: 'Add specifications, grade, manufacturer or notes...',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _resetForm,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'SAVE MATERIAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // --- 6. UPDATE & MANAGE TAB ---

  Widget _buildUpdateTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    final filteredMaterials = materials.where((m) {
      final name = m['materialName'].toString().toLowerCase();
      final id = m['materialId'].toString().toLowerCase();
      final cat = m['materialCategory'].toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return _searchQuery.isEmpty ||
          name.contains(q) ||
          id.contains(q) ||
          cat.contains(q);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.manage_search_rounded, color: primaryColor, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Material Directory',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${materials.length} Configured',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF0A183D),
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search material by name, category, or ID...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.search_rounded, color: primaryColor, size: 18),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selected Material Quick Price Editor
          if (selectedMaterialForUpdate != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedMaterialForUpdate!['materialName'] ?? '',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A183D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'ID: ${selectedMaterialForUpdate!['materialId']} | Unit: ${selectedMaterialForUpdate!['materialUnit']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showEditMaterialModal(selectedMaterialForUpdate!),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                          backgroundColor: primaryColor.withValues(alpha: 0.06),
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: const Text(
                          'Edit All',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Delete Material',
                        child: InkWell(
                          onTap: () => _confirmDeleteMaterial(selectedMaterialForUpdate!),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildCustomTextField(
                          controller: updatePriceController,
                          label: 'Update Material Price',
                          icon: Icons.currency_rupee_rounded,
                          readOnly: !isEditingPrice,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => isEditingPrice = !isEditingPrice);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditingPrice
                                  ? const Color(0xFFEF4444)
                                  : primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: Icon(
                              isEditingPrice ? Icons.close_rounded : Icons.edit_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isEditingPrice) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isSavingPriceUpdate
                            ? null
                            : () async {
                                final newPrice = updatePriceController.text.trim();
                                if (newPrice.isEmpty) return;
                                setState(() => isSavingPriceUpdate = true);
                                try {
                                  final docRef = selectedMaterialForUpdate!['ref'] as DocumentReference;
                                  await docRef.update({
                                    'materialPrice': newPrice,
                                    'unitPrice': num.tryParse(newPrice) ?? 0,
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Price updated successfully!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                    await _fetchMaterials();
                                    setState(() => isEditingPrice = false);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to update price: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => isSavingPriceUpdate = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSavingPriceUpdate
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'SAVE NEW PRICE',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Material List
          if (filteredMaterials.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching materials found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Try changing your search term or configure a new material',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredMaterials.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final mat = filteredMaterials[index];
                final isSelected = selectedMaterialForUpdate != null &&
                    (selectedMaterialForUpdate!['ref'] as DocumentReference).path ==
                        (mat['ref'] as DocumentReference).path;

                return InkWell(
                  onTap: () => _onSelectMaterialForUpdate(mat),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mat['materialName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      mat['materialId'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• Unit: ${mat['materialUnit']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '₹${mat['materialPrice']}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Edit Material Details',
                          child: InkWell(
                            onTap: () => _showEditMaterialModal(mat),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Color(0xFF0A183D),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Delete Material',
                          child: InkWell(
                            onTap: () => _confirmDeleteMaterial(mat),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // --- 7. HELPER WIDGETS ---

  Widget _buildFieldLabel(String label, {String? helperText}) {
    final isRequired = label.contains('*');
    final cleanText = label.replaceAll('*', '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: cleanText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
            letterSpacing: -0.1,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            if (helperText != null)
              TextSpan(
                text: '  ($helperText)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownWithAddButton({
    required String label,
    required String hintText,
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required VoidCallback onAddPressed,
    required String tooltip,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
    final validValue = (value != null && items.any((i) => i.value == value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(validValue),
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                initialValue: validValue,
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      icon,
                      color: brandIconColor,
                      size: 18,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: brandIconColor, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                ),
                items: items,
                onChanged: onChanged,
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 10),
            // Plus (+) Button
            Tooltip(
              message: tooltip,
              child: Material(
                color: brandIconColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onAddPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? hintText,
    String? helperText,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, helperText: helperText),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          textAlignVertical: maxLines == 1 ? TextAlignVertical.center : TextAlignVertical.top,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: readOnly ? const Color(0xFF475569) : const Color(0xFF0A183D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText ?? 'Enter ${label.replaceAll('*', '').trim()}',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: 38,
              minHeight: maxLines == 1 ? 38 : 24,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 8,
                top: maxLines > 1 ? 12 : 0,
              ),
              child: Icon(
                icon,
                color: brandIconColor,
                size: 18,
              ),
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 12 : 12.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteMaterial(Map<String, dynamic> mat) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Material?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete material "${mat['materialName']}" (${mat['materialId']})?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone. Any references to this material configuration will be removed.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteMaterial(mat);
    }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> mat) async {
    try {
      final docRef = mat['ref'] as DocumentReference? ??
          FirestoreService.materials.doc(mat['materialId'] ?? mat['id']);
      await docRef.delete();

      if (selectedMaterialForUpdate != null &&
          (selectedMaterialForUpdate!['ref'] as DocumentReference).path == docRef.path) {
        setState(() {
          selectedMaterialForUpdate = null;
          updatePriceController.clear();
        });
      }

      await _fetchMaterials();
      await _fetchNextMaterialId();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material "${mat['materialName']}" deleted successfully'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete material: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showEditMaterialModal(Map<String, dynamic> mat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditMaterialModalSheet(
        material: mat,
        categories: categories,
        units: units,
        primaryColor: Theme.of(context).primaryColor,
        onFetchCategories: _fetchCategories,
        onFetchUnits: _fetchUnits,
        onMaterialUpdated: () async {
          await _fetchMaterials();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Material "${mat['materialName']}" updated successfully!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
        onMaterialDeleted: () async {
          if (selectedMaterialForUpdate != null &&
              (selectedMaterialForUpdate!['ref'] as DocumentReference).path ==
                  (mat['ref'] as DocumentReference).path) {
            setState(() {
              selectedMaterialForUpdate = null;
              updatePriceController.clear();
            });
          }
          await _fetchMaterials();
          await _fetchNextMaterialId();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Material "${mat['materialName']}" deleted successfully'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIT MATERIAL BOTTOM SHEET MODAL
// ---------------------------------------------------------------------------

class _EditMaterialModalSheet extends StatefulWidget {
  final Map<String, dynamic> material;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final Color primaryColor;
  final Future<void> Function({DocumentReference? selectRef}) onFetchCategories;
  final Future<void> Function({DocumentReference? selectRef}) onFetchUnits;
  final VoidCallback onMaterialUpdated;
  final VoidCallback onMaterialDeleted;

  const _EditMaterialModalSheet({
    required this.material,
    required this.categories,
    required this.units,
    required this.primaryColor,
    required this.onFetchCategories,
    required this.onFetchUnits,
    required this.onMaterialUpdated,
    required this.onMaterialDeleted,
  });

  @override
  State<_EditMaterialModalSheet> createState() => _EditMaterialModalSheetState();
}

class _EditMaterialModalSheetState extends State<_EditMaterialModalSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;

  DocumentReference? _selectedCategoryRef;
  String? _selectedCategoryName;
  DocumentReference? _selectedSubCategoryRef;
  String? _selectedSubCategoryName;
  DocumentReference? _selectedUnitRef;
  String? _selectedUnitName;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  List<Map<String, dynamic>> _units = [];

  bool _isLoadingSubCategories = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _units = List.from(widget.units);

    _idController = TextEditingController(
      text: widget.material['materialId']?.toString() ?? widget.material['id']?.toString() ?? '',
    );
    _nameController = TextEditingController(
      text: widget.material['materialName']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.material['materialPrice']?.toString() ?? '',
    );
    _descController = TextEditingController(
      text: widget.material['description']?.toString() ?? '',
    );

    _initSelections();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  int _calcNextIdNumber(QuerySnapshot snapshot, String prefix) {
    final ids = snapshot.docs
        .map((doc) {
          final docId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          final fieldId = data?['materialId']?.toString() ?? '';
          if (docId.startsWith(prefix)) return docId;
          if (fieldId.startsWith(prefix)) return fieldId;
          return docId;
        })
        .where((id) => id.startsWith(prefix))
        .map((id) => int.tryParse(id.substring(prefix.length)) ?? 0)
        .toList();

    if (ids.isEmpty) return 1;
    ids.sort();
    return ids.last + 1;
  }

  void _initSelections() {
    // Match Category
    final rawCatRef = widget.material['materialCategoryRef'] as DocumentReference?;
    final rawCatName = widget.material['materialCategory']?.toString().trim().toLowerCase() ?? '';

    if (rawCatRef != null && _categories.any((c) => (c['ref'] as DocumentReference).path == rawCatRef.path)) {
      final match = _categories.firstWhere((c) => (c['ref'] as DocumentReference).path == rawCatRef.path);
      _selectedCategoryRef = match['ref'];
      _selectedCategoryName = match['name'];
    } else if (rawCatName.isNotEmpty && _categories.any((c) => (c['name'] as String).toLowerCase() == rawCatName)) {
      final match = _categories.firstWhere((c) => (c['name'] as String).toLowerCase() == rawCatName);
      _selectedCategoryRef = match['ref'];
      _selectedCategoryName = match['name'];
    } else if (_categories.isNotEmpty) {
      _selectedCategoryRef = _categories.first['ref'];
      _selectedCategoryName = _categories.first['name'];
    }

    // Match Unit
    final rawUnitRef = widget.material['materialUnitRef'] as DocumentReference?;
    final rawUnitName = widget.material['materialUnit']?.toString().trim().toLowerCase() ?? '';

    if (rawUnitRef != null && _units.any((u) => (u['ref'] as DocumentReference).path == rawUnitRef.path)) {
      final match = _units.firstWhere((u) => (u['ref'] as DocumentReference).path == rawUnitRef.path);
      _selectedUnitRef = match['ref'];
      _selectedUnitName = match['name'];
    } else if (rawUnitName.isNotEmpty && _units.any((u) => (u['name'] as String).toLowerCase() == rawUnitName)) {
      final match = _units.firstWhere((u) => (u['name'] as String).toLowerCase() == rawUnitName);
      _selectedUnitRef = match['ref'];
      _selectedUnitName = match['name'];
    } else if (_units.isNotEmpty) {
      _selectedUnitRef = _units.first['ref'];
      _selectedUnitName = _units.first['name'];
    }

    // Load subcategories for matched category
    _fetchSubCategories(
      initialSubCatRef: widget.material['materialSubCategoryRef'] as DocumentReference?,
      initialSubCatName: widget.material['materialSubCategory']?.toString(),
    );
  }

  Future<void> _fetchSubCategories({
    DocumentReference? selectRef,
    DocumentReference? initialSubCatRef,
    String? initialSubCatName,
  }) async {
    if (_selectedCategoryRef == null) {
      if (mounted) {
        setState(() {
          _subCategories = [];
          _selectedSubCategoryRef = null;
          _selectedSubCategoryName = null;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingSubCategories = true);
    try {
      final snapshot = await FirestoreService.materialSubCategories
          .where('matCategory', isEqualTo: _selectedCategoryRef)
          .get();

      if (!mounted) return;

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'ref': doc.reference,
              'id': doc.id,
              'name': (data['matSubCategory'] ?? '').toString().trim(),
              'unitRef': data['matUnit'] as DocumentReference?,
            };
          })
          .where((s) => (s['name'] as String).isNotEmpty)
          .toList();

      loaded.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
      );

      if (mounted) {
        setState(() {
          _subCategories = loaded;
          if (selectRef != null && _subCategories.any((s) => (s['ref'] as DocumentReference).path == selectRef.path)) {
            final item = _subCategories.firstWhere((s) => (s['ref'] as DocumentReference).path == selectRef.path);
            _selectedSubCategoryRef = item['ref'];
            _selectedSubCategoryName = item['name'];
          } else if (initialSubCatRef != null &&
              _subCategories.any((s) => (s['ref'] as DocumentReference).path == initialSubCatRef.path)) {
            final item = _subCategories.firstWhere((s) => (s['ref'] as DocumentReference).path == initialSubCatRef.path);
            _selectedSubCategoryRef = item['ref'];
            _selectedSubCategoryName = item['name'];
          } else if (initialSubCatName != null &&
              _subCategories.any((s) => (s['name'] as String).toLowerCase() == initialSubCatName.trim().toLowerCase())) {
            final item = _subCategories.firstWhere(
              (s) => (s['name'] as String).toLowerCase() == initialSubCatName.trim().toLowerCase(),
            );
            _selectedSubCategoryRef = item['ref'];
            _selectedSubCategoryName = item['name'];
          } else if (_subCategories.isNotEmpty) {
            _selectedSubCategoryRef = _subCategories.first['ref'];
            _selectedSubCategoryName = _subCategories.first['name'];
          } else {
            _selectedSubCategoryRef = null;
            _selectedSubCategoryName = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading subcategories in edit modal: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSubCategories = false);
    }
  }

  void _onCategoryChanged(String? refPath) {
    if (refPath == null) return;
    final match = _categories.firstWhere(
      (c) => (c['ref'] as DocumentReference).path == refPath,
      orElse: () => {},
    );
    if (match.isEmpty) return;

    setState(() {
      _selectedCategoryRef = match['ref'];
      _selectedCategoryName = match['name'];
    });

    _fetchSubCategories().then((_) {
      _updateMasterName();
    });
  }

  void _onSubCategoryChanged(String? refPath) {
    if (refPath == null) return;
    final match = _subCategories.firstWhere(
      (s) => (s['ref'] as DocumentReference).path == refPath,
      orElse: () => {},
    );
    if (match.isEmpty) return;

    setState(() {
      _selectedSubCategoryRef = match['ref'];
      _selectedSubCategoryName = match['name'];

      // If this subcategory has a preconfigured unit, match and auto-select it
      if (match['unitRef'] != null) {
        final uRef = match['unitRef'] as DocumentReference;
        if (_units.any((u) => (u['ref'] as DocumentReference).path == uRef.path)) {
          final uMatch = _units.firstWhere((u) => (u['ref'] as DocumentReference).path == uRef.path);
          _selectedUnitRef = uMatch['ref'];
          _selectedUnitName = uMatch['name'];
        }
      }
    });

    _updateMasterName();
  }

  void _onUnitChanged(String? refPath) {
    if (refPath == null) return;
    final match = _units.firstWhere(
      (u) => (u['ref'] as DocumentReference).path == refPath,
      orElse: () => {},
    );
    if (match.isEmpty) return;

    setState(() {
      _selectedUnitRef = match['ref'];
      _selectedUnitName = match['name'];
    });
  }

  void _updateMasterName() {
    final cat = _selectedCategoryName?.trim() ?? '';
    final sub = _selectedSubCategoryName?.trim() ?? '';
    if (cat.isNotEmpty && sub.isNotEmpty) {
      _nameController.text = '${cat}_$sub';
    } else if (cat.isNotEmpty) {
      _nameController.text = cat;
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final dialogKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: dialogKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inventory_2_rounded, color: widget.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Material Name',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              Text(
                                'Master Material Category (e.g. Cement, Steel, Sand)',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('Material Name / Category *'),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A183D)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. Cement, Steel, Bricks, Sand',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.category_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return 'Please enter material name';
                        if (_categories.any((c) => (c['name'] as String).toLowerCase() == text.toLowerCase())) {
                          return 'Material category already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: isSavingLocal
                                  ? null
                                  : () async {
                                      if (!dialogKey.currentState!.validate()) return;
                                      setDialogState(() => isSavingLocal = true);
                                      final catName = nameController.text.trim();
                                      final messenger = ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);

                                      try {
                                        final catCol = FirestoreService.materialCategories;
                                        final snap = await catCol.get();
                                        final nextId = _calcNextIdNumber(snap, 'MC');
                                        final docId = 'MC${nextId.toString().padLeft(3, '0')}';
                                        final docRef = catCol.doc(docId);

                                        await docRef.set({
                                          'matCategory': catName,
                                          'created_at': FieldValue.serverTimestamp(),
                                        });

                                        await widget.onFetchCategories(selectRef: docRef);

                                        // Refresh local categories
                                        final refreshSnap = await FirestoreService.materialCategories.get();
                                        final refreshedCats = refreshSnap.docs.map((d) {
                                          final data = d.data();
                                          return {
                                            'ref': d.reference,
                                            'id': d.id,
                                            'name': (data['matCategory'] ?? data['materialName'] ?? '').toString().trim(),
                                          };
                                        }).where((c) => (c['name'] as String).isNotEmpty).toList();
                                        refreshedCats.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

                                        if (mounted) {
                                          nav.pop();
                                          setState(() {
                                            _categories = refreshedCats;
                                            _selectedCategoryRef = docRef;
                                            _selectedCategoryName = catName;
                                          });
                                          await _fetchSubCategories();
                                          _updateMasterName();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Material Name "$catName" added successfully!'),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(SnackBar(content: Text('Failed to add category: $e')));
                                        }
                                      } finally {
                                        if (mounted) setDialogState(() => isSavingLocal = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                              ),
                              child: isSavingLocal
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('SAVE NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSubCategoryDialog() async {
    if (_selectedCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a Material Category first'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final subCatController = TextEditingController();
    final dialogKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: dialogKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.subdirectory_arrow_right_rounded, color: widget.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Subcategory',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              Text(
                                'Under "${_selectedCategoryName ?? ''}" (e.g. OPC, PPC, 12mm)',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('Subcategory Name *'),
                    TextFormField(
                      controller: subCatController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A183D)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. OPC 53 Grade, TMT 12mm, Fine Sand',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.label_important_outline_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return 'Please enter subcategory name';
                        if (_subCategories.any((s) => (s['name'] as String).toLowerCase() == text.toLowerCase())) {
                          return 'Subcategory already exists under this category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: isSavingLocal
                                  ? null
                                  : () async {
                                      if (!dialogKey.currentState!.validate()) return;
                                      setDialogState(() => isSavingLocal = true);
                                      final subCatName = subCatController.text.trim();
                                      final messenger = ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);

                                      try {
                                        final subCol = FirestoreService.materialSubCategories;
                                        final snap = await subCol.get();
                                        final nextId = _calcNextIdNumber(snap, 'MSC');
                                        final docId = 'MSC${nextId.toString().padLeft(3, '0')}';
                                        final docRef = subCol.doc(docId);

                                        await docRef.set({
                                          'matCategory': _selectedCategoryRef,
                                          'matSubCategory': subCatName,
                                          'created_at': FieldValue.serverTimestamp(),
                                        });

                                        if (mounted) {
                                          nav.pop();
                                          await _fetchSubCategories(selectRef: docRef);
                                          _updateMasterName();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Subcategory "$subCatName" added successfully!'),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(SnackBar(content: Text('Failed to add subcategory: $e')));
                                        }
                                      } finally {
                                        if (mounted) setDialogState(() => isSavingLocal = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                              ),
                              child: isSavingLocal
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('SAVE SUB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddUnitDialog() async {
    final unitController = TextEditingController();
    final dialogKey = GlobalKey<FormState>();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: dialogKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.straighten_rounded, color: widget.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Measurement Unit',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              Text(
                                'e.g. Bags, Kg, Ton, Liters, SqFt, Nos',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('Unit Name / Symbol *'),
                    TextFormField(
                      controller: unitController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A183D)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. Bags, Ton, Liters, Bundle',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return 'Please enter unit name';
                        if (_units.any((u) => (u['name'] as String).toLowerCase() == text.toLowerCase())) {
                          return 'Unit already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: isSavingLocal ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: isSavingLocal
                                  ? null
                                  : () async {
                                      if (!dialogKey.currentState!.validate()) return;
                                      setDialogState(() => isSavingLocal = true);
                                      final unitName = unitController.text.trim();
                                      final messenger = ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);

                                      try {
                                        final unitCol = FirestoreService.materialUnits;
                                        final snap = await unitCol.get();
                                        final nextId = _calcNextIdNumber(snap, 'MU');
                                        final docId = 'MU${nextId.toString().padLeft(3, '0')}';
                                        final docRef = unitCol.doc(docId);

                                        await docRef.set({
                                          'matUnit': unitName,
                                          'created_at': FieldValue.serverTimestamp(),
                                        });

                                        await widget.onFetchUnits(selectRef: docRef);

                                        // Refresh local units
                                        final refreshSnap = await FirestoreService.materialUnits.get();
                                        final refreshedUnits = refreshSnap.docs.map((d) {
                                          final data = d.data();
                                          return {
                                            'ref': d.reference,
                                            'id': d.id,
                                            'name': (data['matUnit'] ?? data['name'] ?? '').toString().trim(),
                                          };
                                        }).where((u) => (u['name'] as String).isNotEmpty).toList();
                                        refreshedUnits.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

                                        if (mounted) {
                                          nav.pop();
                                          setState(() {
                                            _units = refreshedUnits;
                                            _selectedUnitRef = docRef;
                                            _selectedUnitName = unitName;
                                          });
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Unit "$unitName" added successfully!'),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(SnackBar(content: Text('Failed to add unit: $e')));
                                        }
                                      } finally {
                                        if (mounted) setDialogState(() => isSavingLocal = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                              ),
                              child: isSavingLocal
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('SAVE UNIT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a Material Category'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    if (_selectedSubCategoryRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a Subcategory'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    if (_selectedUnitRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a Measurement Unit'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    setState(() => _isSaving = true);

    final masterName = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final priceNum = num.tryParse(priceStr) ?? 0;
    final description = _descController.text.trim();
    final materialId = _idController.text.trim();

    try {
      // Check duplicate masterName in other documents
      final duplicateQuery = await FirestoreService.materials
          .where('materialName', isEqualTo: masterName)
          .get();

      final currentDocId = widget.material['id']?.toString() ?? materialId;
      final duplicates = duplicateQuery.docs.where((d) => d.id != currentDocId && d.id != materialId).toList();

      if (duplicates.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Another material with name "$masterName" is already configured!'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      // Update existing Firestore document in-place
      final DocumentReference docRef = widget.material['ref'] as DocumentReference? ??
          FirestoreService.materials.doc(materialId);

      await docRef.set({
        'materialId': materialId,
        'materialCategoryRef': _selectedCategoryRef,
        'materialCategory': _selectedCategoryName,
        'materialSubCategoryRef': _selectedSubCategoryRef,
        'materialSubCategory': _selectedSubCategoryName,
        'materialName': masterName,
        'materialUnitRef': _selectedUnitRef,
        'materialUnit': _selectedUnitName,
        'materialPrice': priceStr,
        'unitPrice': priceNum,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMaterialUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update material: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteInModal() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Material?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete material "${widget.material['materialName']}" (${widget.material['materialId']})?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone. Any references to this material configuration will be removed.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final docRef = widget.material['ref'] as DocumentReference? ??
            FirestoreService.materials.doc(widget.material['materialId'] ?? widget.material['id']);
        await docRef.delete();
        if (mounted) {
          Navigator.pop(context);
          widget.onMaterialDeleted();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete material: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Widget _buildFieldLabel(String label, {String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
              letterSpacing: 0.2,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                helperText,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? hintText,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, helperText: helperText),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          textAlignVertical: maxLines == 1 ? TextAlignVertical.center : TextAlignVertical.top,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: readOnly ? const Color(0xFF475569) : const Color(0xFF0A183D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText ?? 'Enter ${label.replaceAll('*', '').trim()}',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500),
            prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: maxLines == 1 ? 38 : 24),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8, top: maxLines > 1 ? 12 : 0),
              child: Icon(icon, color: widget.primaryColor, size: 18),
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 12 : 12.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.primaryColor, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWithAddButton({
    required String label,
    required String hintText,
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required VoidCallback onAddPressed,
    required String tooltip,
    bool isLoading = false,
  }) {
    final validValue = (value != null && items.any((i) => i.value == value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(validValue),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    initialValue: validValue,
                    style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: isLoading ? 'Loading...' : hintText,
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500),
                      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(icon, color: widget.primaryColor, size: 18),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.primaryColor, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0)),
                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
                    ),
                    items: items,
                    onChanged: onChanged,
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  if (isLoading)
                    const Positioned(
                      right: 36,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: tooltip,
              child: Material(
                color: widget.primaryColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onAddPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final categoryItems = _categories.map((c) {
      final ref = c['ref'] as DocumentReference;
      return DropdownMenuItem<String>(
        value: ref.path,
        child: Text(
          c['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0A183D)),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    final subCategoryItems = _subCategories.map((s) {
      final ref = s['ref'] as DocumentReference;
      return DropdownMenuItem<String>(
        value: ref.path,
        child: Text(
          s['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0A183D)),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    final unitItems = _units.map((u) {
      final ref = u['ref'] as DocumentReference;
      return DropdownMenuItem<String>(
        value: ref.path,
        child: Text(
          u['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0A183D)),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: widget.primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Material Configuration',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Update master record, unit, or pricing',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSaving ? null : _confirmDeleteInModal,
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  splashRadius: 20,
                  tooltip: 'Delete Material',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: bottomInset > 0 ? bottomInset + 16 : 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Material ID (Read-only)
                    _buildCustomTextField(
                      controller: _idController,
                      label: 'Material ID (Read-only)',
                      icon: Icons.fingerprint_rounded,
                      readOnly: true,
                      helperText: 'Permanent record identifier',
                    ),
                    const SizedBox(height: 16),

                    // Material Category
                    _buildDropdownWithAddButton(
                      label: 'Material Category / Name *',
                      hintText: 'Select Material Category',
                      value: _selectedCategoryRef?.path,
                      icon: Icons.category_rounded,
                      items: categoryItems,
                      onChanged: _onCategoryChanged,
                      onAddPressed: _showAddCategoryDialog,
                      tooltip: 'Add new category',
                    ),
                    const SizedBox(height: 16),

                    // Subcategory
                    _buildDropdownWithAddButton(
                      label: 'Subcategory *',
                      hintText: _selectedCategoryRef == null ? 'Select category first' : 'Select Subcategory',
                      value: _selectedSubCategoryRef?.path,
                      icon: Icons.subdirectory_arrow_right_rounded,
                      items: subCategoryItems,
                      onChanged: _onSubCategoryChanged,
                      onAddPressed: _showAddSubCategoryDialog,
                      tooltip: 'Add new subcategory',
                      isLoading: _isLoadingSubCategories,
                    ),
                    const SizedBox(height: 16),

                    // Master Material Name
                    _buildCustomTextField(
                      controller: _nameController,
                      label: 'Material Master Name *',
                      icon: Icons.label_rounded,
                      hintText: 'e.g. Cement_OPC 53 Grade',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Material Master Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Unit & Price in a responsive Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildDropdownWithAddButton(
                            label: 'Measurement Unit *',
                            hintText: 'Select Unit',
                            value: _selectedUnitRef?.path,
                            icon: Icons.straighten_rounded,
                            items: unitItems,
                            onChanged: _onUnitChanged,
                            onAddPressed: _showAddUnitDialog,
                            tooltip: 'Add new unit',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: _buildCustomTextField(
                            controller: _priceController,
                            label: 'Material Price (₹) *',
                            icon: Icons.currency_rupee_rounded,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Price required';
                              final numVal = num.tryParse(val.trim());
                              if (numVal == null || numVal <= 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildCustomTextField(
                      controller: _descController,
                      label: 'Description (Optional)',
                      icon: Icons.description_rounded,
                      maxLines: 2,
                      hintText: 'Extra specifications, quality grades, notes...',
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1.5,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'SAVE CHANGES',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}

