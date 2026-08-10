import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ConfigMaterialsScreen extends StatefulWidget {
  const ConfigMaterialsScreen({super.key});

  @override
  State<ConfigMaterialsScreen> createState() => _ConfigMaterialsScreenState();
}

class _ConfigMaterialsScreenState extends State<ConfigMaterialsScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _unitEditController = TextEditingController();

  final List<Map<String, String>> _entries = [];
  String _mode = 'category'; // Default to category
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

  Future<void> _addEntry() async {
    if (_mode == 'category') {
      final String category = _categoryController.text.trim();
      if (category.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter category name')),
        );
        return;
      }
      if (_entries.any((e) => e['category'] == category)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category already added to list')),
        );
        return;
      }
      if (await _matCategoryExists(category)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category already exists in master list')),
          );
        }
        return;
      }
      setState(() {
        _entries.add({'category': category, 'unit': ''});
        _categoryController.clear();
      });
    } else if (_mode == 'unit') {
      final String unit = _unitEditController.text.trim();
      if (unit.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter unit name')),
        );
        return;
      }
      if (_entries.any((e) => e['unit'] == unit)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit already added to list')),
        );
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

  Future<void> _saveAll() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to save')),
      );
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      final catCol = FirestoreService.getCollection('materialCategories');
      final unitCol = FirestoreService.getCollection('materialUnits');

      final results = await Future.wait([
        catCol.get(),
        unitCol.get(),
      ]);

      final catSnapshot = results[0];
      final unitSnapshot = results[1];

      int catCounter = _getNextAvailableId(catSnapshot, 'MC');
      int unitCounter = _getNextAvailableId(unitSnapshot, 'MU');

      final existingUnits = unitSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['matUnit']?.toString())
          .toSet();
      final existingCats = catSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['matCategory']?.toString())
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                    'Material Master Config',
                    style: TextStyle(
                      fontSize: 19,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mode Selector Segmented Buttons
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _switchMode('category'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _mode == 'category' ? darkCardBg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Material Category',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _mode == 'category' ? Colors.white : const Color(0xFF0A183D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _switchMode('unit'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _mode == 'unit' ? darkCardBg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Material Unit',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _mode == 'unit' ? Colors.white : const Color(0xFF0A183D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Input Card
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
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _mode == 'category' ? Icons.inventory_2_rounded : Icons.straighten_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _mode == 'category' ? 'Add Material Category' : 'Add Material Unit',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _mode == 'category'
                                              ? 'Enter master category (e.g. Cement, Steel)'
                                              : 'Enter measurement unit (e.g. Bags, Tons, SqFt)',
                                          style: const TextStyle(
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
                              const SizedBox(height: 22),

                              // Input Field Row
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
                                      child: TextField(
                                        controller: _mode == 'category' ? _categoryController : _unitEditController,
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _mode == 'category' ? 'Enter category name' : 'Enter unit name',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: Icon(
                                              _mode == 'category' ? Icons.inventory_2_rounded : Icons.straighten_rounded,
                                              color: const Color(0xFF10B981),
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
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                                      onPressed: _addEntry,
                                      tooltip: 'Add Entry',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Draft Entries Table Card
                        if (_entries.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: darkCardBg,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: darkCardBg.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Entries (${_entries.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _entries.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final entry = _entries[index];
                                    final text = _mode == 'category' ? entry['category']! : entry['unit']!;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 20),
                                            onPressed: () => _deleteEntry(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveAll,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'SAVE ALL ENTRIES',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Existing Master Lists Section
                        Text(
                          _mode == 'category' ? 'Master Material Categories' : 'Master Material Units',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirestoreService.getCollection(
                            _mode == 'category' ? 'materialCategories' : 'materialUnits',
                          ).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No records found.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final docs = snapshot.data!.docs;
                            final key = _mode == 'category' ? 'matCategory' : 'matUnit';

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final title = data[key]?.toString() ?? doc.id;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: darkCardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: darkCardBg.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _mode == 'category' ? Icons.inventory_2_rounded : Icons.straighten_rounded,
                                          color: const Color(0xFF34D399),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 22,
                                        ),
                                        onPressed: () async {
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
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 100),
                      ],
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
