import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';

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
      final snapshot = await FirebaseFirestore.instance
          .collection('tools')
          .get();
      setState(() {
        _toolsList = snapshot.docs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tools: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoadingTools = false;
      });
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF0b3470),
        title: const Text(
          "Tool Master",
          style: TextStyle( fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 4,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Add Tool'),
            Tab(icon: Icon(Icons.edit_outlined), text: 'Update Tool'),
          ],
        ),
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
                        color: Color(0xFF0b3470),
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
                        color: Color(0xFF0b3470),
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
                                  color: Color(0xFF0b3470),
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
          style: theme?.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0b3470),
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
                  borderSide: BorderSide(color: Color(0xFF0b3470)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0b3470), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
        border: Border.all(color: Color(0xFF0b3470)),
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
          borderSide: BorderSide(color: Color(0xFF0b3470)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF0b3470), width: 2),
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
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: _isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      
                    ),
                  )
                : Icon(Icons.save, size: 20),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0b3470),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isSaving ? null : _saveToolWithCompany,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 16),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.clear, size: 20),
            label: Text('Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF0b3470),
              side: BorderSide(color: Color(0xFF0b3470)),
              
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              backgroundColor: Color(0xFF0b3470),
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
            label: Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF0b3470),
              side: BorderSide(color: Color(0xFF0b3470)),
              
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
      ).showSnackBar(SnackBar(content: Text('Count must be a number.')));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('tools')
          .doc(_selectedToolDocId)
          .update({'toolCount': newCount, 'availableCount': newCount});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tool count updated successfully!')),
      );

      _fetchTools();
      _onToolSelected(_selectedToolDocId);
    } catch (e) {
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

      final codeDuplicateQuery = await FirebaseFirestore.instance
          .collection('tools')
          .where('toolCode', isEqualTo: toolCode)
          .get();

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
      final toolsSnapshot = await FirebaseFirestore.instance
          .collection('tools')
          .orderBy('toolId', descending: true)
          .limit(1)
          .get();

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
      await FirebaseFirestore.instance
          .collection('toolsAtCompany')
          .doc(toolCode)
          .set({'toolCode': toolCode, 'availableCount': toolCount});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tool saved successfully!')));

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save tool: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}
