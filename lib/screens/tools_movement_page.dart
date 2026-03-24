import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ToolsMovementPage extends StatefulWidget {
  const ToolsMovementPage({super.key});

  @override
  State<ToolsMovementPage> createState() => _ToolsMovementPageState();
}

class _ToolsMovementPageState extends State<ToolsMovementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color _primaryColor = const Color(0xFF0b3470);
  final Color _accentColor = const Color(0xFF4d79c2);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2c3e50);
  final Color _successColor = const Color(0xFF27ae60);
  final Color _warningColor = const Color(0xFFe67e22);
  final Color _errorColor = const Color(0xFFe74c3c);

  // Company to Site variables
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
  DateTime? _selectedDate;
  String? _selectedSiteId;
  String? _selectedTool;
  int? _toolCount;
  final List<Map<String, dynamic>> _addedTools = [];

  // Site to Company variables
  final TextEditingController _returnProjectNameController =
      TextEditingController();
  final TextEditingController _returnManagerNameController =
      TextEditingController();
  final TextEditingController _returnSupervisorNameController =
      TextEditingController();
  DateTime? _returnSelectedDate;
  String? _returnSelectedSiteId;
  String? _returnSelectedTool;
  int? _returnToolCount;
  final List<Map<String, dynamic>> _returnAddedTools = [];

  // Firestore data
  List<String> _siteIds = [];
  List<Map<String, dynamic>> _tools = <Map<String, dynamic>>[];

  int? _selectedToolAvailableCount;
  int? _returnSelectedToolAvailableCount;

  // Search controllers and texts for filtering tools
  final TextEditingController _companyToolSearchController =
      TextEditingController();
  String _companyToolSearchText = '';

  final TextEditingController _returnToolSearchController =
      TextEditingController();
  String _returnToolSearchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSiteIds();
    _fetchTools();

    // Add listeners to update filtered lists on search input
    _companyToolSearchController.addListener(() {
      setState(() {
        _companyToolSearchText = _companyToolSearchController.text
            .trim()
            .toLowerCase();
      });
    });

    _returnToolSearchController.addListener(() {
      setState(() {
        _returnToolSearchText = _returnToolSearchController.text
            .trim()
            .toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectNameController.dispose();
    _managerNameController.dispose();
    _supervisorNameController.dispose();
    _returnProjectNameController.dispose();
    _returnManagerNameController.dispose();
    _returnSupervisorNameController.dispose();
    _companyToolSearchController.dispose();
    _returnToolSearchController.dispose();
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
          'toolOwner': data['toolOwner'] ?? '',
          'availableCount': data['availableCount'] ?? 0,
          'toolCount': data['toolCount'] ?? 0,
          'description': data['description'] ?? '',
        };
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isReturn) async {
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
              onSurface: _textColor,
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
        if (isReturn) {
          _returnSelectedDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  void _addTool(bool isReturn) {
    if ((isReturn && _returnSelectedTool == null) ||
        (!isReturn && _selectedTool == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a tool'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }
    if ((isReturn && _returnToolCount == null) ||
        (!isReturn && _toolCount == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter tool count'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    // Check if count exceeds available
    final availableCount = isReturn
        ? _returnSelectedToolAvailableCount
        : _selectedToolAvailableCount;

    final enteredCount = isReturn ? _returnToolCount : _toolCount;

    if (enteredCount! > availableCount!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot exceed available count of $availableCount'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    setState(() {
      if (isReturn) {
        _returnAddedTools.add({
          'tool': _returnSelectedTool!,
          'count': _returnToolCount!,
        });
        _returnSelectedTool = null;
        _returnToolCount = null;
        _returnSelectedToolAvailableCount = null;
      } else {
        _addedTools.add({'tool': _selectedTool!, 'count': _toolCount!});
        _selectedTool = null;
        _toolCount = null;
        _selectedToolAvailableCount = null;
      }
    });
  }

  void _resetForm(bool isReturn) {
    setState(() {
      if (isReturn) {
        _returnProjectNameController.clear();
        _returnManagerNameController.clear();
        _returnSupervisorNameController.clear();
        _returnSelectedDate = null;
        _returnSelectedSiteId = null;
        _returnSelectedTool = null;
        _returnToolCount = null;
        _returnAddedTools.clear();
        _returnSelectedToolAvailableCount = null;
        _returnToolSearchController.clear();
      } else {
        _projectNameController.clear();
        _managerNameController.clear();
        _supervisorNameController.clear();
        _selectedDate = null;
        _selectedSiteId = null;
        _selectedTool = null;
        _toolCount = null;
        _addedTools.clear();
        _selectedToolAvailableCount = null;
        _companyToolSearchController.clear();
      }
    });
  }

  Future<void> _updateToolsInventory({
    required String toolCode,
    required String siteId,
    required int count,
  }) async {
    final docRef = FirestoreService
        .getCollection('toolsInventory')
        .doc(toolCode);

    final now = DateTime.now();
    final isoString = now.toIso8601String();

    final docSnap = await docRef.get();
    List<dynamic> sites = [];
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      sites = data['sites'] ?? [];
      bool siteExists = false;
      for (var site in sites) {
        if (site['siteId'] == siteId) {
          site['count'] = (site['count'] ?? 0) + count;
          siteExists = true;
          break;
        }
      }
      if (!siteExists) {
        sites.add({'count': count, 'siteId': siteId});
      }
    } else {
      sites.add({'count': count, 'siteId': siteId});
    }
    await docRef.set({
      'lastUpdatedOn': isoString,
      'sites': sites,
      'toolCode': toolCode,
    });
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
    final snapshot = await FirestoreService
        .getCollection('toolsAtCompany')
        .where('toolCode', isEqualTo: toolCode)
        .limit(1)
        .get();
    int? count;
    if (snapshot.docs.isNotEmpty) {
      count = snapshot.docs.first['availableCount'] as int?;
    }
    setState(() {
      _selectedToolAvailableCount = count;
    });
  }

  Future<void> _fetchAvailableCountForReturnSelectedTool(String? toolId) async {
    if (toolId == null || _returnSelectedSiteId == null) {
      setState(() {
        _returnSelectedToolAvailableCount = null;
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
        _returnSelectedToolAvailableCount = null;
      });
      return;
    }
    final docSnap = await FirestoreService
        .getCollection('toolsInventory')
        .doc(toolCode)
        .get();
    int? count;
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      final sites = data['sites'] as List<dynamic>? ?? [];
      final siteEntry = sites.firstWhere(
        (site) => site['siteId'] == _returnSelectedSiteId,
        orElse: () => null,
      );
      if (siteEntry != null && siteEntry['count'] is int) {
        count = siteEntry['count'] as int;
      } else {
        count = 0;
      }
    }
    setState(() {
      _returnSelectedToolAvailableCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtered lists for search bars (case-insensitive)
    final companyFilteredTools = _tools.where((t) {
      final code = (t['toolCode'] ?? '').toString().toLowerCase();
      final name = (t['toolName'] ?? '').toString().toLowerCase();
      return code.contains(_companyToolSearchText) ||
          name.contains(_companyToolSearchText);
    }).toList();

    final returnFilteredTools = _tools.where((t) {
      final code = (t['toolCode'] ?? '').toString().toLowerCase();
      final name = (t['toolName'] ?? '').toString().toLowerCase();
      return code.contains(_returnToolSearchText) ||
          name.contains(_returnToolSearchText);
    }).toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tools Movement',
          style: TextStyle(fontWeight: FontWeight.bold, ),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Company to Site'),
            Tab(text: 'Site to Company'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCompanyToSiteTab(companyFilteredTools),
          _buildSiteToCompanyTab(returnFilteredTools),
        ],
      ),
    );
  }

  Future<void> _fetchAndSetProjectName(String? siteId, bool isReturn) async {
    String projectName = '';
    String supervisorName = '';
    if (siteId != null && siteId.trim().isNotEmpty) {
      final snapshot = await FirestoreService
          .getCollection('siteSupervisorMap')
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        projectName = data['projectName'] ?? '';
        supervisorName = data['supervisor'] ?? '';
      }
    }
    setState(() {
      if (isReturn) {
        _returnProjectNameController.text = projectName;
        _returnSupervisorNameController.text = supervisorName;
      } else {
        _projectNameController.text = projectName;
        _supervisorNameController.text = supervisorName;
      }
    });
  }

  Widget _buildCompanyToSiteTab(List<Map<String, dynamic>> filteredTools) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: _cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.send, color: _primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Transfer Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _managerNameController,
                    label: 'Manager Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(false),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _selectedSiteId,
                    label: 'Site ID',
                    items: _siteIds,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedSiteId = newValue;
                      });
                      _fetchAndSetProjectName(newValue, false);
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
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: _cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, color: _primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Tools Selection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search bar
                  TextField(
                    controller: _companyToolSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search Tools',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      filled: true,
                      
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _selectedTool,
                    label: 'Select Tool',
                    items: filteredTools
                        .map((t) => t['toolId'] as String)
                        .toList(),
                    displayItems: filteredTools
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
                  const SizedBox(height: 8),
                  _AvailableCountWithWarning(
                    availableCount: _selectedToolAvailableCount,
                    primaryColor: _primaryColor,
                    successColor: _successColor,
                    warningColor: _warningColor,
                    errorColor: _errorColor,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Count',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _toolCount = int.tryParse(value);
                      });
                    },
                    enabled:
                        _selectedToolAvailableCount != 0 &&
                        _selectedToolAvailableCount != null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Tool'),
                      onPressed: () => _addTool(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
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
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: _cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list, color: _primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          'Selected Tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildToolsTable(_addedTools),
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
                  text: 'Move Tools',
                  icon: Icons.send,
                  isPrimary: true,
                  onPressed: () async {
                    if (_addedTools.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please add tools to move'),
                          backgroundColor: _errorColor,
                        ),
                      );
                      return;
                    }
                    await _saveCompanyToSiteMovement();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  text: 'Reset',
                  icon: Icons.refresh,
                  isPrimary: false,
                  onPressed: () => _resetForm(false),
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
    );
  }

  Widget _buildSiteToCompanyTab(List<Map<String, dynamic>> filteredTools) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: _cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.keyboard_return, color: _primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Return Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _returnManagerNameController,
                    label: 'Manager Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(true),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _returnSelectedSiteId,
                    label: 'Site ID',
                    items: _siteIds,
                    onChanged: (newValue) {
                      setState(() {
                        _returnSelectedSiteId = newValue;
                      });
                      _fetchAndSetProjectName(newValue, true);
                      if (_returnSelectedTool != null) {
                        _fetchAvailableCountForReturnSelectedTool(
                          _returnSelectedTool,
                        );
                      } else {
                        setState(() {
                          _returnSelectedToolAvailableCount = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _returnProjectNameController,
                    label: 'Project Name',
                    icon: Icons.work,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _returnSupervisorNameController,
                    label: 'Supervisor Name',
                    icon: Icons.supervisor_account,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: _cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, color: _primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Tools Selection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search bar
                  TextField(
                    controller: _returnToolSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search Tools',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      filled: true,
                      
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _returnSelectedTool,
                    label: 'Select Tool',
                    items: filteredTools
                        .map((t) => t['toolId'] as String)
                        .toList(),
                    displayItems: filteredTools
                        .map((t) => t['toolCode'] as String)
                        .toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _returnSelectedTool = newValue;
                        _returnToolCount = null;
                      });
                      _fetchAvailableCountForReturnSelectedTool(newValue);
                    },
                  ),
                  const SizedBox(height: 8),
                  _AvailableCountWithWarning(
                    availableCount: _returnSelectedToolAvailableCount,
                    primaryColor: _primaryColor,
                    successColor: _successColor,
                    warningColor: _warningColor,
                    errorColor: _errorColor,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Count',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _returnToolCount = int.tryParse(value);
                      });
                    },
                    enabled:
                        _returnSelectedToolAvailableCount != 0 &&
                        _returnSelectedToolAvailableCount != null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Tool'),
                      onPressed: () => _addTool(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_returnAddedTools.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: _cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list, color: _primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          'Selected Tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildToolsTable(_returnAddedTools, isReturn: true),
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
                  onPressed: () async {
                    if (_returnAddedTools.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please add tools to return'),
                          backgroundColor: _errorColor,
                        ),
                      );
                      return;
                    }
                    await _saveSiteToCompanyReturn();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  text: 'Reset',
                  icon: Icons.refresh,
                  isPrimary: false,
                  onPressed: () => _resetForm(true),
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
    );
  }

  Future<void> _saveSiteToCompanyReturn() async {
    if (_returnSelectedSiteId == null || _returnSelectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select Site ID and Date'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }
    final dateStr = DateFormat('ddMMyyyy').format(_returnSelectedDate!);
    final docId = '${_returnSelectedSiteId}_$dateStr';
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
    } catch (e) {}
    final formattedDate =
        '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30';
    final toolsList = _returnAddedTools.map((tool) {
      final toolObj = _tools.firstWhere(
        (t) => t['toolId'] == tool['tool'],
        orElse: () => {'toolCode': tool['tool']},
      );
      return {
        'toolCode': toolObj['toolCode'] ?? tool['tool'],
        'toolCount': tool['count'],
      };
    }).toList();
    final data = {
      'trId': trId,
      'date': formattedDate,
      'mgrName': _returnManagerNameController.text,
      'supervisorName': _returnSupervisorNameController.text,
      'rfSiteId': _returnSelectedSiteId,
      'projectName': _returnProjectNameController.text,
      'tools': toolsList,
    };
    try {
      for (final tool in _returnAddedTools) {
        final toolObj = _tools.firstWhere(
          (t) => t['toolId'] == tool['tool'],
          orElse: () => {'toolCode': tool['tool']},
        );
        final toolCode = toolObj['toolCode'] ?? tool['tool'];
        final enteredCount = tool['count'] as int;

        // Site: DECREMENT
        final siteQuery = await FirestoreService
            .getCollection('toolsAtSite')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();
        if (siteQuery.docs.isNotEmpty) {
          final docRef = siteQuery.docs.first.reference;
          await docRef.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        // Company: INCREMENT
        final companyQuery = await FirestoreService
            .getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();
        if (companyQuery.docs.isNotEmpty) {
          final docRef = companyQuery.docs.first.reference;
          await docRef.update({
            'availableCount': FieldValue.increment(enteredCount),
          });
        }
        await _updateToolsInventory(
          toolCode: toolCode,
          siteId: _returnSelectedSiteId!,
          count: -enteredCount,
        );
      }
      await FirestoreService
          .getCollection('toolsReturn')
          .doc(docId)
          .set(data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tools returned successfully'),
          backgroundColor: _successColor,
        ),
      );
      _resetForm(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to Firebase: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  Future<void> _saveCompanyToSiteMovement() async {
    if (_selectedSiteId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select Site ID and Date'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }
    final dateStr = DateFormat('ddMMyyyy').format(_selectedDate!);
    final docId = '${_selectedSiteId}_$dateStr';
    String tmId = 'TM001';
    try {
      final snapshot = await FirestoreService
          .getCollection('toolsMovement')
          .orderBy('tmId', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final lastTmId = snapshot.docs.first['tmId'] as String?;
        if (lastTmId != null && lastTmId.startsWith('TM')) {
          final lastNum = int.tryParse(lastTmId.substring(2)) ?? 0;
          tmId = 'TM${(lastNum + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (e) {}
    final formattedDate =
        '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(DateTime.now())} UTC+5:30';
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
    final data = {
      'tmId': tmId,
      'date': formattedDate,
      'mgrName': _managerNameController.text,
      'supervisorName': _supervisorNameController.text,
      'mtSiteId': _selectedSiteId,
      'projectName': _projectNameController.text,
      'tools': toolsList,
    };
    try {
      for (final tool in _addedTools) {
        final toolObj = _tools.firstWhere(
          (t) => t['toolId'] == tool['tool'],
          orElse: () => {'toolCode': tool['tool']},
        );
        final toolCode = toolObj['toolCode'] ?? tool['tool'];
        final enteredCount = tool['count'] as int;

        // Company: DECREMENT
        final companyQuery = await FirestoreService
            .getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: toolCode)
            .limit(1)
            .get();
        if (companyQuery.docs.isNotEmpty) {
          final docRef = companyQuery.docs.first.reference;
          await docRef.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        // Site: INCREMENT, create if not exist
        final siteDocRef = FirestoreService
            .getCollection('toolsAtSite')
            .doc(toolCode);
        await siteDocRef.set({'toolCode': toolCode}, SetOptions(merge: true));
        await siteDocRef.update({
          'availableCount': FieldValue.increment(enteredCount),
        });

        await _updateToolsInventory(
          toolCode: toolCode,
          siteId: _selectedSiteId!,
          count: enteredCount,
        );
      }

      await FirestoreService
          .getCollection('toolsMovement')
          .doc(docId)
          .set(data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tools moved successfully'),
          backgroundColor: _successColor,
        ),
      );
      _resetForm(false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to Firebase: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
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
        prefixIcon: icon != null
            ? Icon(icon, color: _primaryColor.withOpacity(0.7))
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor),
        ),
        filled: true,
        fillColor: readOnly || !enabled ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
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
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor),
        ),
        filled: true,
        
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
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
      borderRadius: BorderRadius.circular(10),
      icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildDatePicker(bool isReturn) {
    return InkWell(
      onTap: () => _selectDate(context, isReturn),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(
            Icons.calendar_today,
            color: _primaryColor.withOpacity(0.7),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
          ),
          filled: true,
          
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isReturn
                  ? _returnSelectedDate == null
                        ? 'Select date'
                        : DateFormat('yyyy-MM-dd').format(_returnSelectedDate!)
                  : _selectedDate == null
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: _primaryColor, width: 1.5),
        ),
        elevation: isPrimary ? 2 : 0,
        shadowColor: _primaryColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildToolsTable(
    List<Map<String, dynamic>> tools, {
    bool isReturn = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _primaryColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
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
                          color: _textColor,
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
                          color: _textColor,
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
                          color: _textColor,
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
            ...tools.asMap().entries.map((entry) {
              final i = entry.key;
              final tool = entry.value;
              // Find toolCode for this toolId
              String toolCode = '';
              if (tool['tool'] != null) {
                final toolObj = _tools.firstWhere(
                  (t) => t['toolId'] == tool['tool'],
                  orElse: () => {'toolCode': ''},
                );
                toolCode = toolObj['toolCode'] ?? '';
              }
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _primaryColor.withOpacity(0.1)),
                  ),
                  color: i.isEven
                      ? _primaryColor.withOpacity(0.03)
                      : Colors.transparent,
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
                          style: TextStyle(color: _textColor),
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
                          style: TextStyle(color: _textColor),
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
                          style: TextStyle(color: _textColor),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: IconButton(
                        icon: Icon(Icons.delete, color: _errorColor),
                        onPressed: () {
                          setState(() {
                            if (isReturn) {
                              _returnAddedTools.removeAt(i);
                            } else {
                              _addedTools.removeAt(i);
                            }
                          });
                        },
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

/// Widget to show available count and warning, and highlight if needed
class _AvailableCountWithWarning extends StatelessWidget {
  final int? availableCount;
  final Color primaryColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  const _AvailableCountWithWarning({
    super.key,
    this.availableCount,
    required this.primaryColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    if (availableCount == null) {
      return Text(
        'Available: N/A',
        style: TextStyle(fontSize: 12, color: primaryColor.withOpacity(0.7)),
      );
    }
    if (availableCount == 0) {
      return Row(
        children: [
          Icon(Icons.warning, color: errorColor, size: 16),
          const SizedBox(width: 4),
          Text(
            'Available: 0 (Not available)',
            style: TextStyle(
              fontSize: 12,
              color: errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    if (availableCount! < 5) {
      return Row(
        children: [
          Icon(Icons.warning, color: warningColor, size: 16),
          const SizedBox(width: 4),
          Text(
            'Available: $availableCount (Low stock!)',
            style: TextStyle(
              fontSize: 12,
              color: warningColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    return Text(
      'Available: $availableCount',
      style: TextStyle(fontSize: 12, color: successColor),
    );
  }
}
