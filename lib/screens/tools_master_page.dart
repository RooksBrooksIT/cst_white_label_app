import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/dialog_utils.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: 'Tool Master',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'ADD TOOL'),
          Tab(text: 'UPDATE COUNT'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewTab(theme, isSmallScreen),
          _buildUpdateTab(theme, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildNewTab(ThemeData theme, bool isSmallScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Add New Tool",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildFormField(
                    label: "Tool Name",
                    controller: _toolNameController,
                    hint: "Enter Tool Name",
                    theme: theme,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    label: "Tool Owner",
                    child: _buildDropdown(theme),
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    label: "Tool Code",
                    child: _buildReadOnlyField(_toolCode, theme),
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    label: "Tool Count",
                    controller: _toolCountController,
                    hint: "Enter Tool Count",
                    keyboardType: TextInputType.number,
                    theme: theme,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    label: "Description",
                    controller: _descriptionController,
                    hint: "Enter Description",
                    maxLines: 4,
                    theme: theme,
                  ),
                  SizedBox(height: 24),
                  _buildActionButtons(theme, isSmallScreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateTab(ThemeData theme, bool isSmallScreen) {
    // Initialize the controller with the selected tool's count
    if (_selectedToolData != null) {
      _updateCountController ??= TextEditingController();
      if (_updateCountController!.text !=
          _selectedToolData!['toolCount']?.toString()) {
        _updateCountController!.text =
            _selectedToolData!['toolCount']?.toString() ?? '';
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Update Tool Count",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildFormField(
                    label: "Select Tool",
                    child: _isLoadingTools
                        ? Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            value: _selectedToolDocId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            hint: Text("Select a tool"),
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
                  ),
                  if (_selectedToolData != null) ...[
                    SizedBox(height: 24),
                    _buildFormField(
                      label: "Current Count",
                      child: _buildReadOnlyField(
                        _selectedToolData!['toolCount']?.toString() ?? '0',
                        theme,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFormField(
                      label: "New Count",
                      controller: _updateCountController,
                      hint: "Enter new count",
                      keyboardType: TextInputType.number,
                      theme: theme,
                    ),
                    SizedBox(height: 24),
                    _buildUpdateActionButtons(theme, isSmallScreen),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    TextEditingController? controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? child,
    ThemeData? theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme?.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        child ??
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
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
                  borderSide: BorderSide(
                    color: theme?.primaryColor ?? Colors.blue,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildReadOnlyField(String value, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Text(value, style: theme.textTheme.bodyMedium),
    );
  }

  Widget _buildDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _toolOwner,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: [
        'Org',
        'Rental',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: _onOwnerChanged,
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isSmallScreen) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded, size: 20),
            label: Text(_isSaving ? 'ADDING...' : 'ADD TOOL'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSaving ? null : _saveToolWithCompany,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('CLEAR FORM'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              _toolNameController.clear();
              _descriptionController.clear();
              _toolCountController.clear();
              setState(() {
                _toolCode = '';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateActionButtons(ThemeData theme, bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Icons.update, size: 20),
            label: Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _updateToolCount,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 16),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.clear, size: 20),
            label: Text('Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),

              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _selectedToolDocId = null;
                _selectedToolData = null;
              });
            },
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
      // 1. Update the 'tools' collection
      await FirestoreService.getCollection('tools')
          .doc(_selectedToolDocId)
          .update({'toolCount': newCount, 'availableCount': newCount});

      // 2. Update the 'toolsAtCompany' collection to reflect the new count backend-wide
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

      // 3. Immediately reflect changes in the UI state
      setState(() {
        if (_selectedToolData != null) {
          // Creating a new map ensures the widget recognizes the change
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

      // 4. Fetch the latest tools in the background to sync the dropdown
      await _fetchTools();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tool count: ${e.toString()}')),
      );
    }
  }

  TextEditingController? _updateCountController;

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
      ).showSnackBar(SnackBar(content: Text('Please fill all fields.')));
      return;
    }

    final toolCount = int.tryParse(toolCountStr);
    if (toolCount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tool count must be a number.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Check for existing tool with same Name or Code
      // final duplicateQuery = await FirebaseFirestore.instance
      //     .collection('tools')
      //     .where('toolName', isEqualTo: toolName)
      //     .get();

      // if (duplicateQuery.docs.isNotEmpty) {
      //   ScaffoldMessenger.of(
      //     context,
      //   ).showSnackBar(SnackBar(content: Text('Tool name already exists.')));
      //   setState(() {
      //     _isSaving = false;
      //   });
      //   return;
      // }

      final codeDuplicateQuery = await FirestoreService.getCollection(
        'tools',
      ).where('toolCode', isEqualTo: toolCode).get();

      if (!mounted) return;
      if (codeDuplicateQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tool code already exists.'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Get the latest toolId
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

      // Save to tools collection
      await FirestoreService.getCollection('tools').doc(docId).set({
        'toolId': newToolId,
        'toolName': toolName,
        'toolOwner': toolOwner,
        'toolCode': toolCode,
        'toolCount': toolCount,
        'description': description,
      });

      // Save to toolsAtCompany collection
      await FirestoreService.getCollection(
        'toolsAtCompany',
      ).doc(toolCode).set({'toolCode': toolCode, 'availableCount': toolCount});

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Tool saved successfully!',
        );
      }

      // Clear form
      _toolNameController.clear();
      _descriptionController.clear();
      _toolCountController.clear();
      setState(() {
        _toolCode = '';
      });

      // Refresh tools list for update tab
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
