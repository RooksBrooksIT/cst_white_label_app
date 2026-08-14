import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_button.dart';
import 'package:demo_cst/utils/responsive.dart';

class ProjectScreen extends StatefulWidget {
  final String? projectId;
  final bool hideAppBar;
  const ProjectScreen({super.key, this.projectId, this.hideAppBar = false});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  final _mainFormKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _amountSpentController = TextEditingController();
  final TextEditingController _balanceAmountController =
      TextEditingController();
  TabController? _tabController;
  final TextEditingController _projectBudgetController =
      TextEditingController();
  final TextEditingController _updateSiteIdController = TextEditingController();
  final TextEditingController _contractorNameController =
      TextEditingController();
  final TextEditingController _contractorBudgetController =
      TextEditingController();

  bool _isContractWork = false;

  String? projectCategory;
  String? projectSubCategory;
  String? projectContract;
  String? projectStage;
  String? currentStatus;
  DateTime? plannedStartDate;
  DateTime? plannedEndDate;
  DateTime? actualStartDate;
  DateTime? actualEndDate;

  // Newly added fields for contract start and end dates
  DateTime? contractStartDate;
  DateTime? contractEndDate;

  String? _updateAppBarSiteId;
  List<String> _unassignedSiteIds = [];
  String? _selectedSiteId;

  bool isUpdateMode = false;
  Map<String, dynamic>? selectedProjectData;
  String? selectedProjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAmountListeners();
    _fetchUnassignedSiteIds();
    _syncExpensesForAllProjects();
  }

  Future<void> _fetchUnassignedSiteIds() async {
    final sitesSnapshot = await FirestoreService.getCollection('Site').get();
    final allSiteIds = sitesSnapshot.docs
        .map((doc) => doc.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    final siteSupervisorSnapshot = await FirestoreService.getCollection(
      'siteSupervisorMap',
    ).get();
    final assignedSiteIds = siteSupervisorSnapshot.docs
        .map((doc) => (doc.data())['site'])
        .where((id) => id != null && id.toString().isNotEmpty)
        .map((id) => id.toString())
        .toSet();

    final unassigned = allSiteIds.difference(assignedSiteIds).toList();

    final projectsSnapshot = await FirestoreService.getCollection(
      'projects',
    ).get();
    final Map<String, Map<String, dynamic>> projectsBySiteId = {};
    for (var doc in projectsSnapshot.docs) {
      final data = doc.data();
      final sid = data['siteId']?.toString();
      if (sid != null && sid.isNotEmpty) {
        projectsBySiteId[sid] = data;
      }
    }

    final filtered = unassigned.where((sid) {
      final data = projectsBySiteId[sid];
      if (data == null) return true;
      return !_projectHasAllDetails(data);
    }).toList();

    if (!mounted) return;

    setState(() {
      _unassignedSiteIds = filtered;
      _selectedSiteId = _unassignedSiteIds.isNotEmpty
          ? _unassignedSiteIds[0]
          : null;
    });

    if (_selectedSiteId != null) {
      await _loadPlannedDatesForSite(_selectedSiteId);
    }
  }

  Future<void> _syncExpensesForAllProjects() async {
    final projectsSnapshot = await FirestoreService.getCollection(
      'projects',
    ).get();
    for (var doc in projectsSnapshot.docs) {
      final siteId = doc.data()['siteId'];
      if (siteId != null) {
        final expenseSnapshot = await FirestoreService.getCollection(
          'totalSiteExpensesPerDay',
        ).doc(siteId).get();
        if (expenseSnapshot.exists) {
          final data = expenseSnapshot.data()!;
          final totalMgrExpense = (data['totalMgrExpense'] ?? 0).toDouble();
          final totalOrgExpense = (data['totalOrgExpense'] ?? 0).toDouble();
          final totalSiteExpense = (data['totalSiteExpense'] ?? 0).toDouble();
          final totalIncentiveExpenses = (data['totalIncentiveExpenses'] ?? 0)
              .toDouble();
          final totalContractorExpense = (data['totalContractorExpense'] ?? 0)
              .toDouble();
          final amountSpent =
              totalMgrExpense +
              totalOrgExpense +
              totalSiteExpense +
              totalIncentiveExpenses +
              totalContractorExpense;
          final amountPaid = (doc.data()['amountPaid'] ?? 0).toDouble();
          final balanceAmount = amountPaid - amountSpent;
          await FirestoreService.getCollection('projects').doc(doc.id).update({
            'amountSpent': amountSpent,
            'amountBalance': balanceAmount,
          });
        }
      }
    }
  }

  String formatDate(DateTime? date) {
    return date == null ? 'Select date' : DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime) onSelected,
  ) async {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  void _resetForm() {
    _projectNameController.clear();
    _ownerNameController.clear();
    _ownerPhoneController.clear();
    _amountPaidController.clear();
    _amountSpentController.clear();
    _balanceAmountController.clear();
    _projectBudgetController.clear();
    _updateSiteIdController.clear();
    _contractorNameController.clear();
    _contractorBudgetController.clear();
    setState(() {
      projectCategory = null;
      projectSubCategory = null;
      projectContract = null;
      projectStage = null;
      currentStatus = null;
      plannedStartDate = null;
      plannedEndDate = null;
      actualStartDate = null;
      actualEndDate = null;
      contractStartDate = null;
      contractEndDate = null;

      _isContractWork = false;

      selectedProjectId = null;
      selectedProjectData = null;
      _updateAppBarSiteId = null;
    });
  }

  void _setupAmountListeners() {
    _amountPaidController.addListener(_calculateBalance);
    _amountSpentController.addListener(_calculateBalance);
  }

  void _calculateBalance() {
    final paid = double.tryParse(_amountPaidController.text) ?? 0;
    final spent = double.tryParse(_amountSpentController.text) ?? 0;
    final balance = paid - spent;
    _balanceAmountController.text = balance.toStringAsFixed(2);
  }

  bool _projectHasAllDetails(Map<String, dynamic> data) {
    return (data['projectName'] != null &&
            data['projectName'].toString().isNotEmpty) &&
        (data['ownerName'] != null &&
            data['ownerName'].toString().isNotEmpty) &&
        (data['ownerPhoneNumber'] != null &&
            data['ownerPhoneNumber'].toString().isNotEmpty) &&
        (data['projectCategory'] != null &&
            data['projectCategory'].toString().isNotEmpty) &&
        (data['projectSubCategory'] != null &&
            data['projectSubCategory'].toString().isNotEmpty) &&
        (data['projectContract'] != null &&
            data['projectContract'].toString().isNotEmpty) &&
        (data['projectStage'] != null &&
            data['projectStage'].toString().isNotEmpty) &&
        (data['currentStatus'] != null || data['status'] != null) &&
        data['plannedStartDate'] != null &&
        data['plannedEndDate'] != null &&
        data['actualStateDate'] != null &&
        data['actualEndDate'] != null &&
        (data['projectBudget'] != null) &&
        (data['amountPaid'] != null);
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _amountPaidController.dispose();
    _amountSpentController.dispose();
    _balanceAmountController.dispose();
    _projectBudgetController.dispose();
    _updateSiteIdController.dispose();
    _contractorNameController.dispose();
    _contractorBudgetController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_mainFormKey.currentState!.validate()) {
      return;
    }
    if (plannedStartDate == null ||
        plannedEndDate == null ||
        actualStartDate == null ||
        actualEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all timeline dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isContractWork &&
        (contractStartDate == null || contractEndDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Contract Start and End dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final double budget =
          double.tryParse(_projectBudgetController.text) ?? 0.0;
      final double paid = double.tryParse(_amountPaidController.text) ?? 0.0;
      final double spent = double.tryParse(_amountSpentController.text) ?? 0.0;
      final double balance = paid - spent;

      final Map<String, dynamic> projectData = {
        'projectName': _projectNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhoneNumber': _ownerPhoneController.text.trim(),
        'projectCategory': projectCategory,
        'projectSubCategory': projectSubCategory,
        'projectContract': projectContract,
        'projectStage': projectStage,
        'currentStatus': currentStatus,
        'status': currentStatus,
        'plannedStartDate': plannedStartDate,
        'plannedEndDate': plannedEndDate,
        'actualStateDate': actualStartDate,
        'actualEndDate': actualEndDate,
        'projectBudget': budget,
        'amountPaid': paid,
        'amountSpent': spent,
        'amountBalance': balance,
        'isContractWork': _isContractWork,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isContractWork) {
        projectData['contractorName'] = _contractorNameController.text.trim();
        projectData['contractorBudget'] =
            double.tryParse(_contractorBudgetController.text) ?? 0.0;
        projectData['contractStartDate'] = contractStartDate;
        projectData['contractEndDate'] = contractEndDate;
      }

      if (!isUpdateMode) {
        if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a Site ID'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        projectData['siteId'] = _selectedSiteId;
        projectData['createdAt'] = FieldValue.serverTimestamp();

        final query = await FirestoreService.getCollection('projects')
            .where('siteId', isEqualTo: _selectedSiteId)
            .get();

        if (query.docs.isNotEmpty) {
          final docId = query.docs.first.id;
          await FirestoreService.getCollection('projects').doc(docId).update(
                projectData,
              );
        } else {
          await FirestoreService.getCollection('projects').add(projectData);
        }
      } else {
        if (selectedProjectId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a project to update'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        await FirestoreService.getCollection('projects').doc(selectedProjectId).update(
              projectData,
            );
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => _buildSuccessModal(context),
      );
      _resetForm();
      await _fetchUnassignedSiteIds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving project: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadPlannedDatesForSite(String? siteId) async {
    if (siteId == null || siteId.isEmpty) {
      setState(() {
        plannedStartDate = null;
        plannedEndDate = null;
        projectCategory = null;
        currentStatus = null;
      });
      return;
    }
    try {
      final snapshot = await FirestoreService.getCollection(
        'projects',
      ).where('siteId', isEqualTo: siteId).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          plannedStartDate = data['plannedStartDate'] != null
              ? (data['plannedStartDate'] as Timestamp).toDate()
              : null;
          plannedEndDate = data['plannedEndDate'] != null
              ? (data['plannedEndDate'] as Timestamp).toDate()
              : null;
          final cat = data['projectCategory']?.toString().trim();
          projectCategory = (cat != null && cat.isNotEmpty) ? cat : null;
          final status = (data['currentStatus'] ?? data['status'])
              ?.toString()
              .trim();
          currentStatus = (status != null && status.isNotEmpty) ? status : null;
        });
      } else {
        setState(() {
          plannedStartDate = null;
          plannedEndDate = null;
          projectCategory = null;
          currentStatus = null;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final Color darkCardBg = AppTheme.getDarkAccent(primaryColor);
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──────────────────────────────────────────────────
            if (!widget.hideAppBar)
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
                      'Project Configuration',
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
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isUpdateMode) {
                          setState(() {
                            isUpdateMode = false;
                            _resetForm();
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isUpdateMode
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'NEW PROJECT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: !isUpdateMode
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isUpdateMode) {
                          setState(() {
                            isUpdateMode = true;
                            _resetForm();
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isUpdateMode
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'UPDATE PROJECT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isUpdateMode
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Form Body ───────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── NEW PROJECT BASIC CARD ────────────────────────
                        if (!isUpdateMode) ...[
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
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E88E5),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1E88E5)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_business_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'New Project',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Enter project details & owner information',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                _buildTextFormField(
                                  context,
                                  controller: _projectNameController,
                                  label: 'Project Name',
                                  icon: Icons.title_rounded,
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                _buildTextFormField(
                                  context,
                                  controller: _ownerNameController,
                                  label: 'Owner Name',
                                  icon: Icons.person_outline_rounded,
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                _buildTextFormField(
                                  context,
                                  controller: _ownerPhoneController,
                                  label: 'Owner Phone Number',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty)
                                      return 'Required';
                                    if (val.trim().length != 10)
                                      return 'Must be 10 digits';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Customer Login Info Note
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryColor
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_person_outlined,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Customer Login Info',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            const Text(
                                              'The Owner Name and Phone Number will be used as the username and password for Customer Login.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFCBD5E1),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  context,
                                  value: _selectedSiteId,
                                  label: 'Site Id',
                                  items: _unassignedSiteIds,
                                  icon: Icons.location_on_rounded,
                                  onChanged: (val) async {
                                    setState(() {
                                      _selectedSiteId = val;
                                    });
                                    await _loadPlannedDatesForSite(val);
                                  },
                                  validator: (val) =>
                                      val == null || val.isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                                if (_unassignedSiteIds.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'No sites found in the organisation.',
                                    style: TextStyle(
                                      color: Colors.orange[300],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── IS CONTRACT WORK CHECKBOX ─────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: CheckboxListTile(
                              value: _isContractWork,
                              onChanged: (val) {
                                setState(() {
                                  _isContractWork = val ?? false;
                                  if (!_isContractWork) {
                                    contractStartDate = null;
                                    contractEndDate = null;
                                  }
                                });
                              },
                              title: const Text(
                                'Is Contract Work',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              activeColor: primaryColor,
                              checkColor: const Color(0xFF0A183D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── MAIN FORM ──────────────────────────────────────
                        Form(
                          key: _mainFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── SELECT PROJECT (Update Mode) ───────────
                              if (isUpdateMode) ...[
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: darkCardBg,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: darkCardBg
                                            .withValues(alpha: 0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select Project',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirestoreService.getCollection(
                                          'projects',
                                        ).snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(primaryColor),
                                              ),
                                            );
                                          }
                                          final projects = snapshot.data!.docs;
                                          if (projects.isEmpty) {
                                            return const Text(
                                              'No projects found',
                                              style: TextStyle(
                                                  color: Color(0xFFCBD5E1)),
                                            );
                                          }

                                          final projectItems = projects
                                              .where((doc) {
                                                final data = doc.data()
                                                    as Map<String, dynamic>;
                                                final name =
                                                    (data['projectName'] ?? '')
                                                        .toString();
                                                return name.trim().isNotEmpty;
                                              })
                                              .map((doc) {
                                                final data = doc.data()
                                                    as Map<String, dynamic>;
                                                final name =
                                                    data['projectName'] ?? '';
                                                final location =
                                                    data['ownerName'] ?? '';
                                                return {
                                                  'id': doc.id,
                                                  'label':
                                                      '$name (${location.toString()})',
                                                };
                                              })
                                              .toList();

                                          final itemLabels = projectItems
                                              .map((e) => e['label'] as String)
                                              .toList();
                                          final selectedItem =
                                              projectItems.firstWhere(
                                            (e) => e['id'] == selectedProjectId,
                                            orElse: () => {'label': ''},
                                          );
                                          final selectedLabel =
                                              selectedItem['label'] as String;

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildDropdownField(
                                                context,
                                                value: selectedLabel.isNotEmpty
                                                    ? selectedLabel
                                                    : null,
                                                label: 'Select Project to Update',
                                                items: itemLabels,
                                                icon: Icons.location_city_rounded,
                                                onChanged: (val) async {
                                                  final match =
                                                      projectItems.firstWhere(
                                                    (e) => e['label'] == val,
                                                    orElse: () => {'id': ''},
                                                  );
                                                  final value =
                                                      match['id'] as String;
                                                  if (value.isEmpty) return;

                                                  final selectedDoc = projects
                                                      .firstWhere(
                                                    (doc) => doc.id == value,
                                                  );
                                                  final data = selectedDoc.data()
                                                      as Map<String, dynamic>;
                                                  setState(() {
                                                    selectedProjectId =
                                                        selectedDoc.id;
                                                    selectedProjectData =
                                                        Map<String, dynamic>.from(
                                                      data,
                                                    );
                                                    _projectNameController.text =
                                                        data['projectName'] ??
                                                            '';
                                                    _ownerNameController.text =
                                                        data['ownerName'] ?? '';
                                                    _ownerPhoneController.text =
                                                        data['ownerPhoneNumber'] ??
                                                            '';
                                                    _amountPaidController.text =
                                                        (data['amountPaid'] ??
                                                                '')
                                                            .toString();
                                                    _projectBudgetController
                                                        .text = (data[
                                                                'projectBudget'] ??
                                                            '')
                                                        .toString();
                                                    projectCategory =
                                                        data.containsKey(
                                                      'projectCategory',
                                                    )
                                                            ? data[
                                                                'projectCategory']
                                                            : null;
                                                    projectSubCategory =
                                                        data.containsKey(
                                                      'projectSubCategory',
                                                    )
                                                            ? data[
                                                                'projectSubCategory']
                                                            : null;
                                                    projectContract =
                                                        data.containsKey(
                                                      'projectContract',
                                                    )
                                                            ? data[
                                                                'projectContract']
                                                            : null;
                                                    projectStage =
                                                        data.containsKey(
                                                      'projectStage',
                                                    )
                                                            ? data[
                                                                'projectStage']
                                                            : null;
                                                    _isContractWork =
                                                        data.containsKey(
                                                      'isContractWork',
                                                    )
                                                            ? (data['isContractWork'] ==
                                                                true)
                                                            : false;
                                                    _contractorNameController
                                                            .text =
                                                        data.containsKey(
                                                                    'contractorName') &&
                                                                data['contractorName'] !=
                                                                    null
                                                            ? data[
                                                                    'contractorName']
                                                                .toString()
                                                            : '';
                                                    _contractorBudgetController
                                                            .text =
                                                        data.containsKey(
                                                                    'contractorBudget') &&
                                                                data['contractorBudget'] !=
                                                                    null
                                                            ? data[
                                                                    'contractorBudget']
                                                                .toString()
                                                            : '';
                                                    currentStatus =
                                                        data['currentStatus'] ??
                                                            data['status'] ??
                                                            null;
                                                    plannedStartDate =
                                                        data['plannedStartDate'] !=
                                                                null
                                                            ? (data['plannedStartDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    plannedEndDate =
                                                        data['plannedEndDate'] !=
                                                                null
                                                            ? (data['plannedEndDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    actualStartDate =
                                                        data['actualStateDate'] !=
                                                                null
                                                            ? (data['actualStateDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    actualEndDate =
                                                        data['actualEndDate'] !=
                                                                null
                                                            ? (data['actualEndDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    contractStartDate =
                                                        data['contractStartDate'] !=
                                                                null
                                                            ? (data['contractStartDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    contractEndDate =
                                                        data['contractEndDate'] !=
                                                                null
                                                            ? (data['contractEndDate']
                                                                    as Timestamp)
                                                                .toDate()
                                                            : null;
                                                    _updateSiteIdController
                                                        .text = data.containsKey(
                                                                'siteId') &&
                                                            data['siteId'] !=
                                                                null
                                                        ? data['siteId']
                                                            .toString()
                                                        : '';
                                                    _updateAppBarSiteId =
                                                        data.containsKey(
                                                                    'siteId') &&
                                                                data['siteId'] !=
                                                                    null
                                                            ? data['siteId']
                                                                .toString()
                                                            : '';
                                                  });
                                                  await _fetchAndSetAmountSpentAndBalance(
                                                    data['siteId'],
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 12),
                                              if (selectedProjectId != null)
                                                _buildTextFormField(
                                                  context,
                                                  controller:
                                                      _updateSiteIdController,
                                                  label: 'Site ID',
                                                  icon: Icons
                                                      .location_on_outlined,
                                                  readOnly: true,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ── PROJECT DETAILS CARD ────────────────────
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
                                    const Text(
                                      'Project Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirestoreService.getCollection(
                                        'projectCategories',
                                      ).orderBy('projectCategoryId').snapshots(),
                                      builder: (context, snapshot) {
                                        List<String> fetchedCategories = [];
                                        if (snapshot.hasData) {
                                          fetchedCategories = snapshot.data!.docs
                                              .map(
                                                (doc) => doc['projectCategory']
                                                    as String,
                                              )
                                              .toList();
                                        }
                                        String? dropdownValue =
                                            fetchedCategories.contains(
                                                    projectCategory)
                                                ? projectCategory
                                                : null;
                                        return _buildDropdownField(
                                          context,
                                          value: dropdownValue,
                                          label: 'Project Category',
                                          items: fetchedCategories,
                                          icon: Icons.category_rounded,
                                          onChanged: (value) => setState(
                                              () => projectCategory = value!),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                                  ? 'Required'
                                                  : null,
                                          enabled: !isUpdateMode,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirestoreService.getCollection(
                                        'projectSubCategories',
                                      ).snapshots(),
                                      builder: (context, snapshot) {
                                        List<String> fetchedSubCategories = [];
                                        if (snapshot.hasData) {
                                          fetchedSubCategories = snapshot
                                              .data!.docs
                                              .map(
                                                (doc) =>
                                                    doc['projectSubCategory']
                                                        as String,
                                              )
                                              .toSet()
                                              .toList();
                                        }
                                        String? dropdownValue =
                                            fetchedSubCategories.contains(
                                                    projectSubCategory)
                                                ? projectSubCategory
                                                : null;
                                        return _buildDropdownField(
                                          context,
                                          value: dropdownValue,
                                          label: 'Project Sub Category',
                                          items: fetchedSubCategories,
                                          icon: Icons.account_tree_rounded,
                                          onChanged: (value) => setState(
                                            () => projectSubCategory = value!,
                                          ),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                                  ? 'Required'
                                                  : null,
                                          enabled: !isUpdateMode,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirestoreService.getCollection(
                                        'projectContracts',
                                      ).snapshots(),
                                      builder: (context, snapshot) {
                                        List<String> fetchedContracts = [];
                                        if (snapshot.hasData) {
                                          fetchedContracts = snapshot.data!.docs
                                              .map(
                                                (doc) => doc['projectContract']
                                                    as String,
                                              )
                                              .toSet()
                                              .toList();
                                        }
                                        String? dropdownValue =
                                            fetchedContracts.contains(
                                                    projectContract)
                                                ? projectContract
                                                : null;
                                        return _buildDropdownField(
                                          context,
                                          value: dropdownValue,
                                          label: 'Project Contract',
                                          items: fetchedContracts,
                                          icon: Icons.description_rounded,
                                          onChanged: (value) => setState(
                                              () => projectContract = value!),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                                  ? 'Required'
                                                  : null,
                                          enabled: !isUpdateMode,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirestoreService.getCollection(
                                        'projectStages',
                                      ).snapshots(),
                                      builder: (context, snapshot) {
                                        List<String> fetchedStages = [];
                                        if (snapshot.hasData) {
                                          final docs =
                                              List<QueryDocumentSnapshot>.from(
                                            snapshot.data!.docs,
                                          );
                                          docs.sort((a, b) =>
                                              a.id.compareTo(b.id));
                                          fetchedStages = docs
                                              .map(
                                                (doc) => doc['projectStage']
                                                    as String,
                                              )
                                              .toList();
                                        }
                                        String? dropdownValue =
                                            fetchedStages.contains(projectStage)
                                                ? projectStage
                                                : null;
                                        return _buildDropdownField(
                                          context,
                                          value: dropdownValue,
                                          label: 'Project Stage',
                                          items: fetchedStages,
                                          icon: Icons.flag_rounded,
                                          onChanged: (value) => setState(
                                              () => projectStage = value!),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                                  ? 'Required'
                                                  : null,
                                          enabled: true,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirestoreService.getCollection(
                                        'projectStatus',
                                      ).snapshots(),
                                      builder: (context, snapshot) {
                                        List<String> fetchedStates = [];
                                        if (snapshot.hasData) {
                                          fetchedStates = snapshot.data!.docs
                                              .map(
                                                (doc) => doc['projectState']
                                                    as String,
                                              )
                                              .toList();
                                        }
                                        final defaultStatuses = [
                                          'Not Started',
                                          'Ongoing',
                                          'On Hold',
                                          'Completed',
                                          'Cancelled',
                                        ];
                                        for (var status in defaultStatuses) {
                                          if (!fetchedStates.contains(status)) {
                                            fetchedStates.add(status);
                                          }
                                        }
                                        String? dropdownValue =
                                            fetchedStates.contains(
                                                    currentStatus)
                                                ? currentStatus
                                                : null;
                                        return _buildDropdownField(
                                          context,
                                          value: dropdownValue,
                                          label: 'Current Status',
                                          items: fetchedStates,
                                          icon: Icons.timeline_rounded,
                                          onChanged: (val) => setState(
                                              () => currentStatus = val),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                                  ? 'Required'
                                                  : null,
                                          enabled: true,
                                        );
                                      },
                                    ),

                                    if (_isContractWork) ...[
                                      const SizedBox(height: 14),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirestoreService.getCollection(
                                          'contractors',
                                        ).snapshots(),
                                        builder: (context, snapshot) {
                                          final docs = snapshot.hasData
                                              ? snapshot.data!.docs
                                              : <QueryDocumentSnapshot>[];
                                          final names = docs
                                              .map((d) {
                                                final data = d.data()
                                                    as Map<String, dynamic>;
                                                final n =
                                                    data['contractorName'];
                                                return n == null
                                                    ? ''
                                                    : n.toString().trim();
                                              })
                                              .where((e) => e.isNotEmpty)
                                              .toSet()
                                              .toList();
                                          final String? dropdownValue =
                                              names.contains(
                                            _contractorNameController.text,
                                          )
                                                  ? _contractorNameController.text
                                                  : null;

                                          return Row(
                                            children: [
                                              Expanded(
                                                child: _buildDropdownField(
                                                  context,
                                                  value: dropdownValue,
                                                  label: 'Contractor Name',
                                                  items: names,
                                                  icon: Icons
                                                      .engineering_rounded,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _contractorNameController
                                                          .text = val ?? '';
                                                    });
                                                  },
                                                  validator: (val) =>
                                                      _isContractWork &&
                                                              (val == null ||
                                                                  val.isEmpty)
                                                          ? 'Required'
                                                          : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 24.0),
                                                child: Container(
                                                  width: 46,
                                                  height: 46,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFF1E88E5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    tooltip:
                                                        'Edit Contractor Name',
                                                    onPressed: () async {
                                                      final controller =
                                                          TextEditingController(
                                                        text:
                                                            _contractorNameController
                                                                .text,
                                                      );
                                                      final result =
                                                          await showDialog<
                                                              String>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                            'Edit Contractor Name',
                                                          ),
                                                          content: TextField(
                                                            controller:
                                                                controller,
                                                            decoration:
                                                                const InputDecoration(
                                                              hintText:
                                                                  'Enter contractor name',
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context),
                                                              child: const Text(
                                                                  'Cancel'),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                context,
                                                                controller.text,
                                                              ),
                                                              child: const Text(
                                                                  'OK'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (result != null &&
                                                          result
                                                              .trim()
                                                              .isNotEmpty) {
                                                        setState(() {
                                                          _contractorNameController
                                                                  .text =
                                                              result.trim();
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextFormField(
                                        context,
                                        controller:
                                            _contractorBudgetController,
                                        label: 'Contractor Budget',
                                        icon: Icons.currency_rupee_rounded,
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (!_isContractWork) return null;
                                          if (val == null || val.trim().isEmpty)
                                            return 'Required';
                                          final budget = double.tryParse(val);
                                          if (budget == null)
                                            return 'Invalid number';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildDatePicker(
                                        context,
                                        "Contract Start Date",
                                        contractStartDate,
                                        (date) => setState(
                                            () => contractStartDate = date),
                                        validator: (val) =>
                                            contractStartDate == null
                                                ? 'Required'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildDatePicker(
                                        context,
                                        "Contract End Date",
                                        contractEndDate,
                                        (date) => setState(
                                            () => contractEndDate = date),
                                        validator: (val) =>
                                            contractEndDate == null
                                                ? 'Required'
                                                : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── PROJECT TIMELINE CARD ──────────────────
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
                                    const Text(
                                      'Project Timeline',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildDatePicker(
                                      context,
                                      "Planned Start Date",
                                      plannedStartDate,
                                      (date) => setState(
                                          () => plannedStartDate = date),
                                      validator: (val) =>
                                          plannedStartDate == null
                                              ? 'Required'
                                              : null,
                                      enabled: isUpdateMode,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildDatePicker(
                                      context,
                                      "Planned End Date",
                                      plannedEndDate,
                                      (date) =>
                                          setState(() => plannedEndDate = date),
                                      validator: (val) => plannedEndDate == null
                                          ? 'Required'
                                          : null,
                                      enabled: isUpdateMode,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildDatePicker(
                                      context,
                                      "Actual Start Date",
                                      actualStartDate,
                                      (date) => setState(
                                          () => actualStartDate = date),
                                      validator: (val) =>
                                          actualStartDate == null
                                              ? 'Required'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildDatePicker(
                                      context,
                                      "Actual End Date",
                                      actualEndDate,
                                      (date) =>
                                          setState(() => actualEndDate = date),
                                      validator: (val) => actualEndDate == null
                                          ? 'Required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── FINANCIAL DETAILS CARD ─────────────────
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
                                    const Text(
                                      'Financial Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildTextFormField(
                                      context,
                                      controller: _projectBudgetController,
                                      label: 'Project Budget',
                                      icon: Icons.currency_rupee_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty)
                                          return 'Required';
                                        final budget = double.tryParse(val);
                                        final paid = double.tryParse(
                                          _amountPaidController.text,
                                        );
                                        if (budget == null)
                                          return 'Invalid number';
                                        if (paid != null && budget < paid)
                                          return 'Budget must be greater than Amount Received';
                                        return null;
                                      },
                                      readOnly: isUpdateMode,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextFormField(
                                      context,
                                      controller: _amountPaidController,
                                      label: 'Amount Received',
                                      icon: Icons.currency_rupee_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? 'Required'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextFormField(
                                      context,
                                      controller: _amountSpentController,
                                      label: 'Amount Spent',
                                      icon: Icons.currency_rupee_rounded,
                                      keyboardType: TextInputType.number,
                                      readOnly: true,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextFormField(
                                      context,
                                      controller: _balanceAmountController,
                                      label: 'Balance Amount',
                                      icon: Icons.account_balance_wallet_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? 'Required'
                                              : null,
                                      readOnly: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── ACTION BUTTONS ─────────────────────────
                              _buildActionButtons(context),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAndSetAmountSpentAndBalance(String? siteId) async {
    if (siteId == null || siteId.isEmpty) {
      _amountSpentController.text = '';
      _balanceAmountController.text = '';
      return;
    }
    final expenseSnapshot = await FirestoreService.getCollection(
      'totalSiteExpensesPerDay',
    ).doc(siteId).get();
    if (expenseSnapshot.exists) {
      final data = expenseSnapshot.data()!;
      final totalMgrExpense = (data['totalMgrExpense'] ?? 0).toDouble();
      final totalOrgExpense = (data['totalOrgExpense'] ?? 0).toDouble();
      final totalSiteExpense = (data['totalSiteExpense'] ?? 0).toDouble();
      final totalIncentiveExpenses = (data['totalIncentiveExpenses'] ?? 0)
          .toDouble();
      final totalContractorExpense = (data['totalContractorExpense'] ?? 0)
          .toDouble();
      final amountSpent =
          totalMgrExpense +
          totalOrgExpense +
          totalSiteExpense +
          totalIncentiveExpenses +
          totalContractorExpense;
      _amountSpentController.text = amountSpent.toStringAsFixed(2);
      final paid = double.tryParse(_amountPaidController.text) ?? 0;
      final balance = paid - amountSpent;
      _balanceAmountController.text = balance.toStringAsFixed(2);
    } else {
      _amountSpentController.text = '0.00';
      final paid = double.tryParse(_amountPaidController.text) ?? 0;
      _balanceAmountController.text = paid.toStringAsFixed(2);
    }
  }

  Widget _buildTextFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
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
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(icon, color: brandIconColor, size: 22),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: "",
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String? value,
    required String label,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    final uniqueItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

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
            color: enabled ? Colors.white : const Color(0xFFF1F5F9),
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
            value: (value != null && uniqueItems.contains(value.trim()))
                ? value.trim()
                : null,
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
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(icon, color: brandIconColor, size: 22),
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
            items: uniqueItems.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    DateTime? initialDate,
    Function(DateTime) onSelected, {
    String? Function(DateTime?)? validator,
    bool enabled = true,
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
        InkWell(
          onTap: enabled
              ? () => _selectDate(context, initialDate, onSelected)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF1F5F9),
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
                    formatDate(initialDate),
                    style: TextStyle(
                      color: initialDate == null
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

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saveForm,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isUpdateMode ? Icons.check_rounded : Icons.save_rounded,
                    size: 20,
                    color: const Color(0xFF0A183D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUpdateMode ? 'UPDATE PROJECT' : 'SAVE PROJECT',
                    style: const TextStyle(
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
            onPressed: _resetForm,
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
    );
  }

  Widget _buildSuccessModal(BuildContext context) {
    const successColor = Color(0xFF28a745);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_circle, color: successColor, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Success!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Project has been saved successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
