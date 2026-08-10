import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ProjectCategoryScreen extends StatefulWidget {
  const ProjectCategoryScreen({super.key});

  @override
  State<ProjectCategoryScreen> createState() => _ProjectCategoryScreenState();
}

class _ProjectCategoryScreenState extends State<ProjectCategoryScreen> {
  String? _selectedCategory;
  final _formKey = GlobalKey<FormState>();
  final _newCategoryController = TextEditingController();

  Future<String> _getNextCategoryId() async {
    final snapshot = await FirestoreService.getCollection(
      'projectCategories',
    ).orderBy('projectCategoryId', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return 'PC001';
    final lastId = snapshot.docs.first.data().containsKey('projectCategoryId')
        ? snapshot.docs.first['projectCategoryId']?.toString() ?? ''
        : '';
    if (lastId.isEmpty || !lastId.startsWith('PC')) return 'PC001';
    final number = int.parse(lastId.replaceAll('PC', '')) + 1;
    return 'PC${number.toString().padLeft(3, '0')}';
  }

  Future<bool> _isDuplicateCategory(String category) async {
    final snapshot = await FirestoreService.getCollection(
      'projectCategories',
    ).get();
    final existingCategories = snapshot.docs
        .map((doc) => doc['projectCategory']?.toString().toLowerCase() ?? '')
        .toList();
    return existingCategories.contains(category.toLowerCase());
  }

  Future<void> _showAddCategoryDialog() async {
    _newCategoryController.clear();
    bool isDuplicate = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

            return Container(
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    left: 24,
                    right: 24,
                    top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Add New Project Category',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Solid White Input Box
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
                          controller: _newCategoryController,
                          style: const TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (value) async {
                            final duplicate = await _isDuplicateCategory(value.trim());
                            setDialogState(() => isDuplicate = duplicate);
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Category Name',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Icon(
                                Icons.category_rounded,
                                color: AppTheme.getDarkAccent(theme.primaryColor),
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

                      if (isDuplicate)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'This category already exists',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: theme.primaryColor, width: 1.8),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Center(
                                  child: Text(
                                    'CANCEL',
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isDuplicate
                                    ? null
                                    : () async {
                                        final name = _newCategoryController.text.trim();
                                        if (name.isEmpty) return;
                                        final id = await _getNextCategoryId();
                                        await FirestoreService.getCollection(
                                          'projectCategories',
                                        ).doc(id).set({
                                          'projectCategoryId': id,
                                          'projectCategory': name,
                                        });
                                        if (mounted) {
                                          Navigator.pop(context);
                                          setState(() => _selectedCategory = name);
                                          await DialogUtils.showSuccessDialog(
                                            context,
                                            message: 'Category added successfully!',
                                          );
                                        }
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSelectedCategory() async {
    if (_selectedCategory == null) return;
    final snapshot = await FirestoreService.getCollection(
      'projectCategories',
    ).where('projectCategory', isEqualTo: _selectedCategory).get();
    if (snapshot.docs.isNotEmpty) {
      await FirestoreService.getCollection(
        'projectCategories',
      ).doc(snapshot.docs.first.id).delete();
      if (mounted) {
        setState(() => _selectedCategory = null);
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Category deleted successfully!',
        );
      }
    }
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
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
            // Top Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    'Project Categories',
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

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main Section Card
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
                                        color: const Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF97316).withValues(alpha: 0.4),
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
                                            'Categorization',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Manage project types and categories',
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
                                const SizedBox(height: 24),
                                const Text(
                                  'Select Category',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Category Dropdown & Add Button Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
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
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirestoreService.getCollection(
                                            'projectCategories',
                                          ).orderBy('projectCategoryId').snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData || snapshot.data == null) {
                                              return const Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: LinearProgressIndicator(),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((d) => d['projectCategory']?.toString() ?? '')
                                                .where((val) => val.isNotEmpty)
                                                .toList();

                                            return DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              dropdownColor: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              value: (_selectedCategory != null && items.contains(_selectedCategory))
                                                  ? _selectedCategory
                                                  : null,
                                              style: const TextStyle(
                                                color: Color(0xFF0A183D),
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Choose a category',
                                                hintStyle: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                prefixIcon: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                                  child: Icon(
                                                    Icons.search_rounded,
                                                    color: AppTheme.getDarkAccent(theme.primaryColor),
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
                                              items: items
                                                  .toSet()
                                                  .map(
                                                    (item) => DropdownMenuItem(
                                                      value: item,
                                                      child: Text(
                                                        item,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) => setState(() => _selectedCategory = v),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.primaryColor.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add_rounded, color: Color(0xFF0A183D), size: 26),
                                        onPressed: _showAddCategoryDialog,
                                        tooltip: 'Add Category',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Delete Action Button
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _selectedCategory == null
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Category'),
                                          content: Text(
                                            'Are you sure you want to delete "$_selectedCategory"?',
                                          ),
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
                                        await _deleteSelectedCategory();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'DELETE SELECTED CATEGORY',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
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
