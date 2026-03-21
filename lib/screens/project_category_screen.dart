import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ProjectCategoryScreen extends StatefulWidget {
  const ProjectCategoryScreen({super.key});

  @override
  State<ProjectCategoryScreen> createState() => _ProjectCategoryScreenState();
}

class _ProjectCategoryScreenState extends State<ProjectCategoryScreen> {
  String? _selectedCategory;
  final TextEditingController _customizationController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newCategoryController = TextEditingController();
  final FocusNode _categoryFocusNode = FocusNode();

  final Color primaryColor = const Color(0xFF0B3470);

  // Generate next ID like PC001, PC002, ...
  Future<String> _getNextCategoryId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projectCategories')
        .orderBy('projectCategoryId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return 'PC001';
    } else {
      final lastId = snapshot.docs.first['projectCategoryId'] as String;
      final number = int.parse(lastId.replaceAll('PC', '')) + 1;
      return 'PC${number.toString().padLeft(3, '0')}';
    }
  }

  Future<bool> _isDuplicateCategory(String category) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('projectCategories').get();
    final existingCategories = snapshot.docs
        .map((doc) => (doc['projectCategory'] as String).toLowerCase())
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
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add New Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _newCategoryController,
                    focusNode: _categoryFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.05),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close, color: primaryColor),
                        onPressed: () => _newCategoryController.clear(),
                      ),
                    ),
                    cursorColor: primaryColor,
                    onChanged: (value) async {
                      final duplicate =
                          await _isDuplicateCategory(value.trim());
                      setState(() {
                        isDuplicate = duplicate;
                      });
                    },
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(50),
                    ],
                  ),
                  if (isDuplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: primaryColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'This category already exists',
                            style: TextStyle(color: primaryColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: primaryColor),
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isDuplicate
                              ? null
                              : () async {
                                  final newCategory =
                                      _newCategoryController.text.trim();
                                  if (newCategory.isEmpty) return;

                                  final newId = await _getNextCategoryId();
                                  await FirebaseFirestore.instance
                                      .collection('projectCategories')
                                      .doc(newId)
                                      .set({
                                    'projectCategoryId': newId,
                                    'projectCategory': newCategory,
                                  });

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      _selectedCategory = newCategory;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteSelectedCategory() async {
    if (_selectedCategory == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('projectCategories')
        .where('projectCategory', isEqualTo: _selectedCategory)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('projectCategories')
          .doc(docId)
          .delete();

      if (mounted) {
        setState(() {
          _selectedCategory = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Category deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Category not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // --- END DELETE LOGIC ---

  @override
  void dispose() {
    _newCategoryController.dispose();
    _customizationController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              'Project Category Setup',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                
              ),
            ),
            centerTitle: true,
            backgroundColor: primaryColor,
            elevation: 3,
            pinned: true,
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Card(
                    elevation: 5,
                    shadowColor: primaryColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor,
                                  radius: 24,
                                  child: const Icon(Icons.category,
                                      size: 28, ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Project Category',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Select or create a project category',
                                        style: textTheme.bodySmall?.copyWith(
                                          
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Select Category',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('projectCategories')
                                        .orderBy('projectCategoryId')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const LinearProgressIndicator();
                                      }
                                      if (snapshot.hasError) {
                                        return Text('Error: ${snapshot.error}');
                                      }
                                      final categories =
                                          snapshot.data?.docs ?? [];

                                      final uniqueCategories = <String>{};
                                      final dropdownItems =
                                          <DropdownMenuItem<String>>[];
                                      for (var doc in categories) {
                                        final category =
                                            doc['projectCategory'] as String;
                                        if (uniqueCategories.add(category)) {
                                          dropdownItems.add(
                                            DropdownMenuItem<String>(
                                              value: category,
                                              child: Text(
                                                category,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }
                                      }

                                      String? safeSelectedCategory =
                                          (_selectedCategory != null &&
                                                  uniqueCategories.contains(
                                                      _selectedCategory))
                                              ? _selectedCategory
                                              : null;

                                      return DropdownButtonFormField<String>(
                                        value: safeSelectedCategory,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor:
                                              primaryColor.withOpacity(0.05),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          hintText: 'Select project category',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                        icon: Icon(Icons.arrow_drop_down,
                                            ),
                                        items: dropdownItems,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedCategory = newValue;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select a category';
                                          }
                                          return null;
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        menuMaxHeight: 300,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FloatingActionButton.small(
                                  heroTag: 'addCategory',
                                  onPressed: _showAddCategoryDialog,
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  child: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCircularActionButton(
                        icon: Icons.arrow_back,
                        label: 'Back',
                        backgroundColor: Colors.green.shade100,
                        iconColor: Colors.green.shade900,
                        labelColor: Colors.green.shade900,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 40),
                      _buildCircularActionButton(
                        icon: Icons.delete,
                        label: 'Delete',
                        backgroundColor: _selectedCategory != null
                            ? Colors.red.shade100
                            : Colors.grey.shade300,
                        iconColor: _selectedCategory != null
                            ? Colors.red.shade900
                            : Colors.grey.shade600,
                        labelColor: _selectedCategory != null
                            ? Colors.red.shade900
                            : Colors.grey.shade600,
                        onPressed: _selectedCategory != null
                            ? () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Category'),
                                    content: const Text(
                                        'Are you sure you want to delete the selected category?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteSelectedCategory();
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required Color labelColor,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
