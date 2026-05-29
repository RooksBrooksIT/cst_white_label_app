import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../utils/dialog_utils.dart';

class MatlsSubCat extends StatefulWidget {
  const MatlsSubCat({super.key});

  @override
  State<MatlsSubCat> createState() => _MatlsSubCatState();
}

class _MatlsSubCatState extends State<MatlsSubCat> {
  // Constants
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0; // larger radius for modern look
  static const double cardElevation = 4.0; // subtle shadow uplift

  // Firestore references
  final _categoriesRef = FirestoreService.getCollection('materialCategories');
  final _unitsRef = FirestoreService.getCollection('materialUnits');
  final _subCatRef = FirestoreService.getCollection('materialSubCategories');

  // Dropdown data
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

  /// Fetch categories and units for dropdowns
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
        _showErrorSnackbar('Error loading dropdown data: $e');
      }
    }
  }

  /// Generate ID in format MSC00n (e.g., MSC001, MSC002, ...), skipping existing IDs
  Future<String> _generateSubCategoryId() async {
    final query = await _subCatRef.get();

    // Collect all existing serial numbers
    final Set<int> existingSerials = {};
    for (var doc in query.docs) {
      final id = doc.id; // e.g., 'MSC001'
      final match = RegExp(r'^MSC(\d{3})$').firstMatch(id);
      if (match != null) {
        final serial = int.tryParse(match.group(1) ?? '0') ?? 0;
        existingSerials.add(serial);
      }
    }

    // Find the smallest unused serial number starting from 1
    int nextSerial = 1;
    while (existingSerials.contains(nextSerial)) {
      nextSerial++;
    }
    final serialStr = nextSerial.toString().padLeft(3, '0');
    return 'MSC$serialStr';
  }

  /// Save subcategory
  Future<void> _save() async {
    final category = _selectedCategory;
    final unit = _selectedUnit;
    final subCategory = _subCategoryController.text.trim();

    if (category == null || unit == null || subCategory.isEmpty) {
      _showWarningSnackbar('Please fill all fields');
      return;
    }

    setState(() => _loading = true);

    try {
      // Generate custom document ID (MSC00n format)
      final subCatId = await _generateSubCategoryId();

      await _subCatRef.doc(subCatId).set({
        // Store as Firestore reference
        'matCategory': FirestoreService.getCollection(
          'materialCategories',
        ).doc(category.id),
        'matUnit': FirestoreService.getCollection('materialUnits').doc(unit.id),
        'matSubCategory': subCategory,
        'created_at': FieldValue.serverTimestamp(),
      });

      await DialogUtils.showSuccessDialog(
        context,
        message: 'Saved successfully!',
      );
      _cancel();
    } catch (e) {
      _showErrorSnackbar('Error saving: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Show confirmation dialog before saving
  Future<void> _showSaveConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Save'),
        content: const Text('Are you sure you want to save this sub category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _save();
    }
  }

  /// Clear form inputs
  void _cancel() {
    setState(() {
      _selectedCategory = null;
      _selectedUnit = null;
      _subCategoryController.clear();
    });
  }

  // Snackbar helpers
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _subCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return GlassScaffold(
      title: 'Material Sub Category Master',
      onBack: () => Navigator.pop(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Sub Category',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Material Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<DocumentSnapshot>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            hintText: 'Select category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            filled: true,
                            prefixIcon: Icon(
                              Icons.category,
                              color: primaryColor,
                            ),
                          ),
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          items: _categories.map((cat) {
                            final data =
                                cat.data() as Map<String, dynamic>? ?? {};
                            final displayName =
                                data['matCategory']?.toString() ?? cat.id;
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 15),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Material Unit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<DocumentSnapshot>(
                          value: _selectedUnit,
                          decoration: InputDecoration(
                            hintText: 'Select unit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            filled: true,
                            prefixIcon: Icon(
                              Icons.straighten,
                              color: primaryColor,
                            ),
                          ),
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          items: _units.map((unit) {
                            final data =
                                unit.data() as Map<String, dynamic>? ?? {};
                            final displayName =
                                data['matUnit']?.toString() ?? unit.id;
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 15),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedUnit = value),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Material Sub Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subCategoryController,
                          decoration: InputDecoration(
                            hintText: 'Enter sub category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            filled: true,
                            prefixIcon: Icon(
                              Icons.label_important,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                label: 'SAVE',
                                onPressed: _loading
                                    ? null
                                    : _showSaveConfirmationDialog,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GlassButton(
                                label: 'CANCEL',
                                onPressed: _loading
                                    ? null
                                    : () {
                                        _cancel();
                                        Navigator.of(context).pop();
                                      },
                                isSecondary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildExistingValuesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildExistingValuesSection() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Existing Sub Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
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
              return GlassCard(
                child: Center(
                  child: Text(
                    'No existing sub categories found.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            // Sort alphabetically by the sub-category name
            docs.sort((a, b) {
              final valA =
                  (a.data() as Map<String, dynamic>)['matSubCategory']
                      ?.toString() ??
                  '';
              final valB =
                  (b.data() as Map<String, dynamic>)['matSubCategory']
                      ?.toString() ??
                  '';
              return valA.toLowerCase().compareTo(valB.toLowerCase());
            });

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final subCategory = data['matSubCategory']?.toString() ?? 'N/A';
                final catRef = data['matCategory'] as DocumentReference?;
                final unitRef = data['matUnit'] as DocumentReference?;
                final id = docs[index].id;

                return GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      subCategory,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            _ReferenceText(
                              reference: catRef,
                              fieldName: 'matCategory',
                              fallback: 'Unknown Category',
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.straighten,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            _ReferenceText(
                              reference: unitRef,
                              fieldName: 'matUnit',
                              fallback: 'Unknown Unit',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $id',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Text(
                        (index + 1).toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// A small helper widget to resolve a Firestore reference to a name string
class _ReferenceText extends StatelessWidget {
  final DocumentReference? reference;
  final String fieldName;
  final String fallback;

  const _ReferenceText({
    required this.reference,
    required this.fieldName,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (reference == null) {
      return Text(
        fallback,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: reference!.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(
            fallback,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final value = data?[fieldName]?.toString() ?? fallback;

        return Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
