import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/dialog_utils.dart';

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
    final snapshot = await FirestoreService.getCollection('projectCategories')
        .orderBy('projectCategoryId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return 'PC001';
    final lastId = snapshot.docs.first.data().containsKey('projectCategoryId')
        ? snapshot.docs.first['projectCategoryId']?.toString() ?? ''
        : '';
    if (lastId.isEmpty || !lastId.startsWith('PC')) return 'PC001';
    final number = int.parse(lastId.replaceAll('PC', '')) + 1;
    return 'PC${number.toString().padLeft(3, '0')}';
  }

  Future<bool> _isDuplicateCategory(String category) async {
    final snapshot = await FirestoreService.getCollection('projectCategories').get();
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
                  Text('Add New Category', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  GlassTextField(
                    controller: _newCategoryController,
                    label: 'Category Name',
                    icon: Icons.category_outlined,
                    onChanged: (value) async {
                      final duplicate = await _isDuplicateCategory(value.trim());
                      setDialogState(() => isDuplicate = duplicate);
                    },
                  ),
                  if (isDuplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('This category already exists', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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
                            final name = _newCategoryController.text.trim();
                            if (name.isEmpty) return;
                            final id = await _getNextCategoryId();
                            await FirestoreService.getCollection('projectCategories').doc(id).set({
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

  Future<void> _deleteSelectedCategory() async {
    if (_selectedCategory == null) return;
    final snapshot = await FirestoreService.getCollection('projectCategories').where('projectCategory', isEqualTo: _selectedCategory).get();
    if (snapshot.docs.isNotEmpty) {
      await FirestoreService.getCollection('projectCategories').doc(snapshot.docs.first.id).delete();
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
    return GlassScaffold(
      title: 'Project Categories',
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
                        CircleAvatar(backgroundColor: theme.primaryColor, child: const Icon(Icons.category, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Categorization', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Manage project types and categories', style: theme.textTheme.bodySmall),
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
                            stream: FirestoreService.getCollection('projectCategories').orderBy('projectCategoryId').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null) return const LinearProgressIndicator();
                              final items = snapshot.data!.docs
                                  .map((d) => d['projectCategory']?.toString() ?? '')
                                  .where((val) => val.isNotEmpty)
                                  .toList();
                              return DropdownButtonFormField<String>(
                                value: (_selectedCategory != null && items.contains(_selectedCategory)) ? _selectedCategory : null,
                                decoration: InputDecoration(
                                  labelText: 'Select Category',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.cardColor,
                                ),
                                items: items.toSet().map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                                onChanged: (v) => setState(() => _selectedCategory = v),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add)),
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
                    onPressed: _selectedCategory == null ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Category'),
                          content: Text('Are you sure you want to delete "$_selectedCategory"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('DELETE', style: TextStyle(color: theme.colorScheme.error))),
                          ],
                        ),
                      );
                      if (confirm == true) await _deleteSelectedCategory();
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
