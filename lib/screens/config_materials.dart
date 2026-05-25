import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/dialog_utils.dart';

class ConfigMaterialsScreen extends StatefulWidget {
  const ConfigMaterialsScreen({super.key});

  @override
  State<ConfigMaterialsScreen> createState() => _ConfigMaterialsScreenState();
}

class _ConfigMaterialsScreenState extends State<ConfigMaterialsScreen> {
  // Constants
  static const double borderRadius = 12.0;

  // Controllers
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _unitEditController = TextEditingController();

  // State variables
  final List<Map<String, String>> _entries = [];
  String _mode = 'category'; // Default to category

  // Loading states
  bool _isSaving = false;

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
    _unitEditController.dispose();
    super.dispose();
  }

  // Firestore duplicate category check
  Future<bool> _matCategoryExists(String category) async {
    try {
      final query = await FirestoreService.getCollection(
        'materialCategories',
      ).where('matCategory', isEqualTo: category).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Mode switching
  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _resetFormFields();
    });
  }

  void _resetFormFields() {
    _entries.clear();
    _categoryController.clear();
    _unitEditController.clear();
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

  // Save all entries to Firestore
  Future<void> _saveAll() async {
    if (_entries.isEmpty) {
      _showWarningSnackbar('No entries to save');
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      final catCol = FirestoreService.getCollection('materialCategories');
      final unitCol = FirestoreService.getCollection('materialUnits');

      final [catSnapshot, unitSnapshot] = await Future.wait([
        catCol.get(),
        unitCol.get(),
      ]);

      int catCounter = _getNextAvailableId(catSnapshot, 'MC');
      int unitCounter = _getNextAvailableId(unitSnapshot, 'MU');

      final existingUnits = unitSnapshot.docs
          .map((doc) => doc.data()['matUnit']?.toString())
          .toSet();
      final existingCats = catSnapshot.docs
          .map((doc) => doc.data()['matCategory']?.toString())
          .toSet();

      final batch = FirebaseFirestore.instance.batch();

      for (final entry in _entries) {
        if (entry['unit'] != null && entry['unit']!.isNotEmpty) {
          if (!existingUnits.contains(entry['unit'])) {
            final unitDocId = 'MU${unitCounter.toString().padLeft(3, '0')}';
            batch.set(unitCol.doc(unitDocId), {'matUnit': entry['unit']});
            unitCounter++;
          }
        }

        if (entry['category'] != null && entry['category']!.isNotEmpty) {
          if (!existingCats.contains(entry['category'])) {
            final catDocId = 'MC${catCounter.toString().padLeft(3, '0')}';
            batch.set(catCol.doc(catDocId), {'matCategory': entry['category']});
            catCounter++;
          }
        }
      }

      await batch.commit();

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'All entries saved successfully!',
        );
        _resetFormFields();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to save entries: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    DialogUtils.showSuccessDialog(context, message: message);
  }

  void _showWarningSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

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

  Widget _buildModeSwitchButtons() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildModeButton(
                label: 'Category',
                mode: 'category',
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModeButton(
                label: 'Unit',
                mode: 'unit',
                activeColor: Theme.of(context).colorScheme.primary,
              ),
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

  Widget _buildFormActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
          label: const Text('Clear Form'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => setState(() => _entries.clear()),
        ),
      ],
    );
  }

  Widget _buildCategoryContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'New Category Name',
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
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_entries.isNotEmpty) _buildEntriesList('category'),
          const SizedBox(height: 16),
          _buildFormActionButtons(),
          const SizedBox(height: 32),
          _buildExistingValuesSection('category'),
        ],
      ),
    );
  }

  Widget _buildUnitContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Material Unit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unitEditController,
                        decoration: InputDecoration(
                          labelText: 'New Unit (e.g., kg, m, bags)',
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_entries.isNotEmpty) _buildEntriesList('unit'),
          const SizedBox(height: 16),
          _buildFormActionButtons(),
          const SizedBox(height: 32),
          _buildExistingValuesSection('unit'),
        ],
      ),
    );
  }

  Widget _buildEntriesList(String type) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New ${type[0].toUpperCase() + type.substring(1)}s to Save:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final value = type == 'category' ? entry['category'] : entry['unit'];
              if (value == null || value.isEmpty) return const SizedBox.shrink();
              return ListTile(
                title: Text(value),
                contentPadding: EdgeInsets.zero,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _deleteEntry(index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExistingValuesSection(String type) {
    final collectionName = type == 'category' ? 'materialCategories' : 'materialUnits';
    final fieldName = type == 'category' ? 'matCategory' : 'matUnit';
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Existing ${type[0].toUpperCase() + type.substring(1)}s',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.getCollection(collectionName).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return GlassCard(
                child: Center(
                  child: Text(
                    'No existing ${type}s found.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            // Sort alphabetically by the field name
            docs.sort((a, b) {
              final valA = (a.data() as Map<String, dynamic>)[fieldName]?.toString() ?? '';
              final valB = (b.data() as Map<String, dynamic>)[fieldName]?.toString() ?? '';
              return valA.toLowerCase().compareTo(valB.toLowerCase());
            });

            return GlassCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final value = data[fieldName]?.toString() ?? 'N/A';
                  final id = docs[index].id;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'ID: $id',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withOpacity(0.1),
                      child: Text(
                        (index + 1).toString(),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Material Master',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSwitchButtons(),
            const SizedBox(height: 16),
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
