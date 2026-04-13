import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

class SiteToCompanyReturn extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SiteToCompanyReturn({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SiteToCompanyReturn> createState() => _SiteToCompanyReturnState();
}

class _SiteToCompanyReturnState extends State<SiteToCompanyReturn> {

  // Form controllers
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedSiteId;
  String? _selectedTool;
  int? _toolCount;
  final List<Map<String, dynamic>> _addedTools = [];

  // Firestore data
  List<String> _siteIds = [];
  List<Map<String, dynamic>> _tools = [];
  int? _selectedToolAvailableCount;

  @override
  void initState() {
    super.initState();
    _fetchSiteIds();
    _fetchTools();
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _projectNameController.dispose();
    _supervisorNameController.dispose();
    _toolCountController.dispose();
    super.dispose();
  }

  Future<void> _fetchSiteIds() async {
    final snapshot = await FirestoreService
        .getCollection('siteSupervisorMap')
        .get();
    final siteSet = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final site = data['site'];
      if (site != null && site is String) {
        siteSet.add(site);
      }
    }
    setState(() {
      _siteIds = siteSet.toList();
    });
  }

  Future<void> _fetchTools() async {
    final snapshot = await FirestoreService.getCollection('tools').get();
    setState(() {
      _tools = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'toolId': data['toolId'] ?? '',
          'toolName': data['toolName'] ?? '',
          'toolCode': data['toolCode'] ?? '',
          'name': data['toolName'] ?? data['toolCode'] ?? '',
          'availableCount': data['availableCount'] ?? 0,
        };
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              primary: cs.primary,
              onPrimary: cs.onPrimary,
              surface: cs.surface,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _fetchAndSetProjectName(String? siteId) async {
    if (siteId == null || siteId.trim().isEmpty) return;

    final snapshot = await FirestoreService
        .getCollection('siteSupervisorMap')
        .where('site', isEqualTo: siteId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _projectNameController.text = data['projectName'] ?? '';
        _supervisorNameController.text = data['supervisor'] ?? '';
      });
    }
  }

  Future<void> _fetchAvailableCountForSelectedTool(String? toolName) async {
    if (toolName == null) {
      setState(() {
        _selectedToolAvailableCount = null;
      });
      return;
    }

    final toolObj = _tools.firstWhere(
      (t) => t['name'] == toolName,
      orElse: () => {'toolCode': null},
    );
    final toolCode = toolObj['toolCode'] as String?;

    if (toolCode == null) {
      setState(() {
        _selectedToolAvailableCount = null;
      });
      return;
    }

    final snapshot = await FirestoreService
        .getCollection('toolsMovement')
        .where('toolCode', isEqualTo: toolCode)
        .limit(1)
        .get();

    setState(() {
      _selectedToolAvailableCount = snapshot.docs.isNotEmpty
          ? snapshot.docs.first['availableCount'] as int?
          : null;
    });
  }

  void _addTool() {
    if (_selectedTool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tool')),
      );
      return;
    }

    if (_toolCount == null || _toolCount! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid tool count')),
      );
      return;
    }

    if (_selectedToolAvailableCount != null &&
        _toolCount! > _selectedToolAvailableCount!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Count exceeds available quantity')),
      );
      return;
    }

    final toolObj = _tools.firstWhere((t) => t['name'] == _selectedTool);
    
    setState(() {
      _addedTools.add({
        'name': _selectedTool!,
        'toolCode': toolObj['toolCode'],
        'count': _toolCount!,
      });
      _selectedTool = null;
      _toolCount = null;
      _toolCountController.clear();
      _selectedToolAvailableCount = null;
    });
  }

  void _resetForm() {
    setState(() {
      _managerNameController.clear();
      _projectNameController.clear();
      _supervisorNameController.clear();
      _toolCountController.clear();
      _selectedDate = null;
      _selectedSiteId = null;
      _selectedTool = null;
      _toolCount = null;
      _addedTools.clear();
      _selectedToolAvailableCount = null;
    });
  }

  Future<void> _saveReturn() async {
    if (_selectedSiteId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Site ID and Date')),
      );
      return;
    }

    if (_addedTools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add tools to return')),
      );
      return;
    }

    final dateStr = DateFormat('ddMMyyyy').format(_selectedDate!);
    final docId = '${_selectedSiteId}_$dateStr';

    String trId = 'TR001';
    try {
      final snapshot = await FirestoreService
        .getCollection('toolsReturn')
          .orderBy('trId', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final lastTrId = snapshot.docs.first['trId'] as String?;
        if (lastTrId != null && lastTrId.startsWith('TR')) {
          final lastNum = int.tryParse(lastTrId.substring(2)) ?? 0;
          trId = 'TR${(lastNum + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (e) {
      debugPrint('Error fetching last trId: $e');
    }

    final data = {
      'trId': trId,
      'date': '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30',
      'mgrName': _managerNameController.text,
      'supervisorName': _supervisorNameController.text,
      'rfSiteId': _selectedSiteId,
      'projectName': _projectNameController.text,
      'tools': _addedTools,
    };

    try {
      for (final tool in _addedTools) {
        final toolCode = tool['toolCode'];
        final count = tool['count'] as int;

        // Update toolsAtSite
        final siteQuery = await FirestoreService
            .getCollection('toolsAtSite')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (siteQuery.docs.isNotEmpty) {
          final docRef = siteQuery.docs.first.reference;
          final current = siteQuery.docs.first['availableCount'] as int? ?? 0;
          await docRef.update({'availableCount': current - count});
        }

        // Update toolsAtCompany
        final companyQuery = await FirestoreService
            .getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (companyQuery.docs.isNotEmpty) {
          final docRef = companyQuery.docs.first.reference;
          final current = companyQuery.docs.first['availableCount'] as int? ?? 0;
          await docRef.update({'availableCount': current + count});
        }
      }

      await FirestoreService
          .getCollection('toolsMovement')
          .doc(docId)
          .set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tools returned successfully')),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving return: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Site to Company Return',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Return Details'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _managerNameController,
                    label: 'Manager Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _selectedSiteId,
                    label: 'Site ID',
                    items: _siteIds,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedSiteId = newValue;
                      });
                      _fetchAndSetProjectName(newValue);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _projectNameController,
                    label: 'Project Name',
                    icon: Icons.business,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _supervisorNameController,
                    label: 'Supervisor Name',
                    icon: Icons.badge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Tools Selection'),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDropdownField(
                        value: _selectedTool,
                        label: 'Select Tool',
                        items: _tools.map((t) => t['name'] as String).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedTool = newValue;
                            _toolCountController.clear();
                            _toolCount = null;
                          });
                          _fetchAvailableCountForSelectedTool(newValue);
                        },
                      ),
                      const SizedBox(height: 4),
                      _AvailableCountWithWarning(
                        availableCount: _selectedToolAvailableCount,
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        controller: _toolCountController,
                        label: 'Count',
                        icon: Icons.onetwothree,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _toolCount = int.tryParse(value);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GlassButton(
                    label: 'Add Tool',
                    onPressed: _addTool,
                  ),
                ],
              ),
            ),
            if (_addedTools.isNotEmpty) ...[
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Selected Tools'),
                    const SizedBox(height: 16),
                    _buildToolsTable(),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Cancel',
                    isSecondary: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    label: 'Save Return',
                    onPressed: _saveReturn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return GlassTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: cs.surfaceContainerHighest,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
        prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: cs.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surface.withOpacity(0.05),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              _selectedDate == null
                  ? 'Select Date'
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
              style: TextStyle(color: cs.onSurface, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsTable() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Responsive.scaleH(context, 12)),
        child: Column(
          children: [
            Container(
              color: cs.primary.withOpacity(0.1),
              padding: EdgeInsets.symmetric(
                vertical: Responsive.scaleV(context, 12),
                horizontal: Responsive.scaleH(context, 8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Tool Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 14),
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Tool Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 14),
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 14),
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: Responsive.scaleH(context, 40)),
                ],
              ),
            ),
            ...List.generate(_addedTools.length, (index) {
              final tool = _addedTools[index];
              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.scaleV(context, 8),
                  horizontal: Responsive.scaleH(context, 8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        tool['name'] ?? '',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        tool['toolCode'] ?? '',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        tool['count'].toString(),
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: cs.error,
                        size: Responsive.scaleH(context, 20),
                      ),
                      onPressed: () => setState(() => _addedTools.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AvailableCountWithWarning extends StatelessWidget {
  final int? availableCount;

  const _AvailableCountWithWarning({required this.availableCount});

  @override
  Widget build(BuildContext context) {
    if (availableCount == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final bool isLow = availableCount! < 5;
    final Color color = isLow ? cs.error : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(top: Responsive.scaleV(context, 4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: Responsive.scaleH(context, 16),
            color: color,
          ),
          SizedBox(width: Responsive.scaleH(context, 4)),
          Text(
            'Available: $availableCount',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 13),
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
