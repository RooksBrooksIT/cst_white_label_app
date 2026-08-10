import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class ToolMasterPage extends StatefulWidget {
  const ToolMasterPage({super.key});

  @override
  _ToolMasterPageState createState() => _ToolMasterPageState();
}

class _ToolMasterPageState extends State<ToolMasterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _toolNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
  TextEditingController? _updateCountController;

  String _toolOwner = 'Org';
  String _toolCode = '';
  bool _isSaving = false;

  // For Update Tab
  String? _selectedToolDocId;
  Map<String, dynamic>? _selectedToolData;
  List<QueryDocumentSnapshot> _toolsList = [];
  bool _isLoadingTools = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _toolNameController.addListener(_updateToolCode);
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

  void _onOwnerChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _toolOwner = newValue;
      });
      _updateToolCode();
    }
  }

  @override
  void dispose() {
    _toolNameController.dispose();
    _descriptionController.dispose();
    _toolCountController.dispose();
    _updateCountController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTools() async {
    setState(() {
      _isLoadingTools = true;
    });
    try {
      final snapshot = await FirestoreService.getCollection('tools').get();
      if (!mounted) return;
      setState(() {
        _toolsList = snapshot.docs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tools: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTools = false;
        });
      }
    }
  }

  void _onToolSelected(String? docId) {
    if (docId == null) return;

    QueryDocumentSnapshot? foundDoc;
    try {
      foundDoc = _toolsList.firstWhere((doc) => doc.id == docId);
    } catch (e) {
      foundDoc = null;
    }
    setState(() {
      _selectedToolDocId = docId;
      _selectedToolData = foundDoc?.data() as Map<String, dynamic>?;
      if (_selectedToolData != null) {
        _updateCountController ??= TextEditingController();
        _updateCountController!.text =
            _selectedToolData!['toolCount']?.toString() ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final Color darkCardBg = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
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
                  Text(
                    'Tool Master',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Dark Pill Tab Switcher ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
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
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 16,
                                  color: _tabController.index == 0
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ADD TOOL',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController.index == 0
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController.index == 1
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: _tabController.index == 1
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'UPDATE COUNT',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController.index == 1
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Tab View Body ───────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNewTab(darkCardBg, primaryColor),
                      _buildUpdateTab(darkCardBg, primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ADD TOOL TAB ──────────────────────────────────────────────────────────
  Widget _buildNewTab(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
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
            const Text(
              'Add New Tool',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),

            _buildTextField(
              label: 'Tool Name',
              controller: _toolNameController,
              hint: 'Enter Tool Name',
              icon: Icons.build_rounded,
            ),
            const SizedBox(height: 14),

            _buildFormField(
              label: 'Tool Owner',
              child: _buildDropdown(),
            ),
            const SizedBox(height: 14),

            _buildFormField(
              label: 'Tool Code',
              child: _buildReadOnlyField(_toolCode),
            ),
            const SizedBox(height: 14),

            _buildTextField(
              label: 'Tool Count',
              controller: _toolCountController,
              hint: 'Enter Tool Count',
              keyboardType: TextInputType.number,
              icon: Icons.inventory_rounded,
            ),
            const SizedBox(height: 14),

            _buildTextField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Enter Description',
              maxLines: 3,
              icon: Icons.description_rounded,
            ),
            const SizedBox(height: 22),

            _buildActionButtons(primaryColor),
          ],
        ),
      ),
    );
  }

  // ── UPDATE COUNT TAB ──────────────────────────────────────────────────────
  Widget _buildUpdateTab(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
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
            const Text(
              'Update Tool Count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),

            _buildFormField(
              label: 'Select Tool',
              child: _isLoadingTools
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildToolDropdown(),
            ),

            if (_selectedToolData != null) ...[
              const SizedBox(height: 14),
              _buildFormField(
                label: 'Current Count',
                child: _buildReadOnlyField(
                  _selectedToolData!['toolCount']?.toString() ?? '0',
                ),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'New Count',
                controller: _updateCountController,
                hint: 'Enter new count',
                keyboardType: TextInputType.number,
                icon: Icons.edit_rounded,
              ),
              const SizedBox(height: 22),
              _buildUpdateActionButtons(primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────

  Widget _buildFormField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController? controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
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
      ],
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Container(
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
      child: DropdownButtonFormField<String>(
        value: _toolOwner,
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.account_tree_rounded,
              color: brandIconColor,
              size: 22,
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
        items: ['Org', 'Rental']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: _onOwnerChanged,
      ),
    );
  }

  Widget _buildToolDropdown() {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Container(
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
      child: DropdownButtonFormField<String>(
        value: _selectedToolDocId,
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Select a tool',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.build_rounded,
              color: brandIconColor,
              size: 22,
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
        items: _toolsList
            .map(
              (doc) => DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  doc['toolCode'] ?? doc.id,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: _onToolSelected,
      ),
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveToolWithCompany,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0A183D)),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_rounded,
                          size: 20,
                          color: Color(0xFF0A183D),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ADD TOOL',
                          style: TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              _toolNameController.clear();
              _descriptionController.clear();
              _toolCountController.clear();
              setState(() {
                _toolCode = '';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'CLEAR FORM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateActionButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _updateToolCount,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 20,
                    color: Color(0xFF0A183D),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'UPDATE COUNT',
                    style: TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedToolDocId = null;
                _selectedToolData = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.close_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'CLEAR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateToolCount() async {
    if (_selectedToolDocId == null || _updateCountController == null) return;

    final newCountStr = _updateCountController!.text.trim();
    final newCount = int.tryParse(newCountStr);
    if (newCount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Count must be a number.')));
      return;
    }

    try {
      await FirestoreService.getCollection('tools')
          .doc(_selectedToolDocId)
          .update({'toolCount': newCount, 'availableCount': newCount});

      final toolCode = _selectedToolData?['toolCode']?.toString();
      if (toolCode != null && toolCode.isNotEmpty) {
        await FirestoreService.getCollection(
          'toolsAtCompany',
        ).doc(toolCode).set({
          'toolCode': toolCode,
          'availableCount': newCount,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      setState(() {
        if (_selectedToolData != null) {
          _selectedToolData = Map<String, dynamic>.from(_selectedToolData!);
          _selectedToolData!['toolCount'] = newCount;
          _selectedToolData!['availableCount'] = newCount;
        }
      });

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tool count updated successfully!',
        );
      }

      await _fetchTools();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tool count: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveToolWithCompany() async {
    final toolName = _toolNameController.text.trim();
    final description = _descriptionController.text.trim();
    final toolCountStr = _toolCountController.text.trim();
    final toolOwner = _toolOwner;
    final toolCode = _toolCode;

    if (toolName.isEmpty ||
        description.isEmpty ||
        toolCountStr.isEmpty ||
        toolCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
      return;
    }

    final toolCount = int.tryParse(toolCountStr);
    if (toolCount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tool count must be a number.')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tool code already exists.'),
            backgroundColor: Colors.red,
          ),
        );

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
        final lastId = toolsSnapshot.docs.first['toolId'] as String;
        final lastNum = int.tryParse(lastId.replaceAll('TC', '')) ?? 0;
        newToolId = 'TC${(lastNum + 1).toString().padLeft(3, '0')}';
      }

      final docId = '${newToolId}_$toolCode';

      await FirestoreService.getCollection('tools').doc(docId).set({
        'toolId': newToolId,
        'toolName': toolName,
        'toolOwner': toolOwner,
        'toolCode': toolCode,
        'toolCount': toolCount,
        'description': description,
      });

      await FirestoreService.getCollection(
        'toolsAtCompany',
      ).doc(toolCode).set({'toolCode': toolCode, 'availableCount': toolCount});

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tool saved successfully!',
        );
      }

      _toolNameController.clear();
      _descriptionController.clear();
      _toolCountController.clear();
      setState(() {
        _toolCode = '';
      });

      _fetchTools();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save tool: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
