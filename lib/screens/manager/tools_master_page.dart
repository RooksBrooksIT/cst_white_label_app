import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ToolMasterPage extends StatefulWidget {
  const ToolMasterPage({super.key});

  @override
  State<ToolMasterPage> createState() => _ToolMasterPageState();
}

class _ToolMasterPageState extends State<ToolMasterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // New Tab State
  final TextEditingController _toolNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
  String _toolOwner = 'Org';
  String _toolCode = '';
  bool _isSaving = false;

  // Update Tab State
  String _searchQuery = '';
  String _selectedOwnerFilter = 'All'; // 'All', 'Org', 'Rental'
  final TextEditingController _searchController = TextEditingController();

  // Shared Tools List
  List<QueryDocumentSnapshot> _toolsList = [];
  bool _isLoadingTools = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        _isLoadingTools = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppTheme.showErrorToast(context, 'Failed to load tools: ${e.toString()}');
      setState(() {
        _isLoadingTools = false;
      });
    }
  }

  Future<void> _saveTool() async {
    final toolName = _toolNameController.text.trim();
    final description = _descriptionController.text.trim();
    final toolCountStr = _toolCountController.text.trim();
    final toolOwner = _toolOwner;
    final toolCode = _toolCode;

    if (toolName.isEmpty || toolCountStr.isEmpty || toolCode.isEmpty) {
      AppTheme.showErrorToast(context, 'Please fill all required fields.');
      return;
    }

    final toolCount = int.tryParse(toolCountStr);
    if (toolCount == null || toolCount <= 0) {
      AppTheme.showErrorToast(context, 'Tool count must be greater than 0.');
      return;
    }

    FocusScope.of(context).unfocus();

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
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tool "$toolName" registered successfully with $toolCount units!',
        );
      }

      _toolNameController.clear();
      _descriptionController.clear();
      _toolCountController.text = '1';
      setState(() {
        _toolCode = '';
      });

      await _fetchTools();
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

  Future<void> _addStockToTool(DocumentSnapshot doc, int additionalQty) async {
    final data = doc.data() as Map<String, dynamic>;
    final currentTotal = int.tryParse(data['toolCount']?.toString() ?? '0') ?? 0;
    final currentAvail = int.tryParse(data['availableCount']?.toString() ?? '0') ?? 0;
    final newTotal = currentTotal + additionalQty;
    final newAvail = currentAvail + additionalQty;
    final toolCode = data['toolCode']?.toString() ?? '';
    final toolName = data['toolName']?.toString() ?? 'Tool';

    setState(() {
      _isLoadingTools = true;
    });

    try {
      await FirestoreService.getCollection('tools').doc(doc.id).update({
        'toolCount': newTotal,
        'availableCount': newAvail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (toolCode.isNotEmpty) {
        await FirestoreService.getCollection('toolsAtCompany').doc(toolCode).set({
          'toolCode': toolCode,
          'toolName': toolName,
          'toolOwner': data['toolOwner'] ?? 'Org',
          'availableCount': newAvail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $additionalQty units to $toolName! Total stock is now $newTotal units.',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
      await _fetchTools();
    } catch (e) {
      if (!mounted) return;
      AppTheme.showErrorToast(context, 'Failed to update stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTools = false;
        });
      }
    }
  }

  void _showAddStockModal(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final toolName = data['toolName']?.toString() ?? 'Unnamed Tool';
    final toolCode = data['toolCode']?.toString() ?? '';
    final currentStock = int.tryParse(data['toolCount']?.toString() ?? '0') ?? 0;
    final addQtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int additionalQty = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final theme = Theme.of(context);
            final primaryColor = theme.primaryColor;
            final previewTotal = currentStock + additionalQty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.add_business_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Tool Stock',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                  Text(
                                    toolCode.isNotEmpty ? '$toolName ($toolCode)' : toolName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Current Stock vs New Stock Preview Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Stock',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentStock units',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Updated Stock',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$previewTotal units',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quantity input
                      TextFormField(
                        controller: addQtyController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter quantity';
                          }
                          final numVal = int.tryParse(val.trim());
                          if (numVal == null || numVal <= 0) {
                            return 'Enter a quantity > 0';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setModalState(() {
                            additionalQty = int.tryParse(val.trim()) ?? 0;
                          });
                        },
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Additional Quantity Received *',
                          hintText: 'e.g. 10',
                          prefixIcon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: primaryColor,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            additionalQty > 0
                                ? 'Add $additionalQty to Stock (Total: $previewTotal)'
                                : 'Add to Stock',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final qty = int.tryParse(addQtyController.text.trim()) ?? 0;
                            if (qty <= 0) return;

                            Navigator.pop(ctx);
                            await _addStockToTool(doc, qty);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tools Availability',
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
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      _buildTabItem(0, 'NEW', Icons.add_rounded),
                      _buildTabItem(1, 'UPDATE', Icons.published_with_changes_rounded),
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
                  _buildNewToolSection(isMobile, darkAccent),
                  _buildUpdateStockSection(isMobile, darkAccent),
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
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF0A183D),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isSelected ? Colors.white : const Color(0xFF0A183D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: ADD NEW TOOL (NEW TAB)
  // ---------------------------------------------------------------------------

  Widget _buildNewToolSection(bool isMobile, Color darkAccent) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
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
                    // Header Banner
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.handyman_rounded, color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Tool',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: darkAccent,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Register a tool with its initial available count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tool Name
                    _buildFieldLabel('Tool Name *', Icons.build_rounded),
                    const SizedBox(height: 8),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tool Ownership (Segmented Selector)
                    _buildFieldLabel('Tool Ownership *', Icons.account_balance_rounded),
                    const SizedBox(height: 8),
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
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'Company (Org)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _toolOwner == 'Org' ? darkAccent : const Color(0xFF64748B),
                                        ),
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
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'Rental Tool',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _toolOwner == 'Rental' ? darkAccent : const Color(0xFF64748B),
                                        ),
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
                    if (_toolCode.isNotEmpty) ...[
                      _buildFieldLabel('System Tool Code (Auto-Generated)', Icons.qr_code_2_rounded),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _toolCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Initial Tool Count
                    _buildFieldLabel('Availability Count *', Icons.numbers_rounded),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      child: TextField(
                        controller: _toolCountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter initial quantity',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildFieldLabel('Description / Specifications (Optional)', Icons.notes_rounded),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Model, brand, power rating, storage location',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTool,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'ADD TOOL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: UPDATE STOCK TAB (SAME TABLE FORMAT AS MATERIAL AVAILABILITY)
  // ---------------------------------------------------------------------------

  Widget _buildUpdateStockSection(bool isMobile, Color darkAccent) {
    final filteredTools = _toolsList.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['toolName'] ?? '').toString().toLowerCase();
      final code = (data['toolCode'] ?? '').toString().toLowerCase();
      final id = (data['toolId'] ?? '').toString().toLowerCase();
      final owner = (data['toolOwner'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          code.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery.toLowerCase());

      final matchesOwner = _selectedOwnerFilter == 'All' ||
          owner == _selectedOwnerFilter.toLowerCase();

      return matchesSearch && matchesOwner;
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search / Filter Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search tool by name, code...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: primaryColor, size: 20),
                          tooltip: 'Refresh',
                          onPressed: _fetchTools,
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
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

              // Tools Stock Table Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Tool Name',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Stock Count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Action',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Table Body
                      if (_isLoadingTools)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredTools.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.handyman_outlined, size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No tools matching "$_searchQuery"'
                                      : 'No tools available in stock.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTools.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final doc = filteredTools[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final toolName = data['toolName']?.toString() ?? 'Unnamed Tool';
                            final toolCode = data['toolCode']?.toString() ?? '';
                            final toolOwner = data['toolOwner']?.toString() ?? 'Org';
                            final toolCount = int.tryParse(data['toolCount']?.toString() ?? '0') ?? 0;
                            final isRental = toolOwner.toLowerCase() == 'rental';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                              child: Row(
                                children: [
                                  // Tool Name & Details
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          toolName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isRental
                                                    ? Colors.amber.withValues(alpha: 0.15)
                                                    : primaryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isRental ? 'RENTAL' : 'ORG',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isRental ? Colors.amber.shade900 : primaryColor,
                                                ),
                                              ),
                                            ),
                                            if (toolCode.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  toolCode,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF94A3B8),
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stock Count
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$toolCount',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Action (+)
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Material(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          onTap: () => _showAddStockModal(context, doc),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            child: const Icon(
                                              Icons.add_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
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
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerFilterChip(String label) {
    final isSelected = _selectedOwnerFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedOwnerFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: child,
    );
  }
}
