import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/screens/manager/tools_inventory_details.dart';

class ToolMasterPage extends StatefulWidget {
  const ToolMasterPage({super.key});

  @override
  State<ToolMasterPage> createState() => _ToolMasterPageState();
}

class _ToolMasterPageState extends State<ToolMasterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 0: Add Tool Controllers
  final TextEditingController _toolNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
  String _toolOwner = 'Org';
  String _toolCode = '';
  bool _isSaving = false;

  // Tab 1: Directory State
  String _searchQuery = '';
  String _selectedOwnerFilter = 'All'; // 'All', 'Org', 'Rental'
  final TextEditingController _searchController = TextEditingController();

  // Tab 2: Update Tab State
  String? _selectedToolDocId;
  Map<String, dynamic>? _selectedToolData;
  final TextEditingController _updateCountController = TextEditingController();
  bool _isUpdatingCount = false;

  // Shared Tools List
  List<QueryDocumentSnapshot> _toolsList = [];
  bool _isLoadingTools = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _toolNameController.addListener(_updateToolCode);
    _toolCountController.text = '1';
    _fetchTools();
  }

  void _updateToolCode() {
    final ownerCode = _toolOwner.isNotEmpty
        ? _toolOwner[0].toUpperCase() + _toolOwner.substring(1).toLowerCase()
        : '';
    final name = _toolNameController.text.trim().replaceAll(" ", "_");
    setState(() {
      _toolCode = name.isNotEmpty ? '${name}_($ownerCode)' : '';
    });
  }

  void _onOwnerChanged(String newValue) {
    setState(() {
      _toolOwner = newValue;
    });
    _updateToolCode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _toolNameController.dispose();
    _descriptionController.dispose();
    _toolCountController.dispose();
    _updateCountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTools() async {
    setState(() {
      _isLoadingTools = true;
    });
    try {
      final snapshot = await FirestoreService.getCollection('tools').get();
      if (!mounted) return;
      final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
      docs.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>?;
        final dataB = b.data() as Map<String, dynamic>?;
        final nameA = (dataA?['toolName'] ?? a.id).toString().toLowerCase();
        final nameB = (dataB?['toolName'] ?? b.id).toString().toLowerCase();
        return nameA.compareTo(nameB);
      });
      setState(() {
        _toolsList = docs;
        if (_selectedToolDocId != null) {
          final match = _toolsList.where((doc) => doc.id == _selectedToolDocId);
          if (match.isNotEmpty) {
            _selectedToolData = match.first.data() as Map<String, dynamic>?;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppTheme.showErrorToast(context, 'Failed to load tools: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTools = false;
        });
      }
    }
  }

  void _onToolSelected(String? docId) {
    if (docId == null) {
      setState(() {
        _selectedToolDocId = null;
        _selectedToolData = null;
        _updateCountController.clear();
      });
      return;
    }

    QueryDocumentSnapshot? foundDoc;
    try {
      foundDoc = _toolsList.firstWhere((doc) => doc.id == docId);
    } catch (_) {
      foundDoc = null;
    }
    setState(() {
      _selectedToolDocId = docId;
      _selectedToolData = foundDoc?.data() as Map<String, dynamic>?;
      if (_selectedToolData != null) {
        _updateCountController.text =
            _selectedToolData!['toolCount']?.toString() ?? '0';
      }
    });
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> _saveTool() async {
    final toolName = _toolNameController.text.trim();
    final description = _descriptionController.text.trim();
    final toolCountStr = _toolCountController.text.trim();
    final toolOwner = _toolOwner;
    final toolCode = _toolCode;

    if (toolName.isEmpty ||
        description.isEmpty ||
        toolCountStr.isEmpty ||
        toolCode.isEmpty) {
      AppTheme.showErrorToast(context, 'Please fill all required fields.');
      return;
    }

    final toolCount = int.tryParse(toolCountStr);
    if (toolCount == null || toolCount < 0) {
      AppTheme.showErrorToast(context, 'Tool count must be a positive number.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final codeDuplicateQuery = await FirestoreService.getCollection(
        'tools',
      ).where('toolCode', isEqualTo: toolCode).get();

      if (!mounted) return;
      if (codeDuplicateQuery.docs.isNotEmpty) {
        AppTheme.showErrorToast(context, 'Tool code "$toolCode" already exists.');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final toolsSnapshot = await FirestoreService.getCollection(
        'tools',
      ).orderBy('toolId', descending: true).limit(1).get();

      String newToolId = 'TC001';
      if (toolsSnapshot.docs.isNotEmpty) {
        final lastId = toolsSnapshot.docs.first['toolId'] as String? ?? 'TC000';
        final lastNum = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        newToolId = 'TC${(lastNum + 1).toString().padLeft(3, '0')}';
      }

      final docId = '${newToolId}_$toolCode';

      await FirestoreService.getCollection('tools').doc(docId).set({
        'toolId': newToolId,
        'toolName': toolName,
        'toolOwner': toolOwner,
        'toolCode': toolCode,
        'toolCount': toolCount,
        'availableCount': toolCount,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirestoreService.getCollection(
        'toolsAtCompany',
      ).doc(toolCode).set({
        'toolCode': toolCode,
        'availableCount': toolCount,
        'toolName': toolName,
        'toolOwner': toolOwner,
      }, SetOptions(merge: true));

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tool "$toolName" registered successfully!',
        );
      }

      _toolNameController.clear();
      _descriptionController.clear();
      _toolCountController.text = '1';
      setState(() {
        _toolCode = '';
      });

      await _fetchTools();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      AppTheme.showErrorToast(context, 'Failed to save tool: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateToolCount() async {
    if (_selectedToolDocId == null) {
      AppTheme.showErrorToast(context, 'Please select a tool first.');
      return;
    }

    final newCountStr = _updateCountController.text.trim();
    final newCount = int.tryParse(newCountStr);
    if (newCount == null || newCount < 0) {
      AppTheme.showErrorToast(context, 'Count must be a valid positive number.');
      return;
    }

    setState(() {
      _isUpdatingCount = true;
    });

    try {
      await FirestoreService.getCollection('tools')
          .doc(_selectedToolDocId)
          .update({
        'toolCount': newCount,
        'availableCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final toolCode = _selectedToolData?['toolCode']?.toString();
      if (toolCode != null && toolCode.isNotEmpty) {
        await FirestoreService.getCollection('toolsAtCompany')
            .doc(toolCode)
            .set({
          'toolCode': toolCode,
          'availableCount': newCount,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        AppTheme.showSuccessToast(context, 'Stock count updated to $newCount!');
      }

      await _fetchTools();
    } catch (e) {
      if (!mounted) return;
      AppTheme.showErrorToast(context, 'Failed to update stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCount = false;
        });
      }
    }
  }

  Future<void> _showEditToolDialog(Map<String, dynamic> toolData, String docId) async {
    final nameCtrl = TextEditingController(text: toolData['toolName'] ?? '');
    final descCtrl = TextEditingController(text: toolData['description'] ?? '');
    final countCtrl = TextEditingController(
      text: toolData['toolCount']?.toString() ?? '0',
    );
    String editOwner = toolData['toolOwner'] ?? 'Org';
    bool isSavingEdit = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerContext, setDialogState) {
          final darkAccent = AppTheme.getDarkAccent(primaryColor);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit Tool Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: darkAccent,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tool ID & Code',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${toolData['toolId'] ?? ''} • ${toolData['toolCode'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tool Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter tool name',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Total Quantity / Units',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ownership Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Org Owned')),
                          selected: editOwner == 'Org',
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            if (selected) setDialogState(() => editOwner = 'Org');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Rental')),
                          selected: editOwner == 'Rental',
                          selectedColor: Colors.amber.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            if (selected) setDialogState(() => editOwner = 'Rental');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter tool description',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: isSavingEdit
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        final newCount = int.tryParse(countCtrl.text.trim());
                        final newDesc = descCtrl.text.trim();

                        if (newName.isEmpty || newCount == null || newCount < 0) {
                          if (dialogCtx.mounted) {
                            AppTheme.showErrorToast(
                              dialogCtx,
                              'Please enter valid tool name and count',
                            );
                          }
                          return;
                        }

                        setDialogState(() => isSavingEdit = true);
                        try {
                          await FirestoreService.getCollection('tools')
                              .doc(docId)
                              .update({
                            'toolName': newName,
                            'toolCount': newCount,
                            'availableCount': newCount,
                            'toolOwner': editOwner,
                            'description': newDesc,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          final toolCode = toolData['toolCode']?.toString();
                          if (toolCode != null && toolCode.isNotEmpty) {
                            await FirestoreService.getCollection('toolsAtCompany')
                                .doc(toolCode)
                                .set({
                              'toolName': newName,
                              'availableCount': newCount,
                              'toolOwner': editOwner,
                            }, SetOptions(merge: true));
                          }

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            AppTheme.showSuccessToast(
                              context,
                              'Tool details updated successfully!',
                            );
                            _fetchTools();
                          }
                        } catch (e) {
                          setDialogState(() => isSavingEdit = false);
                          if (dialogCtx.mounted) {
                            AppTheme.showErrorToast(dialogCtx, 'Update error: $e');
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSavingEdit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteTool(String docId, String toolName, String toolCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Tool',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$toolName" ($toolCode)?\nThis will remove it from the master catalog.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.getCollection('tools').doc(docId).delete();
        if (toolCode.isNotEmpty) {
          await FirestoreService.getCollection('toolsAtCompany').doc(toolCode).delete();
        }
        if (mounted) {
          AppTheme.showSuccessToast(context, 'Tool "$toolName" deleted successfully.');
          _fetchTools();
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showErrorToast(context, 'Failed to delete tool: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tools Master Configuration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
        actions: [
          IconButton(
            tooltip: 'Refresh Tools',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _fetchTools,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Modern Pill Tab Switcher ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      _buildTabItem(0, 'ADD TOOL', Icons.add_circle_outline_rounded),
                      _buildTabItem(1, 'DIRECTORY', Icons.inventory_2_outlined),
                      _buildTabItem(2, 'STOCK UPDATE', Icons.published_with_changes_rounded),
                    ],
                  );
                },
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAddToolTab(isMobile, darkAccent),
                  _buildToolsDirectoryTab(isMobile, darkAccent),
                  _buildStockUpdateTab(isMobile, darkAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: ADD NEW TOOL
  // ---------------------------------------------------------------------------

  Widget _buildAddToolTab(bool isMobile, Color darkAccent) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 640),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.build_circle_rounded, color: primaryColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Register New Tool',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkAccent,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Add organization tools or rental equipment to master records',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                // Tool Name
                _buildFieldLabel('Tool Name *', Icons.handyman_rounded),
                const SizedBox(height: 6),
                _buildInputContainer(
                  child: TextField(
                    controller: _toolNameController,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Concrete Mixer, Power Drill, Shovel',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tool Ownership (Segmented Selector)
                _buildFieldLabel('Tool Ownership *', Icons.account_balance_rounded),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onOwnerChanged('Org'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _toolOwner == 'Org' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _toolOwner == 'Org'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 16,
                                  color: _toolOwner == 'Org' ? primaryColor : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Company Owned (Org)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _toolOwner == 'Org' ? darkAccent : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onOwnerChanged('Rental'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _toolOwner == 'Rental' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _toolOwner == 'Rental'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 16,
                                  color: _toolOwner == 'Rental' ? Colors.amber.shade800 : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Rental Tool',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _toolOwner == 'Rental' ? darkAccent : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Generated Tool Code
                _buildFieldLabel('System Tool Code (Auto-Generated)', Icons.qr_code_2_rounded),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _toolCode.isEmpty ? 'e.g. Concrete_Mixer_(Org)' : _toolCode,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: _toolCode.isEmpty ? const Color(0xFF94A3B8) : darkAccent,
                          ),
                        ),
                      ),
                      if (_toolCode.isNotEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _toolCode));
                            AppTheme.showSuccessToast(context, 'Tool code copied!');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Initial Quantity / Stepper
                _buildFieldLabel('Initial Tool Count / Quantity *', Icons.numbers_rounded),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputContainer(
                        child: TextField(
                          controller: _toolCountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter quantity',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCountStepperButton(Icons.remove, () {
                      final current = int.tryParse(_toolCountController.text.trim()) ?? 1;
                      if (current > 1) {
                        _toolCountController.text = (current - 1).toString();
                      }
                    }),
                    const SizedBox(width: 4),
                    _buildCountStepperButton(Icons.add, () {
                      final current = int.tryParse(_toolCountController.text.trim()) ?? 0;
                      _toolCountController.text = (current + 1).toString();
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                _buildFieldLabel('Description & Specification *', Icons.description_rounded),
                const SizedBox(height: 6),
                _buildInputContainer(
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Add capacity, model, warranty notes or maintenance guidelines...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveTool,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: primaryColor.withValues(alpha: 0.35),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'REGISTER TOOL',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          _toolNameController.clear();
                          _descriptionController.clear();
                          _toolCountController.text = '1';
                          setState(() {
                            _toolCode = '';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'RESET',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildCountStepperButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF334155)),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: TOOLS DIRECTORY & INVENTORY LIST
  // ---------------------------------------------------------------------------

  Widget _buildToolsDirectoryTab(bool isMobile, Color darkAccent) {
    if (_isLoadingTools) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredTools = _toolsList.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['toolName'] ?? '').toString().toLowerCase();
      final code = (data['toolCode'] ?? '').toString().toLowerCase();
      final id = (data['toolId'] ?? '').toString().toLowerCase();
      final desc = (data['description'] ?? '').toString().toLowerCase();
      final owner = (data['toolOwner'] ?? '').toString().toLowerCase();

      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          code.contains(query) ||
          id.contains(query) ||
          desc.contains(query);

      final matchesOwner = _selectedOwnerFilter == 'All' ||
          owner == _selectedOwnerFilter.toLowerCase();

      return matchesQuery && matchesOwner;
    }).toList();

    int totalCount = 0;
    int orgCount = 0;
    int rentalCount = 0;

    for (var doc in _toolsList) {
      final data = doc.data() as Map<String, dynamic>;
      final count = int.tryParse(data['toolCount']?.toString() ?? '0') ?? 0;
      totalCount += count;
      final owner = (data['toolOwner'] ?? '').toString();
      if (owner.toLowerCase() == 'rental') {
        rentalCount += count;
      } else {
        orgCount += count;
      }
    }

    return RefreshIndicator(
      onRefresh: _fetchTools,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Metrics Row ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Types',
                    value: '${_toolsList.length}',
                    icon: Icons.category_rounded,
                    accentColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Units',
                    value: '$totalCount',
                    icon: Icons.inventory_2_rounded,
                    accentColor: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Org Owned',
                    value: '$orgCount',
                    icon: Icons.business_rounded,
                    accentColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Rental',
                    value: '$rentalCount',
                    icon: Icons.schedule_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Search & Filter Controls ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search by tool name, code, ID...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildOwnerFilterChip('All'),
                      const SizedBox(width: 6),
                      _buildOwnerFilterChip('Org'),
                      const SizedBox(width: 6),
                      _buildOwnerFilterChip('Rental'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tools List / Cards ──────────────────────────────────────────
            if (filteredTools.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isEmpty ? 'No Tools Found' : 'No Matching Tools',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Register tools in the "Add Tool" tab to manage your master inventory'
                          : 'Try searching with a different term or clearing the filter',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (_searchQuery.isEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(0),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add First Tool'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTools.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = filteredTools[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final toolId = data['toolId']?.toString() ?? 'TC---';
                  final toolName = data['toolName']?.toString() ?? 'Unnamed Tool';
                  final toolCode = data['toolCode']?.toString() ?? '';
                  final toolOwner = data['toolOwner']?.toString() ?? 'Org';
                  final toolCount = int.tryParse(data['toolCount']?.toString() ?? '0') ?? 0;
                  final description = data['description']?.toString() ?? '';
                  final isRental = toolOwner.toLowerCase() == 'rental';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isRental
                                      ? Colors.amber.shade50
                                      : primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRental
                                        ? Colors.amber.shade300
                                        : primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  isRental ? Icons.timelapse_rounded : Icons.build_rounded,
                                  color: isRental ? Colors.amber.shade800 : primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: darkAccent.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            toolId,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: darkAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isRental
                                                ? Colors.amber.withValues(alpha: 0.15)
                                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isRental ? 'RENTAL' : 'ORG OWNED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isRental
                                                  ? Colors.amber.shade900
                                                  : const Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      toolName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: darkAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      toolCode,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$toolCount',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: darkAccent,
                                      ),
                                    ),
                                    const Text(
                                      'UNITS',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),

                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ToolsInventoryDetailsPage(toolCode: toolCode),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.location_on_outlined, size: 16),
                                label: const Text(
                                  'Distribution',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  _onToolSelected(doc.id);
                                  _tabController.animateTo(2);
                                },
                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                label: const Text(
                                  'Quick Count',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0284C7),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit Tool Details',
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                                onPressed: () => _showEditToolDialog(data, doc.id),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                tooltip: 'Delete Tool',
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () => _confirmDeleteTool(doc.id, toolName, toolCode),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerFilterChip(String label) {
    final isSelected = _selectedOwnerFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedOwnerFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: UPDATE STOCK TAB
  // ---------------------------------------------------------------------------

  Widget _buildStockUpdateTab(bool isMobile, Color darkAccent) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 640),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.05),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.published_with_changes_rounded,
                        color: Color(0xFF0EA5E9),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adjust Tool Stock Count',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkAccent,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Quickly modify master counts and synchronize availability',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                _buildFieldLabel('Select Tool to Update *', Icons.build_circle_rounded),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _isLoadingTools
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedToolDocId,
                            isExpanded: true,
                            hint: const Text(
                              'Choose a tool...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: _toolsList.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['toolName'] ?? 'Tool';
                              final code = data['toolCode'] ?? doc.id;
                              final id = data['toolId'] ?? '';
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  '$id - $name ($code)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _onToolSelected,
                          ),
                        ),
                ),
                const SizedBox(height: 18),

                if (_selectedToolData != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedToolData!['toolName']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: darkAccent,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CURRENT: ${_selectedToolData!['toolCount'] ?? '0'} UNITS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${_selectedToolData!['toolCode'] ?? ''} • Owner: ${_selectedToolData!['toolOwner'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  _buildFieldLabel('New Tool Quantity *', Icons.numbers_rounded),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputContainer(
                          child: TextField(
                            controller: _updateCountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter new total count',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCountStepperButton(Icons.remove, () {
                        final current = int.tryParse(_updateCountController.text.trim()) ?? 0;
                        if (current > 0) {
                          _updateCountController.text = (current - 1).toString();
                        }
                      }),
                      const SizedBox(width: 4),
                      _buildCountStepperButton(Icons.add, () {
                        final current = int.tryParse(_updateCountController.text.trim()) ?? 0;
                        _updateCountController.text = (current + 1).toString();
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Quick Adjust:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      _buildQuickDeltaChip('+1', 1),
                      _buildQuickDeltaChip('+5', 5),
                      _buildQuickDeltaChip('+10', 10),
                      _buildQuickDeltaChip('-1', -1),
                      _buildQuickDeltaChip('-5', -5),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isUpdatingCount ? null : _updateToolCount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            child: _isUpdatingCount
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'CONFIRM UPDATE',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedToolDocId = null;
                              _selectedToolData = null;
                              _updateCountController.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'CLEAR',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 36, color: primaryColor),
                        const SizedBox(height: 10),
                        const Text(
                          'Select a tool from the dropdown above to adjust its quantity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDeltaChip(String label, int delta) {
    return GestureDetector(
      onTap: () {
        final current = int.tryParse(_updateCountController.text.trim()) ?? 0;
        final next = (current + delta).clamp(0, 999999);
        setState(() {
          _updateCountController.text = next.toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: delta > 0
              ? const Color(0xFF10B981).withValues(alpha: 0.12)
              : Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: delta > 0 ? const Color(0xFF047857) : Colors.red.shade800,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}
