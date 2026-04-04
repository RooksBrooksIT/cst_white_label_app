import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
import 'package:flutter/material.dart';

class ProjectSubCategoryScreen extends StatefulWidget {
  const ProjectSubCategoryScreen({super.key});

  @override
  State<ProjectSubCategoryScreen> createState() => _ProjectSubCategoryScreenState();
}

class _ProjectSubCategoryScreenState extends State<ProjectSubCategoryScreen> {
  String? _selectedSubCategory;
  final _formKey = GlobalKey<FormState>();
  final _newSubCategoryController = TextEditingController();

  Future<String> _getNextSubCategoryId() async {
    try {
      final snapshot = await FirestoreService.getCollection('projectSubCategories')
          .orderBy('subCategoryId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 'PSC001';
      final lastId = snapshot.docs.first['subCategoryId']?.toString() ?? '';
      if (lastId.isEmpty) return 'PSC001';
      final numericPart = int.parse(lastId.replaceAll(RegExp(r'[^0-9]'), ''));
      return 'PSC${(numericPart + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      return 'PSC${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';
    }
  }

  Future<bool> _isDuplicateSubCategory(String name) async {
    final snapshot = await FirestoreService.getCollection('projectSubCategories')
        .where('projectSubCategory', isEqualTo: name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _showAddSubCategoryDialog() async {
    _newSubCategoryController.clear();
    bool isDuplicate = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Add New Sub Category', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  GlassTextField(
                    controller: _newSubCategoryController,
                    label: 'Sub Category Name',
                    icon: Icons.subdirectory_arrow_right_rounded,
                    onChanged: (value) async {
                      final duplicate = await _isDuplicateSubCategory(value.trim());
                      setDialogState(() => isDuplicate = duplicate);
                    },
                  ),
                  if (isDuplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('This sub-category already exists', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: GlassButton(label: 'CANCEL', onPressed: () => Navigator.pop(context), isSecondary: true)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassButton(
                          label: 'SAVE',
                          onPressed: isDuplicate ? null : () async {
                            final name = _newSubCategoryController.text.trim();
                            if (name.isEmpty) return;
                            final id = await _getNextSubCategoryId();
                            await FirestoreService.getCollection('projectSubCategories').doc(id).set({
                              'subCategoryId': id,
                              'projectSubCategory': name,
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              setState(() => _selectedSubCategory = name);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSelectedSubCategory() async {
    if (_selectedSubCategory == null) return;
    final snapshot = await FirestoreService.getCollection('projectSubCategories').where('projectSubCategory', isEqualTo: _selectedSubCategory).get();
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
      setState(() => _selectedSubCategory = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-category deleted')));
    }
  }

  @override
  void dispose() {
    _newSubCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      title: 'Sub Categories',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: theme.primaryColor, child: const Icon(Icons.assignment, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Project Configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Define sub-categories for detailed tracking', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirestoreService.getCollection('projectSubCategories').orderBy('subCategoryId').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null) return const LinearProgressIndicator();
                              final items = snapshot.data!.docs
                                  .map((d) => d['projectSubCategory']?.toString() ?? '')
                                  .where((val) => val.isNotEmpty)
                                  .toList();
                              return DropdownButtonFormField<String>(
                                value: (_selectedSubCategory != null && items.contains(_selectedSubCategory)) ? _selectedSubCategory : null,
                                decoration: InputDecoration(
                                  labelText: 'Select Sub Category',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.cardColor,
                                ),
                                items: items.toSet().map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                                onChanged: (v) => setState(() => _selectedSubCategory = v),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(onPressed: _showAddSubCategoryDialog, icon: const Icon(Icons.add)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: GlassButton(label: 'BACK', onPressed: () => Navigator.pop(context), isSecondary: true)),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    label: 'DELETE',
                    onPressed: _selectedSubCategory == null ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Sub Category'),
                          content: Text('Are you sure you want to delete "$_selectedSubCategory"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('DELETE', style: TextStyle(color: theme.colorScheme.error))),
                          ],
                        ),
                      );
                      if (confirm == true) await _deleteSelectedSubCategory();
                    },
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
}
