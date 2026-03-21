import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatlsSubCat extends StatefulWidget {
  const MatlsSubCat({super.key});

  @override
  State<MatlsSubCat> createState() => _MatlsSubCatState();
}

class _MatlsSubCatState extends State<MatlsSubCat> {
  // Constants
  static const Color primaryColor = Color(0xFF0b3470); // Updated primary color
  static const Color cardColor = Color(0xFFF5F5F5);
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0; // larger radius for modern look
  static const double cardElevation = 4.0; // subtle shadow uplift

  // Firestore references
  final _categoriesRef =
      FirebaseFirestore.instance.collection('materialCategories');
  final _unitsRef = FirebaseFirestore.instance.collection('materialUnits');
  final _subCatRef =
      FirebaseFirestore.instance.collection('materialSubCategories');

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
        'matCategory':
            FirebaseFirestore.instance.doc('materialCategories/${category.id}'),
        'matUnit': FirebaseFirestore.instance.doc('materialUnits/${unit.id}'),
        'matSubCategory': subCategory,
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('Saved successfully!');
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
              backgroundColor: primaryColor,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        title: const Text(
          'Material Sub Category Master',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5,),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(defaultPadding),
              child: Card(
                elevation: cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
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
                          
                          prefixIcon: const Icon(Icons.category, color: primaryColor),
                        ),
                        isExpanded: true,
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
                          
                          prefixIcon: const Icon(Icons.straighten, color: primaryColor),
                        ),
                        isExpanded: true,
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
                        onChanged: (value) => setState(() => _selectedUnit = value),
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
                          
                          prefixIcon: const Icon(Icons.label_important, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save, size: 20),
                              label: const Text(
                                'SAVE',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _loading ? null : _showSaveConfirmationDialog,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel, size: 20),
                              label: const Text(
                                'CANCEL',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _loading
                                  ? null
                                  : () {
                                      _cancel();
                                      Navigator.of(context).pop();
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
