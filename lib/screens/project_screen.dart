import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ProjectScreen extends StatefulWidget {
  final String? projectId;
  const ProjectScreen({super.key, this.projectId});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _mainFormKey = GlobalKey<FormState>();

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _amountSpentController = TextEditingController();
  final TextEditingController _balanceAmountController =
      TextEditingController();
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
  DateTime? contractStartDate;
  DateTime? contractEndDate;

  List<String> _unassignedSiteIds = [];
  String? _selectedSiteId;
  bool isUpdateMode = false;
  Map<String, dynamic>? selectedProjectData;
  String? selectedProjectId;

  final Color purple = const Color(0xFF9C27B0);
  final Color bgColor = const Color(
    0xFFF1F5F9,
  ); // More visible gray (Slate 100)
  final Color borderColor = const Color.fromARGB(255, 169, 172, 175);
  final Color textColor = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _setupAmountListeners();
    _fetchUnassignedSiteIds();
    _syncExpensesForAllProjects();

    if (widget.projectId != null) {
      isUpdateMode = true;
      selectedProjectId = widget.projectId;
      _loadProjectData(widget.projectId!);
    }
  }

  void _setupAmountListeners() {
    _amountPaidController.addListener(_updateBalanceAmount);
    _amountSpentController.addListener(_updateBalanceAmount);
  }

  void _updateBalanceAmount() {
    final paid = double.tryParse(_amountPaidController.text) ?? 0;
    final spent = double.tryParse(_amountSpentController.text) ?? 0;
    _balanceAmountController.text = (paid - spent).toStringAsFixed(2);
  }

  Future<void> _fetchUnassignedSiteIds() async {
    try {
      final siteSnapshot = await FirestoreService.sites.get();
      final allSiteIds = siteSnapshot.docs.map((doc) => doc.id).toSet();

      final assignedSnapshot = await FirestoreService.siteSupervisorMap.get();
      final assignedSiteIds = assignedSnapshot.docs
          .map((doc) => doc.data()['site']?.toString())
          .whereType<String>()
          .toSet();

      final unassigned = allSiteIds.difference(assignedSiteIds).toList();

      setState(() {
        _unassignedSiteIds = unassigned;
        if (_unassignedSiteIds.isNotEmpty &&
            _selectedSiteId == null &&
            !isUpdateMode) {
          _selectedSiteId = _unassignedSiteIds.first;
          _loadPlannedDatesForSite(_selectedSiteId);
        }
      });
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
  }

  Future<void> _syncExpensesForAllProjects() async {
    try {
      final projectsSnapshot = await FirestoreService.projects.get();
      for (var doc in projectsSnapshot.docs) {
        final siteId = doc.data()['siteId'];
        if (siteId != null) {
          final expenseSnapshot = await FirestoreService.totalSiteExpensesPerDay
              .doc(siteId)
              .get();
          if (expenseSnapshot.exists) {
            final data = expenseSnapshot.data()!;
            final total =
                (data['totalMgrExpense'] ?? 0).toDouble() +
                (data['totalOrgExpense'] ?? 0).toDouble() +
                (data['totalSiteExpense'] ?? 0).toDouble() +
                (data['totalIncentiveExpenses'] ?? 0).toDouble() +
                (data['totalContractorExpense'] ?? 0).toDouble();

            final paid = (doc.data()['amountPaid'] ?? 0).toDouble();
            await FirestoreService.projects.doc(doc.id).update({
              'amountSpent': total,
              'amountBalance': paid - total,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing expenses: $e');
    }
  }

  Future<void> _loadPlannedDatesForSite(String? siteId) async {
    if (siteId == null || siteId.isEmpty) return;
    try {
      final snapshot = await FirestoreService.projects
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          plannedStartDate = data['plannedStartDate'] != null
              ? (data['plannedStartDate'] as Timestamp).toDate()
              : null;
          plannedEndDate = data['plannedEndDate'] != null
              ? (data['plannedEndDate'] as Timestamp).toDate()
              : null;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadProjectData(String projectId) async {
    try {
      final doc = await FirestoreService.projects.doc(projectId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _projectNameController.text = data['projectName'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _amountPaidController.text = (data['amountPaid'] ?? '').toString();
          _projectBudgetController.text = (data['projectBudget'] ?? '')
              .toString();
          projectCategory = data['projectCategory'];
          projectSubCategory = data['projectSubCategory'];
          projectContract = data['projectContract'];
          projectStage = data['projectStage'];
          _isContractWork = data['isContractWork'] == true;
          _contractorNameController.text =
              data['contractorName']?.toString() ?? '';
          _contractorBudgetController.text =
              data['contractorBudget']?.toString() ?? '';
          currentStatus = data['currentStatus'] ?? data['status'];
          plannedStartDate = data['plannedStartDate'] != null
              ? (data['plannedStartDate'] as Timestamp).toDate()
              : null;
          plannedEndDate = data['plannedEndDate'] != null
              ? (data['plannedEndDate'] as Timestamp).toDate()
              : null;
          _selectedSiteId = data['siteId'];
        });
        _fetchAndSetAmountSpentAndBalance(data['siteId']);
      }
    } catch (e) {
      debugPrint('Error loading project: $e');
    }
  }

  void _resetForm() {
    _projectNameController.clear();
    _ownerNameController.clear();
    _amountPaidController.clear();
    _amountSpentController.clear();
    _balanceAmountController.clear();
    _projectBudgetController.clear();
    _contractorNameController.clear();
    _contractorBudgetController.clear();
    setState(() {
      projectCategory = projectSubCategory = projectContract = projectStage =
          currentStatus = null;
      plannedStartDate = plannedEndDate = actualStartDate = actualEndDate =
          contractStartDate = contractEndDate = null;
      _isContractWork = false;
      selectedProjectId = null;
      selectedProjectData = null;
      if (!isUpdateMode) {
        _selectedSiteId = _unassignedSiteIds.isNotEmpty
            ? _unassignedSiteIds.first
            : null;
      }
    });
  }

  Future<String> _generateNextProjectId() async {
    final snapshot = await FirestoreService.projects
        .orderBy(FieldPath.documentId)
        .get();
    int maxNumber = 0;
    for (var doc in snapshot.docs) {
      if (doc.id.startsWith('PR')) {
        final number = int.tryParse(doc.id.substring(2));
        if (number != null && number > maxNumber) maxNumber = number;
      }
    }
    return 'PR${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _saveForm() async {
    if (_mainFormKey.currentState?.validate() != true) return;

    try {
      final data = {
        'projectName': _projectNameController.text,
        'ownerName': _ownerNameController.text,
        'amountPaid': double.tryParse(_amountPaidController.text) ?? 0,
        'projectBudget': double.tryParse(_projectBudgetController.text) ?? 0,
        'projectCategory': projectCategory ?? '',
        'projectSubCategory': projectSubCategory ?? '',
        'projectContract': projectContract ?? '',
        'projectStage': projectStage ?? '',
        'currentStatus': currentStatus ?? 'Planning',
        'isContractWork': _isContractWork,
        'contractorName': _isContractWork
            ? _contractorNameController.text
            : null,
        'contractorBudget': _isContractWork
            ? double.tryParse(_contractorBudgetController.text) ?? 0
            : null,
        'plannedStartDate': plannedStartDate != null
            ? Timestamp.fromDate(plannedStartDate!)
            : null,
        'plannedEndDate': plannedEndDate != null
            ? Timestamp.fromDate(plannedEndDate!)
            : null,
        'actualStateDate': actualStartDate != null
            ? Timestamp.fromDate(actualStartDate!)
            : null,
        'actualEndDate': actualEndDate != null
            ? Timestamp.fromDate(actualEndDate!)
            : null,
        'contractStartDate': contractStartDate != null
            ? Timestamp.fromDate(contractStartDate!)
            : null,
        'contractEndDate': contractEndDate != null
            ? Timestamp.fromDate(contractEndDate!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isUpdateMode) {
        data['siteId'] = _selectedSiteId ?? '';
        data['createdAt'] = FieldValue.serverTimestamp();
        final id = await _generateNextProjectId();
        await FirestoreService.projects.doc(id).set(data);
      } else if (selectedProjectId != null) {
        await FirestoreService.projects.doc(selectedProjectId).update(data);
      }

      await showDialog(
        context: context,
        builder: (_) => _buildSuccessModal(context),
      );
      _resetForm();
      _fetchUnassignedSiteIds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fixed Slate 50
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: purple,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    "Project Config",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _mainFormKey,
          child: Column(
            children: [
              _buildWhiteCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildToggleButton(
                        label: 'New Project',
                        isActive: !isUpdateMode,
                        onTap: () => setState(() {
                          isUpdateMode = false;
                          _resetForm();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleButton(
                        label: 'Update Project',
                        isActive: isUpdateMode,
                        onTap: () => setState(() {
                          isUpdateMode = true;
                          _resetForm();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (isUpdateMode)
                _buildWhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Project',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirestoreService.projects.snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          final docs = snapshot.data!.docs;
                          final items = docs.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return "${data['projectName'] ?? ''} (${data['ownerName'] ?? ''})";
                          }).toList();

                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No projects found to update',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          String? dropdownValue;
                          if (selectedProjectId != null) {
                            try {
                              final doc = docs.firstWhere(
                                (d) => d.id == selectedProjectId,
                              );
                              final data = doc.data() as Map<String, dynamic>;
                              dropdownValue =
                                  "${data['projectName'] ?? ''} (${data['ownerName'] ?? ''})";
                            } catch (e) {
                              dropdownValue = null;
                            }
                          }

                          return _buildModernDropdown(
                            label: 'Project to Update',
                            value: items.contains(dropdownValue)
                                ? dropdownValue
                                : null,
                            items: items,
                            icon: Icons.location_city,
                            onChanged: (val) {
                              final doc = docs.firstWhere((d) {
                                final data = d.data() as Map<String, dynamic>;
                                return "${data['projectName'] ?? ''} (${data['ownerName'] ?? ''})" ==
                                    val;
                              });
                              _loadProjectData(doc.id);
                              setState(() => selectedProjectId = doc.id);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

              _buildWhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: purple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _projectNameController,
                      label: 'Project Name',
                      icon: Icons.title,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _ownerNameController,
                      label: 'Owner Name',
                      icon: Icons.person_outline,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildModernDropdown(
                      label: 'Site Id',
                      value: _selectedSiteId,
                      items:
                          (_selectedSiteId != null &&
                              !_unassignedSiteIds.contains(_selectedSiteId))
                          ? [_selectedSiteId!, ..._unassignedSiteIds]
                          : _unassignedSiteIds,
                      icon: Icons.location_on_outlined,
                      enabled: !isUpdateMode,
                      onChanged: (v) {
                        setState(() => _selectedSiteId = v);
                        _loadPlannedDatesForSite(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildWhiteCard(
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.projectCategories
                          .orderBy('projectCategoryId')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData
                            ? snapshot.data!.docs
                                  .map((d) => d['projectCategory'].toString())
                                  .toList()
                            : <String>[];
                        return _buildModernDropdown(
                          label: 'Project Category',
                          value: items.contains(projectCategory)
                              ? projectCategory
                              : null,
                          items: items,
                          icon: Icons.category,
                          onChanged: (v) => setState(() => projectCategory = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.projectStages
                          .orderBy('projectStageId')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData
                            ? snapshot.data!.docs
                                  .map((d) => d['projectStage'].toString())
                                  .toList()
                            : <String>[];
                        return _buildModernDropdown(
                          label: 'Stage',
                          value: items.contains(projectStage)
                              ? projectStage
                              : null,
                          items: items,
                          icon: Icons.flag,
                          onChanged: (v) => setState(() => projectStage = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.projectStatus.snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData
                            ? snapshot.data!.docs
                                  .map((d) => d['projectState'].toString())
                                  .toList()
                            : <String>[];
                        return _buildModernDropdown(
                          label: 'Project Status',
                          value: items.contains(currentStatus)
                              ? currentStatus
                              : null,
                          items: items,
                          icon: Icons.info_outline,
                          onChanged: (v) => setState(() => currentStatus = v),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildWhiteCard(
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _isContractWork,
                      onChanged: (v) =>
                          setState(() => _isContractWork = v ?? false),
                      title: Text(
                        'Contract Work',
                        style: TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      activeColor: purple,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isContractWork) ...[
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _contractorNameController,
                        label: 'Contractor Name',
                        icon: Icons.engineering,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _contractorBudgetController,
                        label: 'Contract Budget',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildWhiteCard(
                child: Column(
                  children: [
                    _buildModernDatePicker(
                      label: 'Planned Start',
                      date: plannedStartDate,
                      onTap: !isUpdateMode
                          ? () => _selectDate(
                              (d) => setState(() => plannedStartDate = d),
                              plannedStartDate,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildModernDatePicker(
                      label: 'Planned End',
                      date: plannedEndDate,
                      onTap: () => _selectDate(
                        (d) => setState(() => plannedEndDate = d),
                        plannedEndDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernDatePicker(
                      label: 'Actual Start',
                      date: actualStartDate,
                      onTap: () => _selectDate(
                        (d) => setState(() => actualStartDate = d),
                        actualStartDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernDatePicker(
                      label: 'Actual End',
                      date: actualEndDate,
                      onTap: () => _selectDate(
                        (d) => setState(() => actualEndDate = d),
                        actualEndDate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildWhiteCard(
                child: Column(
                  children: [
                    _buildModernTextField(
                      controller: _projectBudgetController,
                      label: 'Project Budget',
                      icon: Icons.account_balance_wallet,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _amountPaidController,
                      label: 'Amount Received',
                      icon: Icons.payments,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _amountSpentController,
                      label: 'Amount Spent',
                      icon: Icons.trending_up,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _balanceAmountController,
                      label: 'Balance Amount',
                      icon: Icons.account_balance,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveForm,
                  child: Text(
                    isUpdateMode ? 'Update Project' : 'Save Project',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          readOnly: readOnly,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: textColor),
            fillColor: bgColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
          iconEnabledColor: enabled ? textColor : Colors.grey,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? textColor : Colors.grey),
            fillColor: enabled ? bgColor : Colors.grey.shade100,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null
                      ? "Select $label"
                      : DateFormat('yyyy-MM-dd').format(date),
                  style: TextStyle(
                    color: date == null ? Colors.grey : Colors.black87,
                  ),
                ),
                Icon(Icons.calendar_today, color: textColor, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? purple : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? purple : borderColor),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(
    Function(DateTime) onSelected,
    DateTime? initialDate,
  ) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) onSelected(d);
  }

  Future<void> _fetchAndSetAmountSpentAndBalance(String? siteId) async {
    if (siteId == null || siteId.isEmpty) return;
    try {
      final doc = await FirestoreService.totalSiteExpensesPerDay
          .doc(siteId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final total =
            (data['totalMgrExpense'] ?? 0).toDouble() +
            (data['totalOrgExpense'] ?? 0).toDouble() +
            (data['totalSiteExpense'] ?? 0).toDouble();
        setState(() => _amountSpentController.text = total.toString());
      }
    } catch (e) {}
  }

  Widget _buildSuccessModal(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Success'),
      content: const Text('Saved successfully'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'OK',
            style: TextStyle(color: purple, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
