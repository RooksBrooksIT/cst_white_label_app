import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
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
  final searchController = TextEditingController();
  String _searchQuery = '';

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
    searchController.dispose();
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
          .get();
      if (duplicate.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material with this name already exists'),
          ),
        );
        return;
      }
    } catch (_) {}

    try {
      await FirestoreService.materials.add({
        'materialId': materialIdController.text,
        'materialCategoryRef': selectedCategoryRef,
        'materialSubCategoryRef': selectedSubCategoryRef,
        'materialName': name,
        'materialUnitRef': selectedUnitRef,
        'materialPrice': price,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material Saved Successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _isSaved = true);
      _resetForm();
      _fetchNextMaterialId();
      _fetchMaterials();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save material: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        String unitName = '';

        if (data['materialUnitRef'] != null) {
          try {
            final unitDoc =
                await (data['materialUnitRef'] as DocumentReference).get();
            unitName = unitDoc['matUnit'] ?? '';
          } catch (_) {}
        }

        loadedMaterials.add({
          'ref': doc.reference,
          'materialId': data['materialId'] ?? '',
          'materialName': data['materialName'] ?? '',
          'materialPrice': data['materialPrice'] ?? '',
          'materialUnit': unitName,
        });
      }

      if (mounted) {
        setState(() {
          materials = loadedMaterials;
          if (materials.isNotEmpty) {
            _onMaterialSelected(materials.first);
          } else {
            selectedMaterialRef = null;
            selectedMaterialId = null;
            selectedMaterialUnit = null;
            selectedMaterialPrice = null;
            updateMaterialIdController.clear();
            updateMaterialUnitController.clear();
            updateMaterialPriceController.clear();
          }
        });
      }
    } finally {
      if (mounted) setState(() => isLoadingMaterials = false);
    }
  }

  void _onMaterialSelected(Map<String, dynamic> mat) {
    setState(() {
      selectedMaterialRef = mat['ref'];
      selectedMaterialId = mat['materialId'];
      selectedMaterialUnit = mat['materialUnit'];
      selectedMaterialPrice = mat['materialPrice'];

      updateMaterialIdController.text = selectedMaterialId ?? '';
      updateMaterialUnitController.text = selectedMaterialUnit ?? '';
      updateMaterialPriceController.text = selectedMaterialPrice ?? '';
      isEditingPrice = false;
    });
  }

  void _resetForm() {
    setState(() {
      if (categories.isNotEmpty) {
        selectedCategoryRef = categories.first['ref'];
        selectedCategoryName = categories.first['name'];
      }
      unitPriceController.clear();
      descriptionController.clear();
      _isSaved = false;
    });
    _fetchSubCategories();
  }

  void _showMaterialSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String modalQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = materials.where((m) {
              final name = m['materialName'].toString().toLowerCase();
              final id = m['materialId'].toString().toLowerCase();
              return modalQuery.isEmpty ||
                  name.contains(modalQuery.toLowerCase()) ||
                  id.contains(modalQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.manage_search_rounded, color: Color(0xFF0A183D), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Find Material',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setModalState(() => modalQuery = val),
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search material by name or MT-ID...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0A183D), size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching materials found.',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, index) {
                              final mat = filteredList[index];
                              final isSelected = selectedMaterialRef == mat['ref'];
                              return ListTile(
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 18),
                                ),
                                title: Text(
                                  mat['materialName'] ?? '',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                    color: const Color(0xFF0A183D),
                                    fontSize: 14.5,
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: ${mat['materialId']} | Unit: ${mat['materialUnit']}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${mat['materialPrice']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  _onMaterialSelected(mat);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Config',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            // Tab Bar Switcher Container
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
                  Tab(text: 'NEW MATERIAL'),
                  Tab(text: 'UPDATE MATERIAL'),
                ],
              ),
            ),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
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
    final primaryColor = theme.primaryColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Core Details Card
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
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Core Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Define primary material specifications',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const Row(
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Pricing & Specs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set unit measurement and pricing details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
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
            const SizedBox(height: 24),

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
                        alignment: Alignment.center,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'RESET',
                          textAlign: TextAlign.center,
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
                      onPressed: _isSaving ? null : _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        alignment: Alignment.center,
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
                              child: Text(
                                'SAVE MATERIAL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    final filteredMaterials = materials.where((m) {
      final name = m['materialName'].toString().toLowerCase();
      final id = m['materialId'].toString().toLowerCase();
      return _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Form(
        key: _updateFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Search & Material Finder Bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.manage_search_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Easy Material Finder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showMaterialSearchSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.list_alt_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Full List (${materials.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type to filter material by name or MT-ID...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Card
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
                  const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Search & Update',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select an existing material to modify price',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildWhiteDropdown(
                    label: 'Material Name',
                    value: selectedMaterialRef?.path,
                    icon: Icons.search_rounded,
                    hintText: 'Select Material Name',
                    items: filteredMaterials
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
                          width: 48,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: selectedMaterialRef == null
                                ? null
                                : () => setState(
                                    () => isEditingPrice = !isEditingPrice,
                                  ),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isEditingPrice)
              SizedBox(
                height: 50,
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
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: const Center(
                    child: Text(
                      'UPDATE PRICE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
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
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
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
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
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
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
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
