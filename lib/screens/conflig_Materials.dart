import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';

class MatlsScreen extends StatefulWidget {
  const MatlsScreen({super.key});

  @override
  State<MatlsScreen> createState() => _MatlsScreenState();
}

class _MatlsScreenState extends State<MatlsScreen> {
  // Constants
  static const double defaultPadding = 16.0;
  static const double formFieldSpacing = 16.0;
  static const double cardElevation = 2.0;
  static const double borderRadius = 12.0;

  // Controllers
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _unitEditController = TextEditingController();

  // Firestore references
  final CollectionReference materialCategories = FirebaseFirestore.instance
      .collection('materialCategories');
  final CollectionReference materialUnits = FirebaseFirestore.instance
      .collection('materialUnits');

  // State variables
  final List<Map<String, String>> _entries = [];
  List<String> _unitList = [];
  String? _selectedUnitDropdown;

  // Mode management
  String _mode = 'category'; // Default to category

  // Delete mode variables
  List<Map<String, dynamic>> _categories = [];
  List<String> _categoryNames = [];
  List<String> _unitNames = [];
  String? _dropdownCategory;
  String? _dropdownUnit;

  // Loading states
  bool _isLoadingUnits = false;
  bool _isLoadingCategories = false;
  bool _isSaving = false;
  final bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([_fetchUnits(), _fetchCategories()]);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _unitEditController.dispose();
    super.dispose();
  }

  // Firestore duplicate category check
  Future<bool> _matCategoryExists(String category) async {
    final query = await materialCategories
        .where('matCategory', isEqualTo: category)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // Fetch units from Firestore
  Future<void> _fetchUnits() async {
    if (_isLoadingUnits) return;
    setState(() => _isLoadingUnits = true);

    try {
      final QuerySnapshot snapshot = await materialUnits.get();
      final units = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['matUnit']?.toString() ?? '';
          })
          .where((unit) => unit.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        _unitList = units;
        _unitNames = List<String>.from(_unitList);
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load units: ${e.toString()}');
    } finally {
      setState(() => _isLoadingUnits = false);
    }
  }

  // Fetch categories from Firestore
  Future<void> _fetchCategories() async {
    if (_isLoadingCategories) return;
    setState(() => _isLoadingCategories = true);

    try {
      final QuerySnapshot snapshot = await materialCategories.get();
      final categories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'matCategory': data['matCategory']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _categories = categories;
        _categoryNames = categories
            .map((cat) => cat['matCategory'] as String)
            .toList();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load categories: ${e.toString()}');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  // Mode switching
  void _switchMode(String mode) async {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      _resetFormFields();
    });

    await Future.wait([_fetchCategories(), _fetchUnits()]);
  }

  void _resetFormFields() {
    _entries.clear();
    _categoryController.clear();
    _unitEditController.clear();
    _selectedUnitDropdown = null;
    _dropdownCategory = null;
    _dropdownUnit = null;
  }

  // Form field handlers
  void _onUnitDropdownChanged(String? value) {
    setState(() {
      _selectedUnitDropdown = value;
      _unitEditController.text = value ?? '';
    });
  }

  void _onUnitEditChanged(String value) {
    setState(() {
      _selectedUnitDropdown = value;
    });
  }

  // Add entry with duplicate check (both local and Firestore)
  Future<void> _addEntry() async {
    if (_mode == 'category') {
      final String category = _categoryController.text.trim();
      if (category.isEmpty) {
        _showWarningSnackbar('Please enter category');
        return;
      }
      if (_entries.any((e) => e['category'] == category)) {
        _showWarningSnackbar('Category already added');
        return;
      }
      if (await _matCategoryExists(category)) {
        _showErrorSnackbar('Category already exists in master list');
        return;
      }
      setState(() {
        _entries.add({'category': category, 'unit': ''});
        _categoryController.clear();
      });
    } else if (_mode == 'unit') {
      final String unit = _unitEditController.text.trim();
      if (unit.isEmpty) {
        _showWarningSnackbar('Please enter unit');
        return;
      }
      if (_entries.any((e) => e['unit'] == unit)) {
        _showWarningSnackbar('Unit already added');
        return;
      }
      setState(() {
        _entries.add({'category': '', 'unit': unit});
        _unitEditController.clear();
      });
    }
  }

  void _deleteEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  // Save all entries to Firestore with duplicate check and id generation
  Future<void> _saveAll() async {
    if (_entries.isEmpty) {
      _showWarningSnackbar('No entries to save');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final [catSnapshot, unitSnapshot] = await Future.wait([
        materialCategories.get(),
        materialUnits.get(),
      ]);

      final catNext = _getNextAvailableId(catSnapshot, 'MC');
      final unitNext = _getNextAvailableId(unitSnapshot, 'MU');

      final unitValueToId = {
        for (var doc in unitSnapshot.docs)
          (doc.data() as Map<String, dynamic>)['matUnit']: doc.id,
      };
      final catValueToId = {
        for (var doc in catSnapshot.docs)
          (doc.data() as Map<String, dynamic>)['matCategory']: doc.id,
      };

      int catCounter = catNext;
      int unitCounter = unitNext;

      for (final entry in _entries) {
        // Save unit if not exists
        if (entry['unit'] != null && entry['unit']!.isNotEmpty) {
          if (!unitValueToId.containsKey(entry['unit'])) {
            final unitDocId = 'MU${unitCounter.toString().padLeft(3, '0')}';
            await materialUnits.doc(unitDocId).set({'matUnit': entry['unit']});
            unitValueToId[entry['unit']!] = unitDocId;
            unitCounter++;
          }
        }

        // Save category if not exists
        if (entry['category'] != null && entry['category']!.isNotEmpty) {
          if (!catValueToId.containsKey(entry['category'])) {
            final catDocId = 'MC${catCounter.toString().padLeft(3, '0')}';
            await materialCategories.doc(catDocId).set({
              'matCategory': entry['category'],
            });
            catValueToId[entry['category']!] = catDocId;
            catCounter++;
          }
        }
      }

      _showSuccessSnackbar('All entries saved successfully!');
      _resetFormFields();
      await Future.wait([_fetchUnits(), _fetchCategories()]);
    } catch (e) {
      _showErrorSnackbar('Failed to save entries: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int _getNextAvailableId(QuerySnapshot snapshot, String prefix) {
    final numbers = snapshot.docs
        .map((doc) {
          final id = doc.id;
          if (id.startsWith(prefix)) {
            final numberPart = id.substring(prefix.length);
            return int.tryParse(numberPart);
          }
          return null;
        })
        .whereType<int>()
        .toList();

    return numbers.isNotEmpty ? numbers.reduce((a, b) => a > b ? a : b) + 1 : 1;
  }

  // Snackbar helpers
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.primary),
    );
  }

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  // Confirmation dialog before save
  Future<void> _handleSaveAll() async {
    if (_entries.isEmpty) {
      _showWarningSnackbar('No entries to save');
      return;
    }

    final confirmed = await _showConfirmationDialog(
      title: 'Confirm Save',
      content: 'Are you sure you want to save all ${_entries.length} entries?',
    );

    if (confirmed) {
      await _saveAll();
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Mode switch buttons UI
  Widget _buildModeSwitchButtons() {
    return Card(
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding / 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModeButton(
              label: 'Category',
              mode: 'category',
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: defaultPadding),
            _buildModeButton(
              label: 'Unit',
              mode: 'unit',
              activeColor: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required String mode,
    required Color activeColor,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _mode == mode ? activeColor : Colors.grey[300],
        foregroundColor: _mode == mode ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () => _switchMode(mode),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  // Form action buttons UI
  Widget _buildFormActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: defaultPadding,
      runSpacing: defaultPadding / 2,
      children: [
        ElevatedButton.icon(
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 20),
          label: Text(_isSaving ? 'Saving...' : 'Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: _isSaving ? null : _handleSaveAll,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.clear, size: 20),
          label: const Text('Clear'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () {
            if (_mode == 'category') {
              setState(() {
                _categoryController.clear();
              });
            } else {
              setState(() {
                _unitEditController.clear();
              });
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel, size: 20),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildCategoryContent() {
    return SingleChildScrollView(
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
              Text(
                'Material Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: formFieldSpacing),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: 'Material Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: formFieldSpacing),
              if (_entries.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entries:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        if (entry['category'] != null &&
                            entry['category']!.isNotEmpty) {
                          return ListTile(
                            title: Text(entry['category']!),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteEntry(index),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              _buildFormActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitContent() {
    return SingleChildScrollView(
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
              Text(
                'Material Unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: formFieldSpacing),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unitEditController,
                      decoration: InputDecoration(
                        labelText: 'Material Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: formFieldSpacing),
              if (_entries.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entries:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        if (entry['unit'] != null &&
                            entry['unit']!.isNotEmpty) {
                          return ListTile(
                            title: Text(entry['unit']!),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteEntry(index),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              _buildFormActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Material Master',
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSwitchButtons(),
            const SizedBox(height: defaultPadding),
            Expanded(
              child: _mode == 'category'
                  ? _buildCategoryContent()
                  : _buildUnitContent(),
            ),
          ],
        ),
      ),
    );
  }
}
