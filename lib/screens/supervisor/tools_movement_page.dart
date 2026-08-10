import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class ToolsMovementPage extends StatefulWidget {
  const ToolsMovementPage({super.key});

  @override
  State<ToolsMovementPage> createState() => _ToolsMovementPageState();
}

class _ToolsMovementPageState extends State<ToolsMovementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _errorColor => Theme.of(context).colorScheme.error;

  // Company to Site variables
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
  final TextEditingController _toolCountController = TextEditingController();
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
  final TextEditingController _returnToolCountController =
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchSiteIds();
    _fetchTools();
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
    _toolCountController.dispose();
    _returnToolCountController.dispose();
    super.dispose();
  }

  Future<void> _fetchSiteIds() async {
    final snapshot = await FirestoreService.getCollection(
      'siteSupervisorMap',
    ).get();
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
        _returnToolCountController.clear();
        _returnSelectedToolAvailableCount = null;
      } else {
        _addedTools.add({'tool': _selectedTool!, 'count': _toolCount!});
        _selectedTool = null;
        _toolCount = null;
        _toolCountController.clear();
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
        _returnToolCountController.clear();
        _returnAddedTools.clear();
        _returnSelectedToolAvailableCount = null;
      } else {
        _projectNameController.clear();
        _managerNameController.clear();
        _supervisorNameController.clear();
        _selectedDate = null;
        _selectedSiteId = null;
        _selectedTool = null;
        _toolCount = null;
        _toolCountController.clear();
        _addedTools.clear();
        _selectedToolAvailableCount = null;
      }
    });
  }

  Future<void> _updateToolsInventory({
    required String toolCode,
    required String siteId,
    required int count,
  }) async {
    final docRef = FirestoreService.getCollection(
      'toolsInventory',
    ).doc(toolCode);

    final now = DateTime.now();
    final isoString = now.toIso8601String();

    await FirestoreService.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'toolCode': toolCode,
          'availableCountAtSites': {siteId: count},
          'lastUpdated': isoString,
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> availableCountAtSites =
            Map<String, dynamic>.from(data['availableCountAtSites'] ?? {});

        final currentSiteCount = (availableCountAtSites[siteId] as int?) ?? 0;
        final newSiteCount = currentSiteCount + count;

        if (newSiteCount <= 0) {
          availableCountAtSites.remove(siteId);
        } else {
          availableCountAtSites[siteId] = newSiteCount;
        }

        transaction.update(docRef, {
          'availableCountAtSites': availableCountAtSites,
          'lastUpdated': isoString,
        });
      }
    });
  }

  Future<void> _fetchAvailableCountForSelectedTool(String? toolId) async {
    if (toolId == null) {
      setState(() {
        _selectedToolAvailableCount = null;
      });
      return;
    }
    final tool = _tools.firstWhere(
      (t) => t['toolId'] == toolId,
      orElse: () => {},
    );
    final toolCode = tool['toolCode'] ?? '';
    if (toolCode.isEmpty) {
      setState(() {
        _selectedToolAvailableCount = 0;
      });
      return;
    }

    final querySnapshot = await FirestoreService.getCollection(
      'toolsAtCompany',
    ).where('toolCode', isEqualTo: toolCode).limit(1).get();

    int count = 0;
    if (querySnapshot.docs.isNotEmpty) {
      final docData = querySnapshot.docs.first.data();
      count = docData['availableCount'] ?? 0;
    }
    setState(() {
      _selectedToolAvailableCount = count;
    });
  }

  Future<void> _fetchAvailableCountForReturnSelectedTool(String? toolId) async {
    if (toolId == null ||
        _returnSelectedSiteId == null ||
        _returnSelectedSiteId!.isEmpty) {
      setState(() {
        _returnSelectedToolAvailableCount = null;
      });
      return;
    }
    final tool = _tools.firstWhere(
      (t) => t['toolId'] == toolId,
      orElse: () => {},
    );
    final toolCode = tool['toolCode'] ?? '';
    if (toolCode.isEmpty) {
      setState(() {
        _returnSelectedToolAvailableCount = 0;
      });
      return;
    }

    final querySnapshot = await FirestoreService.getCollection(
      'toolsInventory',
    ).doc(toolCode).get();

    int count = 0;
    if (querySnapshot.exists) {
      final data = querySnapshot.data() as Map<String, dynamic>;
      final Map<String, dynamic> availableCountAtSites =
          Map<String, dynamic>.from(data['availableCountAtSites'] ?? {});
      count = (availableCountAtSites[_returnSelectedSiteId] as int?) ?? 0;
    }
    setState(() {
      _returnSelectedToolAvailableCount = count;
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
                    'Tools Movement',
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

            // ── Dark Pill Mode Switcher ──────────────────────────────────────
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
                                  Icons.send_rounded,
                                  size: 16,
                                  color: _tabController.index == 0
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'COMPANY TO SITE',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
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
                                  Icons.keyboard_return_rounded,
                                  size: 16,
                                  color: _tabController.index == 1
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SITE TO COMPANY',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
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
                      _buildCompanyToSiteTab(darkCardBg, primaryColor),
                      _buildSiteToCompanyTab(darkCardBg, primaryColor),
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

  Future<void> _fetchAndSetProjectName(String? siteId, bool isReturn) async {
    String projectName = '';
    String supervisorName = '';
    if (siteId != null && siteId.trim().isNotEmpty) {
      final snapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('site', isEqualTo: siteId).limit(1).get();
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

  // ── COMPANY TO SITE TAB ──────────────────────────────────────────────────
  Widget _buildCompanyToSiteTab(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Transfer Details Card
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
                _buildSectionHeader('Transfer Details', Icons.send_rounded),
                const SizedBox(height: 18),
                _buildTextField(
                  label: 'Manager Name',
                  controller: _managerNameController,
                  hint: 'Enter Manager Name',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 14),
                _buildDatePicker(false),
                const SizedBox(height: 14),
                _buildDropdownField(
                  value: _selectedSiteId,
                  label: 'Site ID',
                  items: _siteIds,
                  icon: Icons.location_on_rounded,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSiteId = newValue;
                    });
                    _fetchAndSetProjectName(newValue, false);
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Project Name',
                  controller: _projectNameController,
                  hint: 'Auto-filled from selection',
                  readOnly: true,
                  icon: Icons.business_rounded,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Supervisor Name',
                  controller: _supervisorNameController,
                  hint: 'Enter Supervisor Name',
                  icon: Icons.supervisor_account_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tools Selection Card
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
                _buildSectionHeader('Tools Selection', Icons.build_rounded),
                const SizedBox(height: 18),
                _buildDropdownField(
                  value: _selectedTool,
                  label: 'Select Tool',
                  items: _tools.map((t) => t['toolId'] as String).toList(),
                  displayItems:
                      _tools.map((t) => t['toolCode'] as String).toList(),
                  icon: Icons.inventory_2_rounded,
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
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Count',
                  controller: _toolCountController,
                  hint: 'Enter count',
                  keyboardType: TextInputType.number,
                  icon: Icons.tag_rounded,
                  enabled: _selectedToolAvailableCount != 0 &&
                      _selectedToolAvailableCount != null,
                  onChanged: (value) {
                    setState(() {
                      _toolCount = int.tryParse(value);
                    });
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                      color: Color(0xFF0A183D),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                    ),
                    onPressed: () => _addTool(false),
                    label: const Text(
                      'Add Tool',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_addedTools.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                  _buildSectionHeader('Selected Tools', Icons.list_alt_rounded),
                  const SizedBox(height: 16),
                  _buildToolsTable(_addedTools),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Actions Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
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
                          Icons.swap_horiz_rounded,
                          size: 22,
                          color: Color(0xFF0A183D),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'MOVE TOOLS',
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
                  onPressed: () => _resetForm(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'RESET',
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── SITE TO COMPANY TAB ──────────────────────────────────────────────────
  Widget _buildSiteToCompanyTab(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Return Details Card
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
                _buildSectionHeader(
                  'Return Details',
                  Icons.keyboard_return_rounded,
                ),
                const SizedBox(height: 18),
                _buildTextField(
                  label: 'Manager Name',
                  controller: _returnManagerNameController,
                  hint: 'Enter Manager Name',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 14),
                _buildDatePicker(true),
                const SizedBox(height: 14),
                _buildDropdownField(
                  value: _returnSelectedSiteId,
                  label: 'Site ID',
                  items: _siteIds,
                  icon: Icons.location_on_rounded,
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
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Project Name',
                  controller: _returnProjectNameController,
                  hint: 'Auto-filled from selection',
                  readOnly: true,
                  icon: Icons.business_rounded,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Supervisor Name',
                  controller: _returnSupervisorNameController,
                  hint: 'Enter Supervisor Name',
                  icon: Icons.supervisor_account_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tools Selection Card
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
                _buildSectionHeader('Tools Selection', Icons.build_rounded),
                const SizedBox(height: 18),
                _buildDropdownField(
                  value: _returnSelectedTool,
                  label: 'Select Tool',
                  items: _tools.map((t) => t['toolId'] as String).toList(),
                  displayItems:
                      _tools.map((t) => t['toolCode'] as String).toList(),
                  icon: Icons.inventory_2_rounded,
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
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Count',
                  controller: _returnToolCountController,
                  hint: 'Enter count to return',
                  keyboardType: TextInputType.number,
                  icon: Icons.tag_rounded,
                  enabled: _returnSelectedToolAvailableCount != 0 &&
                      _returnSelectedToolAvailableCount != null,
                  onChanged: (value) {
                    setState(() {
                      _returnToolCount = int.tryParse(value);
                    });
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                      color: Color(0xFF0A183D),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                    ),
                    onPressed: () => _addTool(true),
                    label: const Text(
                      'Add Tool',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_returnAddedTools.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                  _buildSectionHeader('Selected Tools', Icons.list_alt_rounded),
                  const SizedBox(height: 16),
                  _buildToolsTable(_returnAddedTools, isReturn: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Actions Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
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
                          Icons.keyboard_return_rounded,
                          size: 22,
                          color: Color(0xFF0A183D),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'RETURN TOOLS',
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
                  onPressed: () => _resetForm(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'RESET',
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── HELPER BUILDERS ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    bool enabled = true,
    TextInputType? keyboardType,
    IconData? icon,
    ValueChanged<String>? onChanged,
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
            color: (!enabled || readOnly) ? const Color(0xFFF1F5F9) : Colors.white,
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
            readOnly: readOnly,
            enabled: enabled,
            keyboardType: keyboardType,
            onChanged: onChanged,
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

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String?> items,
    List<String>? displayItems,
    required void Function(String?) onChanged,
    IconData? icon,
  }) {
    final safeValue = items.contains(value) ? value : null;
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
          child: DropdownButtonFormField<String>(
            value: safeValue,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select $label',
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
            items: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  displayItems != null && displayItems.length > index
                      ? displayItems[index]
                      : item ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(bool isReturn) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);
    final date = isReturn ? _returnSelectedDate : _selectedDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, isReturn),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: brandIconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select date'
                        : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      color: date == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0A183D),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsTable(
    List<Map<String, dynamic>> tools, {
    bool isReturn = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Tool ID',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Tool Code',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Count',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(width: 36),
              ],
            ),
          ),
          ...tools.asMap().entries.map((entry) {
            final i = entry.key;
            final tool = entry.value;
            String toolCode = '';
            if (tool['tool'] != null) {
              final toolObj = _tools.firstWhere(
                (t) => t['toolId'] == tool['tool'],
                orElse: () => {'toolCode': ''},
              );
              toolCode = toolObj['toolCode'] ?? '';
            }
            final isLast = i == tools.length - 1;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          tool['tool'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          toolCode,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tool['count'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Color(0xFFF87171),
                            size: 18,
                          ),
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
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            );
          }).toList(),
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
      final snapshot = await FirestoreService.getCollection(
        'toolsReturn',
      ).orderBy('trId', descending: true).limit(1).get();
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

        final siteQuery = await FirestoreService.getCollection(
          'toolsAtSite',
        ).where('toolCode', isEqualTo: toolCode).limit(1).get();
        if (siteQuery.docs.isNotEmpty) {
          final docRef = siteQuery.docs.first.reference;
          await docRef.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        final companyQuery = await FirestoreService.getCollection(
          'toolsAtCompany',
        ).where('toolCode', isEqualTo: toolCode).limit(1).get();
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
      await FirestoreService.getCollection('toolsReturn').doc(docId).set(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tools returned successfully'),
          backgroundColor: Colors.green,
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
      final snapshot = await FirestoreService.getCollection(
        'toolsMovement',
      ).orderBy('tmId', descending: true).limit(1).get();
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

        final companyQuery = await FirestoreService.getCollection(
          'toolsAtCompany',
        ).where('toolCode', isEqualTo: toolCode).limit(1).get();
        if (companyQuery.docs.isNotEmpty) {
          final docRef = companyQuery.docs.first.reference;
          await docRef.update({
            'availableCount': FieldValue.increment(-enteredCount),
          });
        }

        final siteDocRef = FirestoreService.getCollection(
          'toolsAtSite',
        ).doc(toolCode);
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

      await FirestoreService.getCollection(
        'toolsMovement',
      ).doc(docId).set(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tools moved successfully'),
          backgroundColor: Colors.green,
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
}

class _AvailableCountWithWarning extends StatelessWidget {
  final int? availableCount;
  final Color primaryColor;

  const _AvailableCountWithWarning({
    super.key,
    this.availableCount,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (availableCount == null) {
      return const Text(
        'Available: N/A',
        style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
      );
    }
    if (availableCount == 0) {
      return const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 16),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              'Available: 0 (Not available)',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFF87171),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }
    if (availableCount! < 5) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orangeAccent, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Available: $availableCount (Low stock!)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      'Available: $availableCount',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF4ADE80),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
