import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class MatlsSubCat extends StatefulWidget {
  const MatlsSubCat({super.key});

  @override
  State<MatlsSubCat> createState() => _MatlsSubCatState();
}

class _MatlsSubCatState extends State<MatlsSubCat> {
  final _categoriesRef = FirestoreService.getCollection('materialCategories');
  final _unitsRef = FirestoreService.getCollection('materialUnits');
  final _subCatRef = FirestoreService.getCollection('materialSubCategories');

  List<DocumentSnapshot> _categories = [];
  List<DocumentSnapshot> _units = [];

  DocumentSnapshot? _selectedCategory;
  DocumentSnapshot? _selectedUnit;
  final TextEditingController _subCategoryController = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final categoriesSnap = await _categoriesRef.get();
      final unitsSnap = await _unitsRef.get();
      setState(() {
        _categories = categoriesSnap.docs;
        _units = unitsSnap.docs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dropdown data: $e')),
        );
      }
    }
  }

  Future<String> _generateSubCategoryId() async {
    final query = await _subCatRef.get();
    final Set<int> existingSerials = {};
    for (var doc in query.docs) {
      final id = doc.id;
      final match = RegExp(r'^MSC(\d{3})$').firstMatch(id);
      if (match != null) {
        final serial = int.tryParse(match.group(1) ?? '0') ?? 0;
        existingSerials.add(serial);
      }
    }

    int nextSerial = 1;
    while (existingSerials.contains(nextSerial)) {
      nextSerial++;
    }
    final serialStr = nextSerial.toString().padLeft(3, '0');
    return 'MSC$serialStr';
  }

  Future<void> _save() async {
    final category = _selectedCategory;
    final unit = _selectedUnit;
    final subCategory = _subCategoryController.text.trim();

    if (category == null || unit == null || subCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final subCatId = await _generateSubCategoryId();

      await _subCatRef.doc(subCatId).set({
        'matCategory': FirestoreService.getCollection('materialCategories').doc(category.id),
        'matUnit': FirestoreService.getCollection('materialUnits').doc(unit.id),
        'matSubCategory': subCategory,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Material Sub Category saved successfully!',
        );
        _cancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancel() {
    setState(() {
      _selectedCategory = null;
      _selectedUnit = null;
      _subCategoryController.clear();
    });
  }

  @override
  void dispose() {
    _subCategoryController.dispose();
    super.dispose();
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
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
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
                  Text(
                    'Material Sub Categories',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Form Card
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
                                      color: const Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.category_rounded,
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
                                          'Add Sub Category',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Link category, unit, and sub-category name',
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

                              // Material Category Dropdown
                              const Text(
                                'Material Category',
                                style: TextStyle(
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
                                child: DropdownButtonFormField<DocumentSnapshot>(
                                  value: _selectedCategory,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Select category',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Icon(
                                        Icons.category_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 20,
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
                                  items: _categories.map((cat) {
                                    final data = cat.data() as Map<String, dynamic>? ?? {};
                                    final displayName = data['matCategory']?.toString() ?? cat.id;
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Material Unit Dropdown
                              const Text(
                                'Material Unit',
                                style: TextStyle(
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
                                child: DropdownButtonFormField<DocumentSnapshot>(
                                  value: _selectedUnit,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Select unit',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Icon(
                                        Icons.straighten_rounded,
                                        color: Color(0xFF10B981),
                                        size: 20,
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
                                  items: _units.map((unit) {
                                    final data = unit.data() as Map<String, dynamic>? ?? {};
                                    final displayName = data['matUnit']?.toString() ?? unit.id;
                                    return DropdownMenuItem(
                                      value: unit,
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedUnit = val),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Material Sub Category Text Field
                              const Text(
                                'Material Sub Category Name',
                                style: TextStyle(
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
                                child: TextField(
                                  controller: _subCategoryController,
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter sub-category name',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Icon(
                                        Icons.label_important_rounded,
                                        color: Color(0xFFF97316),
                                        size: 20,
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

                              const SizedBox(height: 24),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'SAVE SUB CATEGORY',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Existing Sub Categories List
                        const Text(
                          'Existing Sub Categories',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: _subCatRef.snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No existing sub categories found.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final docs = snapshot.data!.docs;
                            docs.sort((a, b) {
                              final valA = (a.data() as Map<String, dynamic>)['matSubCategory']?.toString() ?? '';
                              final valB = (b.data() as Map<String, dynamic>)['matSubCategory']?.toString() ?? '';
                              return valA.toLowerCase().compareTo(valB.toLowerCase());
                            });

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final title = data['matSubCategory']?.toString() ?? 'Unnamed';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: darkCardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: darkCardBg.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.label_important_rounded,
                                          color: Color(0xFF60A5FA),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 22,
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Sub Category'),
                                              content: Text('Are you sure you want to delete "$title"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('CANCEL'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text(
                                                    'DELETE',
                                                    style: TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await doc.reference.delete();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
