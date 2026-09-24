import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/approval_workflow_service.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';

class ToolRequestForm extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final bool hideAppBar;
  final VoidCallback? onRequestSubmitted;
  final VoidCallback? onCancel;

  const ToolRequestForm({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    this.hideAppBar = false,
    this.onRequestSubmitted,
    this.onCancel,
  });

  @override
  State<ToolRequestForm> createState() => _ToolRequestFormState();
}

class _ToolRequestFormState extends State<ToolRequestForm> {
  // Dropdown lists
  List<String> siteDropdownItems = [];
  String? selectedSite;

  List<String> unitDropdownItems = ['Units', 'Nos', 'Sets', 'Pieces', 'Pairs'];
  String? selectedUnit = 'Units';

  String? supervisorError;

  // Store full site mappings to support dynamic lookup on site change
  List<Map<String, dynamic>> siteMappings = [];

  // Section 1 Controllers
  final TextEditingController siteIdController = TextEditingController();
  late final TextEditingController supervisorNameController;
  final TextEditingController projectController = TextEditingController();
  final TextEditingController projectStageController = TextEditingController();
  bool isLoadingSupervisorData = true;
  bool isSubmitting = false;

  // Dynamic branding color palette
  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get darkAccent => AppTheme.getDarkAccent(primaryColor);
  Color get errorColor => Theme.of(context).colorScheme.error;

  // Tools dropdown data from 'tools' collection
  List<Map<String, dynamic>> toolDocs = [];
  List<String> toolDescriptions = [];
  bool _isLoadingToolsList = true;

  DateTime? selectedDate;
  DateTime? returnDate;

  // Section 2: Required Tools Controllers
  String? selectedTool;
  final TextEditingController toolCodeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  String selectedPriority = 'Immediate';

  // Data Table Rows
  List<Map<String, dynamic>> addedTools = [];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    supervisorNameController = TextEditingController(
      text: widget.supervisorName,
    );
    _fetchSupervisorSites();
    _fetchToolsFromFirestore();
  }

  Future<void> _fetchSupervisorSites() async {
    setState(() {
      isLoadingSupervisorData = true;
      supervisorError = null;
    });
    try {
      final collection = FirestoreService.getCollection('siteSupervisorMap');

      var query = collection.where(
        'Supervisor ID',
        isEqualTo: widget.supervisorId,
      );
      var snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        query = collection.where(
          'supervisor',
          isEqualTo: widget.supervisorName,
        );
        snapshot = await query.get();
      }

      if (snapshot.docs.isNotEmpty) {
        siteDropdownItems = snapshot.docs
            .map((doc) => doc.data()['site']?.toString() ?? '')
            .where((site) => site.isNotEmpty)
            .toList();

        siteMappings = snapshot.docs.map((doc) => doc.data()).toList();

        if (siteDropdownItems.isNotEmpty) {
          selectedSite = siteDropdownItems.first;
          siteIdController.text = selectedSite!;
          final firstData = snapshot.docs.first.data();
          projectController.text = firstData['projectName']?.toString() ?? '';
          projectStageController.text =
              firstData['projectStage']?.toString() ?? '';
          supervisorNameController.text =
              firstData['supervisor']?.toString() ?? widget.supervisorName;
        } else {
          supervisorError = 'No sites assigned to this supervisor.';
        }
      } else {
        supervisorError = 'No site mapping found for this supervisor.';
      }
    } catch (e) {
      supervisorError = 'Failed to load supervisor data.';
    } finally {
      setState(() {
        isLoadingSupervisorData = false;
      });
    }
  }

  Future<void> _fetchToolsFromFirestore() async {
    setState(() => _isLoadingToolsList = true);
    try {
      final snapshot = await FirestoreService.getCollection('tools').get();
      final List<Map<String, dynamic>> allToolDocs = [];
      final Set<String> nameSet = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['toolName'] ?? data['name'] ?? doc.id).toString().trim();
        final code = (data['toolCode'] ?? data['code'] ?? doc.id).toString().trim();

        if (name.isNotEmpty && !nameSet.contains(name)) {
          nameSet.add(name);
          allToolDocs.add({
            'docId': doc.id,
            'toolName': name,
            'toolCode': code,
            'toolId': doc.id,
            'availableCount': data['availableCount'] ?? data['toolCount'] ?? 0,
            'unit': (data['unit'] ?? 'Units').toString(),
            'rawData': data,
          });
        }
      }

      // Sort alphabetically
      allToolDocs.sort(
        (a, b) => (a['toolName'] as String).toLowerCase().compareTo(
              (b['toolName'] as String).toLowerCase(),
            ),
      );

      final descriptions =
          allToolDocs.map((t) => t['toolName'] as String).toList();

      if (mounted) {
        setState(() {
          toolDocs = allToolDocs;
          toolDescriptions = descriptions;
          _isLoadingToolsList = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tools: $e');
      if (mounted) setState(() => _isLoadingToolsList = false);
    }
  }

  @override
  void dispose() {
    toolCodeController.dispose();
    supervisorNameController.dispose();
    siteIdController.dispose();
    projectController.dispose();
    projectStageController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  void _onToolChanged(String? value) {
    setState(() {
      selectedTool = value;
    });

    if (value != null && value.isNotEmpty) {
      final tool = toolDocs.firstWhere(
        (t) => (t['toolName'] ?? '').toString().trim() == value.trim(),
        orElse: () => {},
      );

      final codeVal = (tool['toolCode'] ?? '').toString().trim();
      final unitVal = (tool['unit'] ?? '').toString().trim();
      setState(() {
        if (codeVal.isNotEmpty) {
          toolCodeController.text = codeVal;
        }
        if (unitVal.isNotEmpty && !unitDropdownItems.contains(unitVal)) {
          unitDropdownItems.add(unitVal);
        }
        if (unitVal.isNotEmpty) {
          selectedUnit = unitVal;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickReturnDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: returnDate ?? (selectedDate ?? DateTime.now()).add(const Duration(days: 7)),
      firstDate: selectedDate ?? DateTime.now(),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        returnDate = picked;
      });
    }
  }

  void _addTool() {
    final tool = selectedTool?.trim() ?? '';
    final code = toolCodeController.text.trim();
    final qty = quantityController.text.trim();
    final unit = selectedUnit?.trim() ?? 'Units';

    if (tool.isNotEmpty && qty.isNotEmpty && (int.tryParse(qty) ?? 0) > 0) {
      // Find matching tool doc
      final toolDoc = toolDocs.firstWhere(
        (t) => (t['toolName'] ?? '').toString().trim() == tool,
        orElse: () => {},
      );

      setState(() {
        addedTools.add({
          "tool": tool,
          "toolName": tool,
          "toolCode": code.isNotEmpty ? code : (toolDoc['toolCode'] ?? ''),
          "toolId": toolDoc['toolId'] ?? '',
          "quantity": qty,
          "toolCount": int.tryParse(qty) ?? 1,
          "unit": unit,
          "priority": selectedPriority,
          "expectedReturnDate": returnDate != null
              ? DateFormat('yyyy-MM-dd').format(returnDate!)
              : null,
        });

        // Reset tool entry fields
        selectedTool = null;
        toolCodeController.clear();
        quantityController.text = '1';
        selectedPriority = 'Immediate';
        returnDate = null;
      });

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('$tool added to request.')),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select equipment and enter a valid quantity.'),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _removeTool(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      addedTools.removeAt(index);
    });
  }

  void _sendForApproval() {
    if (addedTools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Please add at least one tool before submitting.'),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    _submitToolRequest();
  }

  Future<void> _submitToolRequest() async {
    setState(() => isSubmitting = true);
    try {
      final siteId = siteIdController.text.trim();
      final projectName = projectController.text.trim();
      final supervisorName = supervisorNameController.text.trim();
      final now = DateTime.now();
      final formattedDate =
          '${DateFormat('MMMM d, yyyy at h:mm:ss a').format(now)} UTC${now.timeZoneOffset.isNegative ? '-' : '+'}${now.timeZoneOffset.inHours.abs()}:${(now.timeZoneOffset.inMinutes % 60).toString().padLeft(2, '0')}';

      final reqCollection = FirestoreService.getCollection('siteToolsRequest');
      final querySnapshot = await reqCollection
          .orderBy('toolReqId', descending: true)
          .limit(1)
          .get();

      String toolReqId = "TR001";
      if (querySnapshot.docs.isNotEmpty) {
        final lastId =
            querySnapshot.docs.first.data()['toolReqId']?.toString() ?? "TR000";
        final numPart =
            int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        toolReqId = "TR${(numPart + 1).toString().padLeft(3, '0')}";
      }

      final List<Map<String, dynamic>> tools = addedTools
          .map(
            (t) => {
              "toolName": t['toolName'] ?? t['tool'],
              "name": t['toolName'] ?? t['tool'],
              "toolCode": t['toolCode'] ?? '',
              "toolId": t['toolId'] ?? '',
              "toolCount": int.tryParse(t['quantity'].toString()) ?? 1,
              "quantity": int.tryParse(t['quantity'].toString()) ?? 1,
              "count": int.tryParse(t['quantity'].toString()) ?? 1,
              "unit": t['unit'] ?? 'Units',
              "priority": t['priority'] ?? 'Immediate',
              if (t['expectedReturnDate'] != null)
                "expectedReturnDate": t['expectedReturnDate'],
            },
          )
          .toList();

      final data = {
        "toolReqId": toolReqId,
        "date": formattedDate,
        "siteId": siteId,
        "projectName": projectName,
        "projectStage": projectStageController.text.trim(),
        "supervisorName": supervisorName,
        "supervisorId": widget.supervisorId,
        "toolName": tools.isNotEmpty ? tools.first['toolName'] : '',
        "tools": tools,
      };

      String datePart;
      if (selectedDate != null) {
        datePart = DateFormat('yyyyMMdd').format(selectedDate!);
      } else {
        datePart = DateFormat('yyyyMMdd').format(DateTime.now());
      }
      final docId = "${siteId}_$datePart";

      await ApprovalWorkflowService.submitRequest(
        collectionName: 'siteToolsRequest',
        docId: docId,
        baseData: data,
        supervisorName: supervisorName,
        supervisorId: widget.supervisorId,
        initialRemarks:
            'Requisition for ${tools.length} equipment items for $projectName ($siteId)',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              const Text('Request Submitted',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Tool Request $toolReqId has been successfully submitted to Manager for review.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onRequestSubmitted != null) {
                  widget.onRequestSubmitted!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit request: $e"),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Tool Request Form',
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
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: isLoadingSupervisorData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading assigned site details...',
                        style: TextStyle(
                          color: darkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card Banner
                      _buildHeaderBanner(darkAccent),
                      const SizedBox(height: 16),

                      // Section 1: Site & Project Details Card
                      _buildSiteDetailsCard(darkAccent),
                      const SizedBox(height: 16),

                      // Section 2: Tool Entry Card
                      _buildToolEntryCard(darkAccent),
                      const SizedBox(height: 16),

                      // Section 3: Added Tools List Card
                      _buildAddedToolsListCard(darkAccent),
                      const SizedBox(height: 24),

                      // Final Submit & Cancel Buttons
                      _buildActionButtons(darkAccent),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Modern Header Banner Card
  Widget _buildHeaderBanner(Color darkAccent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkAccent,
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.construction_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tool & Equipment Requisition',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Request machinery, tools & equipment for site works',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1: Site & Project Details
  Widget _buildSiteDetailsCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.domain_rounded,
            iconColor: primaryColor,
            title: 'Site & Project Information',
          ),
          const SizedBox(height: 14),
          if (supervisorError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      supervisorError!,
                      style: TextStyle(color: errorColor, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),

          // Site Dropdown Select
          _buildFormDropdown<String>(
            label: "Assigned Site ID",
            icon: Icons.location_on_rounded,
            value: selectedSite,
            items: siteDropdownItems,
            onChanged: (value) {
              setState(() {
                selectedSite = value;
                siteIdController.text = value ?? '';
                final map = siteMappings.firstWhere(
                  (m) => m['site'] == value,
                  orElse: () => {},
                );
                projectController.text = map['projectName']?.toString() ?? '';
                projectStageController.text =
                    map['projectStage']?.toString() ?? '';
                supervisorNameController.text =
                    map['supervisor']?.toString() ?? widget.supervisorName;
              });
            },
          ),
          const SizedBox(height: 12),

          // Readonly Details Fields
          _buildFormTextField(
            label: "Supervisor Name",
            icon: Icons.person_rounded,
            controller: supervisorNameController,
            enabled: false,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildFormTextField(
                  label: "Project",
                  icon: Icons.apartment_rounded,
                  controller: projectController,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormTextField(
                  label: "Stage",
                  icon: Icons.engineering_rounded,
                  controller: projectStageController,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Picker
          _buildDateField(),
        ],
      ),
    );
  }

  /// Card 2: Required Tools Section
  Widget _buildToolEntryCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardTitle(
                icon: Icons.construction_rounded,
                iconColor: primaryColor,
                title: 'Equipment & Tool Details',
              ),
              const Spacer(),
              if (_isLoadingToolsList)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${toolDescriptions.length} In Catalog',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Required Tool Dropdown
          _buildFormDropdown<String>(
            label: "Select Equipment / Tool",
            hint: _isLoadingToolsList ? "Loading tools..." : "Choose tool",
            icon: Icons.handyman_rounded,
            value: selectedTool,
            items: toolDescriptions,
            onChanged: _onToolChanged,
          ),
          const SizedBox(height: 12),

          // Tool Code & Quantity Row
          Row(
            children: [
              Expanded(
                child: _buildFormTextField(
                  label: "Tool Code",
                  icon: Icons.qr_code_rounded,
                  controller: toolCodeController,
                  hint: "e.g. TL001",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormTextField(
                  label: "Quantity",
                  icon: Icons.numbers_rounded,
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unit & Priority Row
          Row(
            children: [
              Expanded(
                child: _buildFormDropdown<String>(
                  label: "Unit",
                  icon: Icons.square_foot_rounded,
                  value: selectedUnit,
                  items: unitDropdownItems,
                  onChanged: (value) => setState(() => selectedUnit = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormDropdown<String>(
                  label: "Priority Level",
                  icon: Icons.priority_high_rounded,
                  value: selectedPriority,
                  items: const ['Immediate', 'In 2 days', 'Standard'],
                  onChanged: (value) => setState(() => selectedPriority = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Expected Return Date Picker (Optional)
          _buildReturnDateField(),
          const SizedBox(height: 16),

          // Add Tool Button (Branded)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addTool,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                "Add Tool to Request",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: primaryColor.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: Added Tools List Card
  Widget _buildAddedToolsListCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardTitle(
                icon: Icons.checklist_rounded,
                iconColor: primaryColor,
                title: 'Requested Equipment Items',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${addedTools.length} Items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (addedTools.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.construction_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No tools added yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use the form above to add equipment to your request.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addedTools.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = addedTools[index];
                final String toolName = item['toolName'] ?? item['tool'] ?? '';
                final String code = item['toolCode'] ?? '';
                final String qty = item['quantity'] ?? '1';
                final String unit = item['unit'] ?? 'Units';
                final String priority = item['priority'] ?? 'Immediate';
                final String? retDate = item['expectedReturnDate'];
                final isImmediate = priority == 'Immediate';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isImmediate
                          ? errorColor.withValues(alpha: 0.2)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isImmediate
                              ? errorColor.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.construction_rounded,
                          size: 18,
                          color: isImmediate ? errorColor : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qty: $qty $unit ${code.isNotEmpty ? '• Code: $code' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (retDate != null)
                              Text(
                                'Return by: $retDate',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0284C7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isImmediate
                              ? errorColor.withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isImmediate
                                ? errorColor
                                : const Color(0xFF059669),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: errorColor,
                          size: 20,
                        ),
                        onPressed: () => _removeTool(index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Action Buttons (Cancel & Submit)
  Widget _buildActionButtons(Color darkAccent) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (widget.onCancel != null) {
                widget.onCancel!();
              } else {
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _sendForApproval,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: primaryColor.withValues(alpha: 0.35),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Submit",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Required Date",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  selectedDate != null
                      ? DateFormat('EEE, MMM d, yyyy').format(selectedDate!)
                      : 'Select Date',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnDateField() {
    return InkWell(
      onTap: _pickReturnDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFFD97706)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Expected Return Date (Optional)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  returnDate != null
                      ? DateFormat('EEE, MMM d, yyyy').format(returnDate!)
                      : 'Not Specified (Indefinite / Permanent)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: returnDate != null
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (returnDate != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                onPressed: () => setState(() => returnDate = null),
              )
            else
              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildFormTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hint,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: (value != null && items.contains(value)) ? value : null,
              hint: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    hint ?? "Select $label",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Alias for ToolRequestForm
typedef ToolRequestPage = ToolRequestForm;
