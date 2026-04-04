import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
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
  final _updateFormKey = GlobalKey<FormState>();
  late TabController _tabController;

  DocumentReference? selectedCategoryRef;
  String? selectedCategoryName;
  DocumentReference? selectedSubCategoryRef;
  String? selectedSubCategoryName;
  DocumentReference? selectedUnitRef;
  String? selectedUnitName;

  final materialIdController = TextEditingController();
  final materialNameController = TextEditingController();
  final unitPriceController = TextEditingController();
  final descriptionController = TextEditingController();
  final materialUnitController = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subCategories = [];
  bool isLoadingCategories = true;
  bool isLoadingSubCategories = false;
  bool isLoadingUnits = false;
  bool isLoadingMaterialId = false;
  bool _isSaving = false;
  bool _isSaved = false;

  List<Map<String, dynamic>> materials = [];
  bool isLoadingMaterials = false;
  DocumentReference? selectedMaterialRef;
  String? selectedMaterialId;
  String? selectedMaterialUnit;
  String? selectedMaterialPrice;
  bool isEditingPrice = false;
  final updateMaterialIdController = TextEditingController();
  final updateMaterialUnitController = TextEditingController();
  final updateMaterialPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCategories();
    _fetchNextMaterialId();
    _fetchMaterials();
  }

  @override
  void dispose() {
    materialIdController.dispose();
    materialNameController.dispose();
    unitPriceController.dispose();
    descriptionController.dispose();
    updateMaterialIdController.dispose();
    updateMaterialUnitController.dispose();
    updateMaterialPriceController.dispose();
    materialUnitController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    if (mounted) setState(() => isLoadingCategories = true);
    try {
      final snapshot = await FirestoreService.materialCategories.get();
      if (!mounted) return;
      categories = snapshot.docs
          .map(
            (doc) => {
              'ref': doc.reference,
              'name': doc['matCategory'] as String,
            },
          )
          .toList();
      if (categories.isNotEmpty) {
        selectedCategoryRef = categories.first['ref'];
        selectedCategoryName = categories.first['name'];
        await _fetchSubCategories();
      }
    } finally {
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> _fetchSubCategories() async {
    if (selectedCategoryRef == null) {
      if (mounted) {
        setState(() {
          subCategories = [];
          selectedSubCategoryRef = null;
          selectedUnitName = null;
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
      subCategories = snapshot.docs
          .map(
            (doc) => {
              'ref': doc.reference,
              'name': doc['matSubCategory'] as String,
              'unitRef': doc['matUnit'] as DocumentReference,
            },
          )
          .toList();
      if (subCategories.isNotEmpty) {
        selectedSubCategoryRef = subCategories.first['ref'];
        selectedSubCategoryName = subCategories.first['name'];
        await _fetchUnitName(subCategories.first['unitRef']);
        if (!mounted) return;
      } else {
        selectedSubCategoryRef = null;
        selectedUnitName = null;
      }
      _updateMaterialName();
    } finally {
      if (mounted) {
        setState(() => isLoadingSubCategories = false);
      }
    }
  }

  Future<void> _fetchUnitName(DocumentReference unitRef) async {
    if (mounted) setState(() => isLoadingUnits = true);
    try {
      final doc = await unitRef.get();
      if (!mounted) return;
      selectedUnitRef = unitRef;
      selectedUnitName = doc['matUnit'] as String;
      materialUnitController.text = selectedUnitName ?? '';
    } finally {
      if (mounted) setState(() => isLoadingUnits = false);
    }
  }

  Future<void> _fetchNextMaterialId() async {
    if (mounted) setState(() => isLoadingMaterialId = true);
    try {
      final snapshot = await FirestoreService.materials
          .orderBy('materialId', descending: true)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final String lastId = snapshot.docs.first['materialId'];
        final int lastNum = int.tryParse(lastId.replaceAll('MT', '')) ?? 0;
        materialIdController.text =
            'MT${(lastNum + 1).toString().padLeft(3, '0')}';
      } else {
        materialIdController.text = 'MT001';
      }
    } finally {
      if (mounted) setState(() => isLoadingMaterialId = false);
    }
  }

  void _updateMaterialName() {
    if (!mounted) return;
    if ((selectedCategoryName ?? '').isNotEmpty &&
        (selectedSubCategoryName ?? '').isNotEmpty) {
      materialNameController.text =
          '${selectedCategoryName}_$selectedSubCategoryName';
    } else {
      materialNameController.text = '';
    }
    if (mounted) setState(() {});
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate() || _isSaving || _isSaved) return;
    setState(() => _isSaving = true);

    final name = materialNameController.text.trim();
    final price = unitPriceController.text;
    final description = descriptionController.text;

    try {
      final materialsRef = FirestoreService.getCollection('materials');
      final duplicate = await materialsRef
          .where('materialName', isEqualTo: name)
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name already exists'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final counterRef = FirestoreService.getCollection(
        'counters',
      ).doc('materials');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        int nextNum =
            (counterSnap.exists
                ? (counterSnap.get('lastMaterialId') ?? 0)
                : 0) +
            1;
        String id = 'MT${nextNum.toString().padLeft(3, '0')}';

        transaction.set(materialsRef.doc(id), {
          'materialId': id,
          'materialName': name,
          'materialCategory': selectedCategoryRef,
          'materialSubCategory': selectedSubCategoryRef,
          'materialUnit': selectedUnitRef,
          'materialPrice': price,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(counterRef, {
          'lastMaterialId': nextNum,
        }, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material Saved'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    if (!mounted) return;
    materialNameController.clear();
    unitPriceController.clear();
    descriptionController.clear();
    materialUnitController.clear();
    if (mounted) {
      setState(() {
        _isSaved = false;
        _fetchCategories();
        _fetchNextMaterialId();
      });
    }
  }

  Future<void> _fetchMaterials() async {
    if (mounted) setState(() => isLoadingMaterials = true);
    try {
      final snapshot = await FirestoreService.materials
          .orderBy('materialId')
          .limit(50)
          .get();
      if (!mounted) return;
      materials = snapshot.docs
          .map(
            (doc) => {
              'ref': doc.reference,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();
    } finally {
      if (mounted) setState(() => isLoadingMaterials = false);
    }
  }

  void _onMaterialSelected(Map<String, dynamic> data) async {
    selectedMaterialRef = data['ref'];
    selectedMaterialId = data['materialId'];
    selectedMaterialPrice = data['materialPrice']?.toString() ?? '';
    updateMaterialIdController.text = selectedMaterialId ?? '';
    updateMaterialPriceController.text = selectedMaterialPrice ?? '';

    if (data['materialUnit'] is DocumentReference) {
      final unitSnap = await (data['materialUnit'] as DocumentReference).get();
      if (!mounted) return;
      if (unitSnap.exists) {
        selectedMaterialUnit = unitSnap['matUnit'] as String?;
      }
    } else {
      selectedMaterialUnit = data['materialUnit']?.toString();
    }
    if (mounted) {
      updateMaterialUnitController.text = selectedMaterialUnit ?? '';
      setState(() => isEditingPrice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      title: 'Material Config',
      appBarBackgroundColor: theme.colorScheme.primary,
      appBarForegroundColor: theme.colorScheme.onPrimary,
      body: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'NEW MATERIAL'),
                Tab(text: 'UPDATE MATERIAL'),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildNewTab(), _buildUpdateTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Core Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: materialIdController,
                    label: 'Material ID',
                    icon: Icons.tag,
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'Category',
                    value: selectedCategoryRef?.path,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: (c['ref'] as DocumentReference).path,
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final cat = categories.firstWhere(
                        (c) => (c['ref'] as DocumentReference).path == v,
                      );
                      setState(() {
                        selectedCategoryRef = cat['ref'];
                        selectedCategoryName = cat['name'];
                      });
                      _fetchSubCategories();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'Sub Category',
                    value: selectedSubCategoryRef?.path,
                    items: subCategories
                        .map(
                          (s) => DropdownMenuItem(
                            value: (s['ref'] as DocumentReference).path,
                            child: Text(s['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final sub = subCategories.firstWhere(
                        (s) => (s['ref'] as DocumentReference).path == v,
                      );
                      setState(() {
                        selectedSubCategoryRef = sub['ref'];
                        selectedSubCategoryName = sub['name'];
                        selectedUnitRef = sub['unitRef'];
                      });
                      _fetchUnitName(sub['unitRef']);
                      _updateMaterialName();
                    },
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: materialNameController,
                    label: 'Material Name',
                    icon: Icons.label_outline,
                    readOnly: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pricing & Specs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: materialUnitController,
                    label: 'Unit',
                    icon: Icons.square_foot,
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: unitPriceController,
                    label: 'Unit Price',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'SAVE MATERIAL',
                    onPressed: _isSaving ? null : _saveForm,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'RESET',
                    onPressed: _resetForm,
                    isSecondary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _updateFormKey,
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Material',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (v) => materials.where(
                      (m) => m['materialName']
                          .toString()
                          .toLowerCase()
                          .contains(v.text.toLowerCase()),
                    ),
                    displayStringForOption: (m) => m['materialName'].toString(),
                    fieldViewBuilder: (ctx, ctrl, node, onSub) {
                      return GlassTextField(
                        controller: ctrl,
                        node: node,
                        label: 'Material Name',
                        icon: Icons.search,
                      );
                    },
                    onSelected: _onMaterialSelected,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: updateMaterialIdController,
                    label: 'Material ID',
                    icon: Icons.tag,
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: updateMaterialUnitController,
                    label: 'Unit',
                    icon: Icons.square_foot,
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: updateMaterialPriceController,
                          label: 'Update Price',
                          icon: Icons.currency_rupee,
                          readOnly: !isEditingPrice,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 0,
                        child: IconButton.filledTonal(
                          onPressed: selectedMaterialRef == null
                              ? null
                              : () => setState(
                                  () => isEditingPrice = !isEditingPrice,
                                ),
                          icon: Icon(isEditingPrice ? Icons.close : Icons.edit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (isEditingPrice)
              GlassButton(
                label: 'UPDATE PRICE',
                onPressed: () async {
                  final price = updateMaterialPriceController.text;
                  await selectedMaterialRef!.update({'materialPrice': price});
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Price Updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchMaterials();
                  if (mounted) setState(() => isEditingPrice = false);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.any((i) => i.value == value))
          ? value
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.list_alt,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        filled: true,
        fillColor: theme.cardColor,
      ),
      items: items,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
