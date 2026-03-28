import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _mainFormKey = GlobalKey<FormState>();
  bool isUpdateMode = false;

  // Form Controllers
  final _projectNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneNumberController = TextEditingController();
  final _projectBudgetController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _amountSpentController = TextEditingController();
  final _balanceAmountController = TextEditingController();
  final _updateSiteIdController = TextEditingController();
  final _contractorNameController = TextEditingController();
  final _contractorBudgetController = TextEditingController();

  // Selection state
  String? selectedProjectId;
  Map<String, dynamic>? selectedProjectData;
  String? _updateAppBarSiteId;

  // Dropdown values
  String? projectCategory;
  String? projectSubCategory;
  String? projectContract;
  String? projectStage;
  String? currentStatus;
  bool _isContractWork = false;

  // Dates
  DateTime? plannedStartDate;
  DateTime? plannedEndDate;
  DateTime? actualStartDate;
  DateTime? actualEndDate;
  DateTime? contractStartDate;
  DateTime? contractEndDate;

  // Theme support
  late Color primaryColor;
  late Color textColor;
  late Color labelColor;
  late Color borderColor;
  late Color successColor;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneNumberController.dispose();
    _projectBudgetController.dispose();
    _amountPaidController.dispose();
    _amountSpentController.dispose();
    _balanceAmountController.dispose();
    _updateSiteIdController.dispose();
    _contractorNameController.dispose();
    _contractorBudgetController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _projectNameController.clear();
    _ownerNameController.clear();
    _ownerPhoneNumberController.clear();
    _projectBudgetController.clear();
    _amountPaidController.clear();
    _amountSpentController.clear();
    _balanceAmountController.clear();
    _updateSiteIdController.clear();
    _contractorNameController.clear();
    _contractorBudgetController.clear();
    setState(() {
      selectedProjectId = null;
      selectedProjectData = null;
      _updateAppBarSiteId = null;
      projectCategory = null;
      projectSubCategory = null;
      projectContract = null;
      projectStage = null;
      currentStatus = null;
      _isContractWork = false;
      plannedStartDate = null;
      plannedEndDate = null;
      actualStartDate = null;
      actualEndDate = null;
      contractStartDate = null;
      contractEndDate = null;
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _saveForm() async {
    if (!_mainFormKey.currentState!.validate()) return;

    try {
      final data = {
        'projectName': _projectNameController.text,
        'ownerName': _ownerNameController.text,
        'ownerPhoneNumber': _ownerPhoneNumberController.text,
        'projectBudget': double.tryParse(_projectBudgetController.text),
        'amountPaid': double.tryParse(_amountPaidController.text),
        'projectCategory': projectCategory,
        'projectSubCategory': projectSubCategory,
        'projectContract': projectContract,
        'projectStage': projectStage,
        'currentStatus': currentStatus,
        'isContractWork': _isContractWork,
        'contractorName': _isContractWork ? _contractorNameController.text : null,
        'contractorBudget': _isContractWork ? double.tryParse(_contractorBudgetController.text) : null,
        'plannedStartDate': plannedStartDate,
        'plannedEndDate': plannedEndDate,
        'actualStateDate': actualStartDate,
        'actualEndDate': actualEndDate,
        'contractStartDate': contractStartDate,
        'contractEndDate': contractEndDate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isUpdateMode && selectedProjectId != null) {
        await FirestoreService.getCollection('projects')
            .doc(selectedProjectId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['siteId'] = 'SITE_${DateTime.now().millisecondsSinceEpoch}';
        await FirestoreService.getCollection('projects').add(data);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _buildSuccessModal(context),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    primaryColor = theme.primaryColor;
    textColor = colorScheme.onSurface;
    labelColor = colorScheme.onSurfaceVariant;
    borderColor = colorScheme.outlineVariant;
    successColor = const Color(0xFF10B981);

    return GlassScaffold(
      title: isUpdateMode ? 'Update Project' : 'Add New Project',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _mainFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Toggle Section
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'NEW PROJECT',
                            onPressed: () {
                              if (isUpdateMode) {
                                setState(() {
                                  isUpdateMode = false;
                                  _resetForm();
                                });
                              }
                            },
                            isSecondary: isUpdateMode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassButton(
                            label: 'UPDATE PROJECT',
                            onPressed: () {
                              if (!isUpdateMode) {
                                setState(() {
                                  isUpdateMode = true;
                                  _resetForm();
                                });
                              }
                            },
                            isSecondary: !isUpdateMode,
                          ),
                        ),
                      ],
                    ),
                    if (isUpdateMode) ...[
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirestoreService.getCollection('projects').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final projects = snapshot.data!.docs;
                          return DropdownButtonFormField<String>(
                            value: selectedProjectId,
                            decoration: InputDecoration(
                              labelText: 'Select Project to Update',
                              prefixIcon: const Icon(Icons.location_city_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.cardColor,
                            ),
                            items: projects.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text("${data['projectName']} (${data['ownerName']})"),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              final doc = projects.firstWhere((d) => d.id == value);
                              final data = doc.data() as Map<String, dynamic>;
                              setState(() {
                                selectedProjectId = doc.id;
                                selectedProjectData = data;
                                _projectNameController.text = data['projectName'] ?? '';
                                _ownerNameController.text = data['ownerName'] ?? '';
                                _ownerPhoneNumberController.text = data['ownerPhoneNumber'] ?? '';
                                _projectBudgetController.text = (data['projectBudget'] ?? '').toString();
                                _amountPaidController.text = (data['amountPaid'] ?? '').toString();
                                projectCategory = data['projectCategory'];
                                projectSubCategory = data['projectSubCategory'];
                                projectContract = data['projectContract'];
                                projectStage = data['projectStage'];
                                _isContractWork = data['isContractWork'] == true;
                                _contractorNameController.text = data['contractorName'] ?? '';
                                _contractorBudgetController.text = (data['contractorBudget'] ?? '').toString();
                                currentStatus = data['currentStatus'];
                                plannedStartDate = (data['plannedStartDate'] as Timestamp?)?.toDate();
                                plannedEndDate = (data['plannedEndDate'] as Timestamp?)?.toDate();
                                actualStartDate = (data['actualStateDate'] as Timestamp?)?.toDate();
                                actualEndDate = (data['actualEndDate'] as Timestamp?)?.toDate();
                                contractStartDate = (data['contractStartDate'] as Timestamp?)?.toDate();
                                contractEndDate = (data['contractEndDate'] as Timestamp?)?.toDate();
                                _updateSiteIdController.text = data['siteId'] ?? '';
                              });
                              await _fetchAndSetAmountSpentAndBalance(data['siteId']);
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Basic Info Card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('General Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      context,
                      controller: _projectNameController,
                      label: 'Project Name',
                      icon: Icons.business_rounded,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      context,
                      controller: _ownerNameController,
                      label: 'Owner Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      context,
                      controller: _ownerPhoneNumberController,
                      label: 'Owner Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Project Categorization
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categorization', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.getCollection('projectCategories').snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['projectCategory'].toString()).toList() : <String>[];
                        return _buildDropdownField(
                          context,
                          value: projectCategory,
                          label: 'Category',
                          items: items,
                          icon: Icons.category_outlined,
                          onChanged: (v) => setState(() => projectCategory = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.getCollection('projectSubCategories').snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['projectSubCategory'].toString()).toList() : <String>[];
                        return _buildDropdownField(
                          context,
                          value: projectSubCategory,
                          label: 'Sub Category',
                          items: items,
                          icon: Icons.subdirectory_arrow_right_rounded,
                          onChanged: (v) => setState(() => projectSubCategory = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.getCollection('projectStages').snapshots(),
                      builder: (context, snapshot) {
                        final items = snapshot.hasData ? snapshot.data!.docs.map((d) => d['projectStage'].toString()).toList() : <String>[];
                        return _buildDropdownField(
                          context,
                          value: projectStage,
                          label: 'Current Stage',
                          items: items,
                          icon: Icons.flag_outlined,
                          onChanged: (v) => setState(() => projectStage = v),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Timeline
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildDatePicker(context, 'Planned Start Date', plannedStartDate, (d) => setState(() => plannedStartDate = d)),
                    const SizedBox(height: 12),
                    _buildDatePicker(context, 'Planned End Date', plannedEndDate, (d) => setState(() => plannedEndDate = d)),
                    const SizedBox(height: 12),
                    _buildDatePicker(context, 'Actual Start Date', actualStartDate, (d) => setState(() => actualStartDate = d)),
                    const SizedBox(height: 12),
                    _buildDatePicker(context, 'Actual End Date', actualEndDate, (d) => setState(() => actualEndDate = d)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Financials
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financials', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      context,
                      controller: _projectBudgetController,
                      label: 'Project Budget',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      context,
                      controller: _amountPaidController,
                      label: 'Amount Received',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _fetchAndSetAmountSpentAndBalance(_updateSiteIdController.text),
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      context,
                      controller: _amountSpentController,
                      label: 'Amount Spent',
                      icon: Icons.payments_outlined,
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      context,
                      controller: _balanceAmountController,
                      label: 'Balance Amount',
                      icon: Icons.hourglass_empty_rounded,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchAndSetAmountSpentAndBalance(String? siteId) async {
    if (siteId == null || siteId.isEmpty) return;
    try {
      final expenseSnapshot = await FirestoreService.getCollection('totalSiteExpensesPerDay').doc(siteId).get();
      if (expenseSnapshot.exists) {
        final data = expenseSnapshot.data()!;
        final amountSpent = (data['totalMgrExpense'] ?? 0.0) +
            (data['totalOrgExpense'] ?? 0.0) +
            (data['totalSiteExpense'] ?? 0.0) +
            (data['totalIncentiveExpenses'] ?? 0.0) +
            (data['totalContractorExpense'] ?? 0.0);
        
        _amountSpentController.text = amountSpent.toStringAsFixed(2);
        final paid = double.tryParse(_amountPaidController.text) ?? 0.0;
        _balanceAmountController.text = (paid - amountSpent).toStringAsFixed(2);
      }
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
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
    Function(String)? onChanged,
  }) {
    return GlassTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType ?? TextInputType.text,
      readOnly: readOnly,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String? value,
    required String label,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.cardColor,
      ),
      items: items.toSet().map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    DateTime? date,
    Function(DateTime) onDateSelected,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _selectDate(context, date, onDateSelected),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.cardColor,
        ),
        child: Text(formatDate(date), style: theme.textTheme.bodyLarge),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            label: isUpdateMode ? 'Update Project' : 'Save Project',
            onPressed: _saveForm,
          ),
        ),
        const SizedBox(width: 12),
        GlassButton(
          label: 'Reset',
          onPressed: _resetForm,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildSuccessModal(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: successColor, size: 64),
            const SizedBox(height: 24),
            Text('Success', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: successColor)),
            const SizedBox(height: 16),
            GlassButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
