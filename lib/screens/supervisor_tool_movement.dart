import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final Color _primaryColor = const Color(0xFF0B3470);
  final Color _accentColor = const Color(0xFFE0AFAF);
  final Color _backgroundColor = const Color(0xFFF5F5F5);

  // Form controllers
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
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

  Future<void> _fetchSiteIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
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
    final snapshot = await FirebaseFirestore.instance.collection('tools').get();
    setState(() {
      _tools = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'toolId': data['toolId'] ?? '',
          'toolName': data['toolName'] ?? '',
          'toolCode': data['toolCode'] ?? '',
          'toolOwner': data['toolOwner'] ?? '',
          'availableCount': data['availableCount'] ?? 0,
          'toolCount': data['toolCount'] ?? 0,
          'description': data['description'] ?? '',
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryColor),
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

    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
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

  Future<void> _fetchAvailableCountForSelectedTool(String? toolId) async {
    if (toolId == null) {
      setState(() {
        _selectedToolAvailableCount = null;
      });
      return;
    }

    final toolObj = _tools.firstWhere(
      (t) => t['toolId'] == toolId,
      orElse: () => {'toolCode': null},
    );
    final toolCode = toolObj['toolCode'] as String?;

    if (toolCode == null) {
      setState(() {
        _selectedToolAvailableCount = null;
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('toolsAtSite')
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a tool')));
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

    setState(() {
      _addedTools.add({'tool': _selectedTool!, 'count': _toolCount!});
      _selectedTool = null;
      _toolCount = null;
      _selectedToolAvailableCount = null;
    });
  }

  void _removeTool(int index) {
    setState(() {
      _addedTools.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      _managerNameController.clear();
      _projectNameController.clear();
      _supervisorNameController.clear();
      _selectedDate = null;
      _selectedSiteId = null;
      _selectedTool = null;
      _toolCount = null;
      _addedTools.clear();
      _selectedToolAvailableCount = null;
    });
  }

  Future<void> _updateToolsInventory({
    required String toolCode,
    required String siteId,
    required int count,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('toolsInventory')
        .doc(toolCode);

    final now = DateTime.now();
    final isoString = now.toIso8601String();

    final docSnap = await docRef.get();
    List<dynamic> sites = [];
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      sites = data['sites'] ?? [];
      sites.removeWhere(
        (site) => site['siteId'] == siteId && site['toolCode'] == toolCode,
      );
    }

    sites.add({'count': count, 'siteId': siteId});

    await docRef.set({
      'lastUpdatedOn': isoString,
      'sites': sites,
      'toolCode': toolCode,
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

    // Generate document ID
    final dateStr = DateFormat('ddMMyyyy').format(_selectedDate!);
    final docId = '${_selectedSiteId}_$dateStr';

    // Generate trId (TR001, TR002, etc.)
    String trId = 'TR001';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('toolsReturn')
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
      // Fallback to TR001
    }

    // Prepare tools list
    final toolsList = _addedTools.map((tool) {
      final toolObj = _tools.firstWhere(
        (t) => t['toolId'] == tool['tool'],
        orElse: () => {'toolCode': tool['tool']},
      );
      return {
        'toolCode': toolObj['toolCode'] ?? tool['tool'],
        'toolCount': tool['count'],
      };
    }).toList();

    // Prepare return data
    final data = {
      'trId': trId,
      'date':
          '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30',
      'mgrName': _managerNameController.text,
      'supervisorName': _supervisorNameController.text,
      'rfSiteId': _selectedSiteId,
      'projectName': _projectNameController.text,
      'tools': toolsList,
    };

    try {
      // Update inventory for each tool
      for (final tool in _addedTools) {
        final toolObj = _tools.firstWhere(
          (t) => t['toolId'] == tool['tool'],
          orElse: () => {'toolCode': tool['tool']},
        );
        final toolCode = toolObj['toolCode'] ?? tool['tool'];
        final count = tool['count'] as int;

        // Update toolsAtSite (decrease count)
        final siteQuery = await FirebaseFirestore.instance
            .collection('toolsAtSite')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        int newSiteCount = 0;
        if (siteQuery.docs.isNotEmpty) {
          final docRef = siteQuery.docs.first.reference;
          final current = siteQuery.docs.first['availableCount'] as int? ?? 0;
          newSiteCount = current - count;
          await docRef.update({'availableCount': newSiteCount});
        }

        // Update toolsAtCompany (increase count)
        final companyQuery = await FirebaseFirestore.instance
            .collection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();

        if (companyQuery.docs.isNotEmpty) {
          final docRef = companyQuery.docs.first.reference;
          final current =
              companyQuery.docs.first['availableCount'] as int? ?? 0;
          await docRef.update({'availableCount': current + count});
        }

        // Update toolsInventory
        await _updateToolsInventory(
          toolCode: toolCode,
          siteId: _selectedSiteId!,
          count: newSiteCount,
        );
      }

      // Save return record
      await FirebaseFirestore.instance
          .collection('toolsReturn')
          .doc(docId)
          .set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tools returned successfully')),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving return: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Site to Company Return',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Return Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _managerNameController,
                      label: ' Name',
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
                      icon: Icons.work,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _supervisorNameController,
                      label: 'Supervisor Name',
                      icon: Icons.supervisor_account,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tools Selection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDropdownField(
                          value: _selectedTool,
                          label: 'Select Tool',
                          items: _tools
                              .map((t) => t['toolId'] as String)
                              .toList(),
                          displayItems: _tools
                              .map((t) => t['toolCode'] as String)
                              .toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedTool = newValue;
                              _toolCount = null;
                            });
                            _fetchAvailableCountForSelectedTool(newValue);
                          },
                        ),
                        const SizedBox(height: 4),
                        _AvailableCountWithWarning(
                          availableCount: _selectedToolAvailableCount,
                        ),
                        const SizedBox(height: 8),
                        _buildInputField(
                          label: 'Count',
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _toolCount = int.tryParse(value);
                            });
                          },
                          enabled:
                              _selectedToolAvailableCount != null &&
                              _selectedToolAvailableCount! > 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.add,
                          size: 20,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Add Tool',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: _addTool,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_addedTools.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Tools',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildToolsTable(),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    text: 'Return Tools',
                    icon: Icons.keyboard_return,
                    isPrimary: true,
                    onPressed: _saveReturn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    text: 'Reset',
                    icon: Icons.refresh,
                    isPrimary: false,
                    onPressed: _resetForm,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    text: 'Cancel',
                    icon: Icons.close,
                    isPrimary: false,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    TextEditingController? controller,
    String label = '',
    IconData? icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        filled: true,
        fillColor: readOnly || !enabled ? Colors.grey.shade100 : Colors.white,
      ),
      keyboardType: keyboardType,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String?> items,
    List<String>? displayItems,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            displayItems != null && displayItems.length > index
                ? displayItems[index]
                : item ?? '',
          ),
        );
      }).toList(),
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(8),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'Select date'
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required bool isPrimary,
    required void Function() onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _primaryColor : Colors.white,
        foregroundColor: isPrimary ? Colors.white : _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : BorderSide(color: _primaryColor),
        ),
        elevation: isPrimary ? 2 : 0,
      ),
    );
  }

  Widget _buildToolsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Tool Id',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Tool Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Text(''),
                    ),
                  ),
                ],
              ),
            ),
            ..._addedTools.asMap().entries.map((entry) {
              final i = entry.key;
              final tool = entry.value;
              final toolObj = _tools.firstWhere(
                (t) => t['toolId'] == tool['tool'],
                orElse: () => {'toolCode': ''},
              );
              final toolCode = toolObj['toolCode'] ?? '';
              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          tool['tool'] ?? '',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          toolCode,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          tool['count'].toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeTool(i),
                      ),
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
  const _AvailableCountWithWarning({super.key, this.availableCount});

  @override
  Widget build(BuildContext context) {
    if (availableCount == null) {
      return const Text(
        'Available: N/A',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    if (availableCount == 0) {
      return Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 16),
          const SizedBox(width: 4),
          Text(
            'Available: 0 (Not available)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    if (availableCount! < 5) {
      return Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 16),
          const SizedBox(width: 4),
          Text(
            'Available: $availableCount (Low stock!)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    return Text(
      'Available: $availableCount',
      style: const TextStyle(fontSize: 12, color: Colors.green),
    );
  }
}
