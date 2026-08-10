import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1942),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B1942).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Material Config',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Tab Bar Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFFCBD5E1),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'NEW MATERIAL'),
                  Tab(text: 'UPDATE MATERIAL'),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildNewTab(), _buildUpdateTab()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTab() {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Core Details Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Core Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Define primary material specifications',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildCustomTextField(
                    controller: materialIdController,
                    label: 'Material ID',
                    icon: Icons.tag_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildWhiteDropdown(
                    label: 'Category',
                    value: selectedCategoryRef?.path,
                    icon: Icons.category_rounded,
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
                  const SizedBox(height: 16),
                  _buildWhiteDropdown(
                    label: 'Sub Category',
                    value: selectedSubCategoryRef?.path,
                    icon: Icons.subdirectory_arrow_right_rounded,
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
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: materialNameController,
                    label: 'Material Name',
                    icon: Icons.label_outline_rounded,
                    readOnly: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pricing & Specs Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pricing & Specs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Set unit measurement and pricing details',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildCustomTextField(
                    controller: materialUnitController,
                    label: 'Unit',
                    icon: Icons.square_foot_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: unitPriceController,
                    label: 'Unit Price',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _resetForm,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: darkCardBg, width: 1.8),
                        alignment: Alignment.center,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Center(
                        child: Text(
                          'RESET',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: darkCardBg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: const Color(0xFF0A183D),
                        alignment: Alignment.center,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                        shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF0A183D),
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Center(
                              child: Text(
                                'SAVE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF0A183D),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateTab() {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _updateFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search & Update',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select an existing material to modify price',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildWhiteDropdown(
                    label: 'Material Name',
                    value: selectedMaterialRef?.path,
                    icon: Icons.search_rounded,
                    hintText: 'Search Material Name',
                    items: materials
                        .map(
                          (m) => DropdownMenuItem(
                            value: (m['ref'] as DocumentReference).path,
                            child: Text(m['materialName'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final mat = materials.firstWhere(
                        (m) => (m['ref'] as DocumentReference).path == v,
                      );
                      _onMaterialSelected(mat);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: updateMaterialIdController,
                    label: 'Material ID',
                    icon: Icons.tag_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: updateMaterialUnitController,
                    label: 'Unit',
                    icon: Icons.square_foot_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildCustomTextField(
                          controller: updateMaterialPriceController,
                          label: 'Update Price',
                          icon: Icons.currency_rupee_rounded,
                          readOnly: !isEditingPrice,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: selectedMaterialRef == null
                                ? null
                                : () => setState(
                                    () => isEditingPrice = !isEditingPrice,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditingPrice
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Icon(
                              isEditingPrice ? Icons.close_rounded : Icons.edit_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (isEditingPrice)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final price = updateMaterialPriceController.text;
                    await selectedMaterialRef!.update({'materialPrice': price});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Price Updated Successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchMaterials();
                    if (mounted) setState(() => isEditingPrice = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: const Color(0xFF0A183D),
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                  ),
                  child: const Center(
                    child: Text(
                      'UPDATE PRICE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
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
  }) {
    final brandIconColor = AppTheme.getDarkAccent(Theme.of(context).primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
                  size: 22,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData icon = Icons.list_alt_rounded,
    String? hintText,
  }) {
    final brandIconColor = AppTheme.getDarkAccent(Theme.of(context).primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            initialValue: (value != null && items.any((i) => i.value == value))
                ? value
                : null,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText ?? 'Select $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
                  size: 22,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: items,
            onChanged: onChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}
