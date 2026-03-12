import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

extension StringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}

class ProjectSubCategoryScreen extends StatefulWidget {
  const ProjectSubCategoryScreen({super.key});

  @override
  State<ProjectSubCategoryScreen> createState() =>
      _ProjectSubCategoryScreenState();
}

class _ProjectSubCategoryScreenState extends State<ProjectSubCategoryScreen> {
  String? _selectedSubCategory;
  final TextEditingController _customizationController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newSubCategoryController =
      TextEditingController();
  bool _isSubCategorySelected = false;

  final Color primaryColor = const Color(0xFF0B3470); // ✅ new professional color

  Future<String> _getNextSubCategoryId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectSubCategories')
          .orderBy('subCategoryId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'PSC001';
      } else {
        final lastId = snapshot.docs.first['subCategoryId'] as String;
        final numericPart = int.parse(lastId.replaceAll(RegExp(r'[^0-9]'), ''));
        final nextId = numericPart + 1;
        return 'PSC${nextId.toString().padLeft(3, '0')}';
      }
    } catch (e) {
      throw Exception('Failed to generate next sub-category ID: $e');
    }
  }

  Future<void> _showAddSubCategoryDialog() async {
    _newSubCategoryController.clear();
    bool isDuplicate = false;
    bool saved = false;
    String savedName = "";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add New Sub Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newSubCategoryController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Sub Category Name',
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
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                      ),
                      onChanged: (value) async {
                        final duplicate =
                            await _isDuplicateSubCategory(value.trim());
                        setState(() {
                          isDuplicate = duplicate;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDuplicate ? Colors.grey : primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isDuplicate
                              ? null
                              : () async {
                                  final newSubCategory =
                                      _newSubCategoryController.text.trim();
                                  if (newSubCategory.isEmpty) return;

                                  final newId = await _getNextSubCategoryId();
                                  await FirebaseFirestore.instance
                                      .collection('projectSubCategories')
                                      .doc(newId)
                                      .set({
                                    'subCategoryId': newId,
                                    'projectSubCategory': newSubCategory,
                                  });

                                  saved = true;
                                  savedName = newSubCategory;

                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedSubCategory = newSubCategory;
                                    _isSubCategorySelected = true;
                                  });
                                },
                        ),
                      ],
                    ),
                    if (isDuplicate)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text(
                          'This sub-category already exists.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved && savedName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sub-category "$savedName" added successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
  }

  Future<bool> _isDuplicateSubCategory(String subCategoryName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectSubCategories')
          .where('projectSubCategory', isEqualTo: subCategoryName)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteSelectedSubCategory() async {
    if (_selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a sub-category to delete.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub Category'),
        content: Text(
            'Are you sure you want to delete the sub-category "${_selectedSubCategory!}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectSubCategories')
          .where('projectSubCategory', isEqualTo: _selectedSubCategory)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sub-category not found in database.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _selectedSubCategory = null;
        _isSubCategorySelected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sub-category deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete sub-category: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Sub Category Setup',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Subcategory detail box
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.assignment, size: 32, color: primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sub Category Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Configure your sub-category settings',
                                  style: TextStyle(
                                      color: primaryColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Sub Category',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('projectSubCategories')
                                  .orderBy('subCategoryId')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }

                                final subCategories = snapshot.data!.docs
                                    .map((doc) =>
                                        doc['projectSubCategory'] as String)
                                    .toSet()
                                    .toList();

                                final validSelected =
                                    subCategories.contains(_selectedSubCategory)
                                        ? _selectedSubCategory
                                        : null;

                                return DropdownButtonFormField<String>(
                                  value: validSelected,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.blue.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintText: 'Select sub-category',
                                  ),
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: primaryColor),
                                  items: subCategories.map((subCategory) {
                                    return DropdownMenuItem<String>(
                                      value: subCategory,
                                      child: Text(subCategory),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedSubCategory = newValue;
                                      _isSubCategorySelected = newValue != null;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a sub-category';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: "Add New Sub Category",
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: _showAddSubCategoryDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 24),
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
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircularActionButton(
                  icon: Icons.arrow_back,
                  label: 'Back',
                  backgroundColor: const Color.fromARGB(255, 181, 220, 255),
                  iconColor: primaryColor,
                  labelColor: primaryColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 40),
                _buildCircularActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  backgroundColor: _isSubCategorySelected
                      ? Colors.red.shade100
                      : Colors.grey.shade300,
                  iconColor: _isSubCategorySelected
                      ? Colors.red.shade900
                      : Colors.grey.shade600,
                  labelColor: Colors.red.shade900,
                  onPressed:
                      _isSubCategorySelected ? _deleteSelectedSubCategory : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable Button
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
                color: Colors.black.withOpacity(0.1),
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
