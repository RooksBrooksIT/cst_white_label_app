import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ConfigMaterialsScreen extends StatefulWidget {
  const ConfigMaterialsScreen({super.key});

  @override
  State<ConfigMaterialsScreen> createState() => _ConfigMaterialsScreenState();
}

class _ConfigMaterialsScreenState extends State<ConfigMaterialsScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSavingCategory = false;
  bool _isSavingUnit = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await FirestoreService.initialize();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _unitController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _getNextAvailableId(QuerySnapshot snapshot, String prefix) {
    final ids = snapshot.docs
        .map((doc) => doc.id)
        .where((id) => id.startsWith(prefix))
        .map((id) => int.tryParse(id.substring(prefix.length)) ?? 0)
        .toList();

    if (ids.isEmpty) return 1;
    ids.sort();
    return ids.last + 1;
  }

  Future<void> _addCategory() async {
    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter category name')),
      );
      return;
    }

    setState(() => _isSavingCategory = true);

    try {
      final catCol = FirestoreService.getCollection('materialCategories');
      final snapshot = await catCol.get();

      final existingCats = snapshot.docs
          .map((doc) => (doc.data())['matCategory']?.toString().toLowerCase())
          .toSet();

      if (existingCats.contains(category.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category already exists')),
          );
        }
        return;
      }

      final nextId = _getNextAvailableId(snapshot, 'MC');
      final docId = 'MC${nextId.toString().padLeft(3, '0')}';

      await catCol.doc(docId).set({'matCategory': category});
      _categoryController.clear();

      if (mounted) {
        DialogUtils.showSuccessDialog(
          context,
          message: 'Category "$category" added successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingCategory = false);
    }
  }

  Future<void> _addUnit() async {
    final unit = _unitController.text.trim();
    if (unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter unit name')),
      );
      return;
    }

    setState(() => _isSavingUnit = true);

    try {
      final unitCol = FirestoreService.getCollection('materialUnits');
      final snapshot = await unitCol.get();

      final existingUnits = snapshot.docs
          .map((doc) => (doc.data())['matUnit']?.toString().toLowerCase())
          .toSet();

      if (existingUnits.contains(unit.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unit already exists')),
          );
        }
        return;
      }

      final nextId = _getNextAvailableId(snapshot, 'MU');
      final docId = 'MU${nextId.toString().padLeft(3, '0')}';

      await unitCol.doc(docId).set({'matUnit': unit});
      _unitController.clear();

      if (mounted) {
        DialogUtils.showSuccessDialog(
          context,
          message: 'Unit "$unit" added successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add unit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingUnit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Master Config',
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 700),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Bar Filter
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search categories or measurement units...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: Colors.grey.shade600,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECTION 1: MATERIAL CATEGORIES
                  _buildSectionCard(
                    context: context,
                    title: '1. Material Categories',
                    subtitle: 'Master Categories (e.g. Cement, Steel, Sand, Bricks)',
                    icon: Icons.inventory_2_rounded,
                    accentColor: const Color(0xFF10B981),
                    controller: _categoryController,
                    hintText: 'Enter category name',
                    isLoading: _isSavingCategory,
                    onAdd: _addCategory,
                    collectionName: 'materialCategories',
                    fieldKey: 'matCategory',
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: MATERIAL UNITS
                  _buildSectionCard(
                    context: context,
                    title: '2. Material Units',
                    subtitle: 'Measurement Units (e.g. Bags, Tons, SqFt, Kg, Meters)',
                    icon: Icons.straighten_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    controller: _unitController,
                    hintText: 'Enter unit name',
                    isLoading: _isSavingUnit,
                    onAdd: _addUnit,
                    collectionName: 'materialUnits',
                    fieldKey: 'matUnit',
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required TextEditingController controller,
    required String hintText,
    required bool isLoading,
    required VoidCallback onAdd,
    required String collectionName,
    required String fieldKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // Section Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
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
          const SizedBox(height: 18),

          // Add Entry Form Field Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onAdd(),
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'ADD',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Realtime Master Stream List
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getCollection(collectionName).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final val = (data[fieldKey]?.toString() ?? doc.id).toLowerCase();
                return _searchQuery.isEmpty || val.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No matching entries found.'
                        : 'No entries configured yet. Add your first above.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Master List (${filteredDocs.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap X to Delete',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data[fieldKey]?.toString() ?? doc.id;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: accentColor,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0A183D),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Entry'),
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
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
