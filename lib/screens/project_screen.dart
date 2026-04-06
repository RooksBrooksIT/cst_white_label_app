import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Newly added fields for contract start and end dates
  DateTime? contractStartDate;
  DateTime? contractEndDate;

  String? _updateAppBarSiteId;
  List<String> _unassignedSiteIds = [];
  String? _selectedSiteId;

  bool isUpdateMode = false;
  Map<String, dynamic>? selectedProjectData;
  String? selectedProjectId;

  // Color scheme will be derived from theme in build method

  @override
  void initState() {
    super.initState();
    _setupAmountListeners();
    _fetchUnassignedSiteIds();
    _syncExpensesForAllProjects();
  }

  Future<void> _fetchUnassignedSiteIds() async {
    final siteSnapshot =
        await FirebaseFirestore.instance.collection('Site').get();
    final allSiteIds = siteSnapshot.docs.map((doc) => doc.id).toSet();

    final assignedSnapshot =
        await FirebaseFirestore.instance.collection('siteSupervisorMap').get();
    final assignedSiteIds = assignedSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['site'])
        .where((id) => id != null && id.toString().isNotEmpty)
        .map((id) => id.toString())
        .toSet();

    final unassigned = allSiteIds.difference(assignedSiteIds).toList();

    final projectsSnapshot =
        await FirebaseFirestore.instance.collection('projects').get();
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

    setState(() {
      _unassignedSiteIds = filtered;
      _selectedSiteId =
          _unassignedSiteIds.isNotEmpty ? _unassignedSiteIds[0] : null;
    });

    if (_selectedSiteId != null) {
      await _loadPlannedDatesForSite(_selectedSiteId);
    }
  }

  Future<void> _syncExpensesForAllProjects() async {
    final projectsSnapshot =
        await FirebaseFirestore.instance.collection('projects').get();
    for (var doc in projectsSnapshot.docs) {
      final siteId = doc.data()['siteId'];
      if (siteId != null) {
        final expenseSnapshot = await FirebaseFirestore.instance
            .collection('totalSiteExpensesPerDay')
            .doc(siteId)
            .get();
        if (expenseSnapshot.exists) {
          final data = expenseSnapshot.data()!;
          final totalMgrExpense = (data['totalMgrExpense'] ?? 0).toDouble();
          final totalOrgExpense = (data['totalOrgExpense'] ?? 0).toDouble();
          final totalSiteExpense = (data['totalSiteExpense'] ?? 0).toDouble();
          final totalIncentiveExpenses =
              (data['totalIncentiveExpenses'] ?? 0).toDouble();
          final totalContractorExpense =
              (data['totalContractorExpense'] ?? 0).toDouble();
          final amountSpent = totalMgrExpense +
              totalOrgExpense +
              totalSiteExpense +
              totalIncentiveExpenses +
              totalContractorExpense;
          final amountPaid = (doc.data()['amountPaid'] ?? 0).toDouble();
          final balanceAmount = amountPaid - amountSpent;
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(doc.id)
              .update({
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

  Future<void> _selectDate(BuildContext context, DateTime? initialDate,
      Function(DateTime) onSelected) async {
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
    _amountPaidController.clear();
    _amountSpentController.clear();
    _balanceAmountController.clear();
    _projectBudgetController.clear();
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
      selectedProjectData = null;
      selectedProjectId = null;
    });
  }

  Future<String> _generateNextProjectId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .orderBy(FieldPath.documentId)
        .get();
    int maxNumber = 0;
    for (var doc in snapshot.docs) {
      final id = doc.id;
      if (id.startsWith('PR')) {
        final number = int.tryParse(id.substring(2));
        if (number != null && number > maxNumber) {
          maxNumber = number;
        }
      }
    }
    final nextNumber = maxNumber + 1;
    return 'PR${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _updateProjectStageInSiteSupervisorMap({
    required String? siteId,
    required String? projectStage,
  }) async {
    final sid = siteId?.trim() ?? '';
    final stage = projectStage?.trim() ?? '';
    if (sid.isEmpty || stage.isEmpty) return;

    try {
      final qs = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('site', isEqualTo: sid)
          .get();

      if (qs.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in qs.docs) {
        batch.update(doc.reference, {
          'projectStage': stage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint(
          'Failed to sync projectStage to siteSupervisorMap for site=$sid: $e');
    }
  }

  Future<void> _saveForm() async {
    final validMain = _mainFormKey.currentState?.validate() == true;
    if (!validMain) return;

    try {
      if (!isUpdateMode) {
        final query = await FirebaseFirestore.instance
            .collection('projects')
            .where('siteId', isEqualTo: _selectedSiteId)
            .limit(1)
            .get();

        final data = _getProjectDataMap(isNew: query.docs.isEmpty);

        if (query.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(query.docs.first.id)
              .update(data);
        } else {
          final projectId = await _generateNextProjectId();
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .set(data);
        }

        await _ensureTotalSiteExpensesDoc(_selectedSiteId);

        final stageToSet = (projectStage ?? '').trim();
        if ((_selectedSiteId?.isNotEmpty ?? false) && stageToSet.isNotEmpty) {
          await _updateProjectStageInSiteSupervisorMap(
            siteId: _selectedSiteId,
            projectStage: stageToSet,
          );
        }

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessModal(context),
        );
        _resetForm();
        await _fetchUnassignedSiteIds();
      } else {
        if (selectedProjectId != null) {
          final Map<String, dynamic> updateData = {};

          final String stage = (projectStage ?? '').trim();
          if (stage.isNotEmpty) {
            updateData['projectStage'] = stage;
          }

          updateData['amountPaid'] =
              double.tryParse(_amountPaidController.text) ?? 0;

          updateData['amountBalance'] =
              double.tryParse(_balanceAmountController.text) ?? 0;

          final String cs = (currentStatus ?? '').trim();
          if (cs.isNotEmpty) {
            updateData['currentStatus'] = cs;
            updateData['status'] = cs;
          }

          updateData['actualStateDate'] = actualStartDate != null
              ? Timestamp.fromDate(actualStartDate!)
              : null;
          updateData['actualEndDate'] =
              actualEndDate != null ? Timestamp.fromDate(actualEndDate!) : null;

          // Add contract start/end dates to updateData
          updateData['contractStartDate'] = contractStartDate != null
              ? Timestamp.fromDate(contractStartDate!)
              : null;
          updateData['contractEndDate'] = contractEndDate != null
              ? Timestamp.fromDate(contractEndDate!)
              : null;

          if (_isContractWork) {
            updateData['isContractWork'] = true;
            updateData['contractorName'] = _contractorNameController.text;
            updateData['contractorBudget'] =
                double.tryParse(_contractorBudgetController.text) ?? 0;
          }

          await FirebaseFirestore.instance
              .collection('projects')
              .doc(selectedProjectId)
              .update(updateData);

          final String siteIdForTotals =
              _updateSiteIdController.text.trim().isNotEmpty
                  ? _updateSiteIdController.text.trim()
                  : (selectedProjectData?['siteId']?.toString() ?? '');
          await _ensureTotalSiteExpensesDoc(siteIdForTotals);

          final String stageToSet =
              (updateData['projectStage'] as String?) ?? (projectStage ?? '');
          await _updateProjectStageInSiteSupervisorMap(
            siteId: siteIdForTotals,
            projectStage: stageToSet,
          );

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessModal(context),
          );
          _resetForm();
        }
      }
    } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Map<String, dynamic> _getProjectDataMap({bool isNew = true}) {
    final now = Timestamp.now();
    return {
      'projectName': _projectNameController.text,
      'ownerName': _ownerNameController.text,
      'amountPaid': double.tryParse(_amountPaidController.text) ?? 0,
      'amountSpent':
          isNew ? 0 : double.tryParse(_amountSpentController.text) ?? 0,
      'amountBalance': isNew
          ? double.tryParse(_amountPaidController.text) ?? 0
          : double.tryParse(_balanceAmountController.text) ?? 0,
      'projectBudget': double.tryParse(_projectBudgetController.text) ?? 0,
      'projectCategory': projectCategory ?? '',
      'projectSubCategory': projectSubCategory ?? '',
      'projectContract': projectContract ?? '',
      'projectStage': projectStage ?? '',
      'currentStatus': currentStatus ?? 'Planning',
      'plannedStartDate': plannedStartDate != null
          ? Timestamp.fromDate(plannedStartDate!)
          : now,
      'plannedEndDate':
          plannedEndDate != null ? Timestamp.fromDate(plannedEndDate!) : null,
      'actualStateDate':
          actualStartDate != null ? Timestamp.fromDate(actualStartDate!) : null,
      'actualEndDate':
          actualEndDate != null ? Timestamp.fromDate(actualEndDate!) : null,
      // Add contractStartDate and contractEndDate here
      'contractStartDate': contractStartDate != null
          ? Timestamp.fromDate(contractStartDate!)
          : null,
      'contractEndDate':
          contractEndDate != null ? Timestamp.fromDate(contractEndDate!) : null,
      'isContractWork': _isContractWork,
      'contractorName': _isContractWork ? _contractorNameController.text : null,
      'contractorBudget': _isContractWork
          ? double.tryParse(_contractorBudgetController.text) ?? 0
          : null,
      'siteId': _selectedSiteId ?? '',
      'createdAt': isNew ? now : FieldValue.serverTimestamp(),
      'projectType': projectCategory ?? '',
      'status': currentStatus ?? 'Planning',
    };
  }

  void _setupAmountListeners() {
    _amountPaidController.addListener(_updateBalanceAmount);
    _amountSpentController.addListener(_updateBalanceAmount);
  }

  void _updateBalanceAmount() {
    final paid = double.tryParse(_amountPaidController.text) ?? 0;
    final spent = double.tryParse(_amountSpentController.text) ?? 0;
    final balance = paid - spent;
    _balanceAmountController.text = balance.toStringAsFixed(2);
  }

  bool _projectHasAllDetails(Map<String, dynamic> data) {
    bool nonEmpty(String? s) => s != null && s.trim().isNotEmpty;
    bool hasDates =
        data['plannedStartDate'] != null && data['plannedEndDate'] != null;
    final budget =
        double.tryParse((data['projectBudget'] ?? 0).toString()) ?? 0;

    final isContract = data['isContractWork'] == true;
    final contractorOk = !isContract ||
        (nonEmpty(data['contractorName']?.toString()) &&
            (double.tryParse((data['contractorBudget'] ?? 0).toString()) ?? 0) >
                0);

    return nonEmpty(data['projectName']?.toString()) &&
        nonEmpty(data['ownerName']?.toString()) &&
        nonEmpty(data['projectCategory']?.toString()) &&
        nonEmpty(data['projectSubCategory']?.toString()) &&
        nonEmpty(data['projectContract']?.toString()) &&
        nonEmpty(data['projectStage']?.toString()) &&
        nonEmpty((data['currentStatus'] ?? data['status'])?.toString()) &&
        hasDates &&
        budget > 0 &&
        contractorOk;
  }

  Future<void> _ensureTotalSiteExpensesDoc(String? siteId) async {
    if (siteId == null || siteId.isEmpty) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('totalSiteExpensesPerDay')
          .doc(siteId);
      final snap = await docRef.get();
      if (!snap.exists) {
        await docRef.set({
          'siteId': siteId,
          'totalMgrExpense': 0.0,
          'totalOrgExpense': 0.0,
          'totalSiteExpense': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPlannedDatesForSite(String? siteId) async {
    if (siteId == null || siteId.isEmpty) {
      setState(() {
        plannedStartDate = null;
        plannedEndDate = null;
      });
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
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
      } else {
        setState(() {
          plannedStartDate = null;
          plannedEndDate = null;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? const Color(0xFF2c3e50);
    final errorColor = theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Project Configuration",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
        ),
      ),
      body: Container(
        color: secondaryColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Toggle buttons for New/Update mode
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (isUpdateMode) {
                            setState(() {
                              isUpdateMode = false;
                              _resetForm();
                            });
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                            !isUpdateMode ? primaryColor : Colors.grey[200],
                          ),
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(0),
                        ),
                        child: Text('New Project',
                            style: TextStyle(
                                color: !isUpdateMode
                                    ? Colors.white
                                    : textColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!isUpdateMode) {
                            setState(() {
                              isUpdateMode = true;
                              _resetForm();
                            });
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                            isUpdateMode ? primaryColor : Colors.grey[200],
                          ),
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 12)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(0),
                        ),
                        child: Text('Update Project',
                            style: TextStyle(
                                color: isUpdateMode
                                    ? Colors.white
                                    : textColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!isUpdateMode)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Project',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryColor),
                          ),
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            context,
                            controller: _projectNameController,
                            label: 'Project Name',
                            icon: Icons.title,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            context,
                            controller: _ownerNameController,
                            label: 'Owner Name',
                            icon: Icons.person_outline,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSiteId,
                            items: _unassignedSiteIds.map((siteId) {
                              return DropdownMenuItem<String>(
                                value: siteId,
                                child: Text(siteId),
                              );
                            }).toList(),
                            onChanged: (val) async {
                              setState(() {
                                _selectedSiteId = val;
                              });
                              await _loadPlannedDatesForSite(val);
                            },
                            decoration: InputDecoration(
                              labelText: 'Site Id',
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            borderRadius: BorderRadius.circular(10),
                            dropdownColor: Colors.white,
                            validator: (val) => val == null || val.isEmpty
                                ? 'Required'
                                : null,
                          ),
                          if (_unassignedSiteIds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('All sites are assigned.',
                                  style: TextStyle(color: errorColor)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8),
                    child: CheckboxListTile(
                      value: _isContractWork,
                      onChanged: (val) {
                        setState(() {
                          _isContractWork = val ?? false;
                          if (!_isContractWork) {
                            // Clear contract dates when unchecked
                            contractStartDate = null;
                            contractEndDate = null;
                          }
                        });
                      },
                      title: Text('Is Contract Work',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryColor)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      tileColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Form(
                key: _mainFormKey,
                child: Column(
                  children: [
                    if (isUpdateMode)
                      Column(
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Project',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor),
                                  ),
                                  const SizedBox(height: 12),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('projects')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData)
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      final projects = snapshot.data!.docs;
                                      if (projects.isEmpty)
                                        return Text('No projects found',
                                            style: TextStyle(color: textColor));
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DropdownButtonFormField<String>(
                                            decoration: InputDecoration(
                                              labelText: 'Select Project to Update',
                                              prefixIcon: const Icon(
                                                  Icons.location_city),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                              filled: true,
                                              fillColor: Colors.grey[50],
                                            ),
                                            value: selectedProjectId,
                                            items: projects.where((doc) {
                                              final data = doc.data()
                                                  as Map<String, dynamic>;
                                              final name = (data[
                                                          'projectName'] ??
                                                      '')
                                                  .toString();
                                              return name.trim().isNotEmpty;
                                            }).map((doc) {
                                              final data = doc.data()
                                                  as Map<String, dynamic>;
                                              final name =
                                                  data['projectName'] ?? '';
                                              final location =
                                                  data['ownerName'] ?? '';
                                              return DropdownMenuItem<String>(
                                                value: doc.id,
                                                child: Text(
                                                    '$name (${location.toString()})'),
                                              );
                                            }).toList(),
                                            onChanged: (value) async {
                                              final selectedDoc =
                                                  projects.firstWhere(
                                                      (doc) => doc.id == value);
                                              final data = selectedDoc.data()
                                                  as Map<String, dynamic>;
                                              setState(() {
                                                selectedProjectId =
                                                    selectedDoc.id;
                                                selectedProjectData =
                                                    Map<String, dynamic>.from(
                                                        data);
                                                _projectNameController.text =
                                                    data['projectName'] ?? '';
                                                _ownerNameController.text =
                                                    data['ownerName'] ?? '';
                                                _amountPaidController.text =
                                                    (data['amountPaid'] ?? '')
                                                        .toString();
                                                _projectBudgetController.text =
                                                    (data['projectBudget'] ?? '')
                                                        .toString();
                                                projectCategory = data
                                                        .containsKey(
                                                            'projectCategory')
                                                    ? data['projectCategory']
                                                    : null;
                                                projectSubCategory = data
                                                        .containsKey(
                                                            'projectSubCategory')
                                                    ? data['projectSubCategory']
                                                    : null;
                                                projectContract = data
                                                        .containsKey(
                                                            'projectContract')
                                                    ? data['projectContract']
                                                    : null;
                                                projectStage = data.containsKey(
                                                        'projectStage')
                                                    ? data['projectStage']
                                                    : null;
                                                _isContractWork = data
                                                        .containsKey(
                                                            'isContractWork')
                                                    ? (data['isContractWork'] ==
                                                        true)
                                                    : false;
                                                _contractorNameController
                                                        .text = data.containsKey(
                                                                'contractorName') &&
                                                            data['contractorName'] !=
                                                                null
                                                    ? data['contractorName']
                                                        .toString()
                                                    : '';
                                                _contractorBudgetController
                                                        .text = data.containsKey(
                                                                'contractorBudget') &&
                                                            data['contractorBudget'] !=
                                                                null
                                                    ? data['contractorBudget']
                                                        .toString()
                                                    : '';
                                                currentStatus = data[
                                                            'currentStatus'] ??
                                                        data['status'] ??
                                                        null;
                                                plannedStartDate = data[
                                                            'plannedStartDate'] !=
                                                        null
                                                    ? (data['plannedStartDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                plannedEndDate = data[
                                                            'plannedEndDate'] !=
                                                        null
                                                    ? (data['plannedEndDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                actualStartDate = data[
                                                            'actualStateDate'] !=
                                                        null
                                                    ? (data['actualStateDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                actualEndDate = data[
                                                            'actualEndDate'] !=
                                                        null
                                                    ? (data['actualEndDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                // Load contract start and end dates
                                                contractStartDate = data[
                                                            'contractStartDate'] !=
                                                        null
                                                    ? (data['contractStartDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                contractEndDate = data[
                                                            'contractEndDate'] !=
                                                        null
                                                    ? (data['contractEndDate']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                                _updateSiteIdController.text = data
                                                            .containsKey(
                                                                'siteId') &&
                                                        data['siteId'] != null
                                                    ? data['siteId'].toString()
                                                    : '';
                                                _updateAppBarSiteId = data
                                                                .containsKey(
                                                                    'siteId') &&
                                                            data['siteId'] !=
                                                                null
                                                        ? data['siteId']
                                                            .toString()
                                                        : '';
                                              });
                                              await _fetchAndSetAmountSpentAndBalance(
                                                  data['siteId']);
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          if (selectedProjectId != null)
                                            _buildTextFormField(
                                              context,
                                              controller: _updateSiteIdController,
                                              label: 'Site ID',
                                              icon: Icons.location_on_outlined,
                                              readOnly: true,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text('Project Details',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor)),
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectCategories')
                                    .orderBy('projectCategoryId')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedCategories = [];
                                  if (snapshot.hasData) {
                                    fetchedCategories = snapshot.data!.docs
                                        .map((doc) =>
                                            doc['projectCategory'] as String)
                                        .toList();
                                  }
                                  String? dropdownValue = fetchedCategories
                                          .contains(projectCategory)
                                      ? projectCategory
                                      : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Project Category',
                                    items: fetchedCategories,
                                    icon: Icons.category_outlined,
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
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectSubCategories')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedSubCategories = [];
                                  if (snapshot.hasData) {
                                    fetchedSubCategories = snapshot.data!.docs
                                        .map((doc) =>
                                            doc['projectSubCategory'] as String)
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
                                    icon: Icons.category_outlined,
                                    onChanged: (value) => setState(
                                        () => projectSubCategory = value!),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                            ? 'Required'
                                            : null,
                                    enabled: !isUpdateMode,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectContracts')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedContracts = [];
                                  if (snapshot.hasData) {
                                    fetchedContracts = snapshot.data!.docs
                                        .map((doc) =>
                                            doc['projectContract'] as String)
                                        .toSet()
                                        .toList();
                                  }
                                  String? dropdownValue = fetchedContracts
                                          .contains(projectContract)
                                      ? projectContract
                                      : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Project Contract',
                                    items: fetchedContracts,
                                    icon: Icons.category_outlined,
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
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectStages')
                                    .orderBy('projectStageId')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedStages = [];
                                  if (snapshot.hasData) {
                                    fetchedStages = snapshot.data!.docs
                                        .map((doc) =>
                                            doc['projectStage'] as String)
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
                                    icon: Icons.flag_outlined,
                                    onChanged: (value) =>
                                        setState(() => projectStage = value!),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                            ? 'Required'
                                            : null,
                                    enabled: true,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectStatus')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedStates = [];
                                  if (snapshot.hasData) {
                                    fetchedStates = snapshot.data!.docs
                                        .map((doc) =>
                                            doc['projectState'] as String)
                                        .toList();
                                  }
                                  String? dropdownValue =
                                      fetchedStates.contains(currentStatus)
                                          ? currentStatus
                                          : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Current Status',
                                    items: fetchedStates,
                                    icon: Icons.timeline_outlined,
                                    onChanged: (val) =>
                                        setState(() => currentStatus = val),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                            ? 'Required'
                                            : null,
                                    enabled: true,
                                  );
                                },
                              ),

                              if (_isContractWork) const SizedBox(height: 16),
                              if (_isContractWork)
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('contractors')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    final docs = snapshot.hasData
                                        ? snapshot.data!.docs
                                        : <QueryDocumentSnapshot>[];
                                    final names = docs
                                        .map((d) {
                                          final data = d.data()
                                              as Map<String, dynamic>;
                                          final n = data['contractorName'];
                                          return n == null
                                              ? ''
                                              : n.toString();
                                        })
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                    final String? dropdownValue =
                                        names.contains(
                                                _contractorNameController.text)
                                            ? _contractorNameController.text
                                            : null;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            value: dropdownValue,
                                            items: names
                                                .map((name) =>
                                                    DropdownMenuItem<String>(
                                                      value: name,
                                                      child: Text(name),
                                                    ))
                                                .toList(),
                                            onChanged: (val) {
                                              setState(() {
                                                _contractorNameController
                                                    .text = val ?? '';
                                              });
                                            },
                                            decoration: InputDecoration(
                                              labelText: 'Contractor Name',
                                              prefixIcon: const Icon(
                                                  Icons.engineering_outlined),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[50],
                                            ),
                                            validator: (val) =>
                                                _isContractWork &&
                                                        (val == null ||
                                                            val.isEmpty)
                                                    ? 'Required'
                                                    : null,
                                            isExpanded: true,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.edit,
                                              color: primaryColor),
                                          tooltip: 'Edit Contractor Name',
                                          onPressed: () async {
                                            final controller =
                                                TextEditingController(
                                                    text:
                                                        _contractorNameController
                                                            .text);
                                            final result =
                                                await showDialog<String>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Edit Contractor Name'),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                          hintText:
                                                              'Enter contractor name'),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context,
                                                            controller.text),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (result != null &&
                                                result.trim().isNotEmpty) {
                                              setState(() {
                                                _contractorNameController
                                                    .text = result.trim();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              if (_isContractWork) const SizedBox(height: 16),
                              if (_isContractWork)
                                TextFormField(
                                  controller: _contractorBudgetController,
                                  decoration: InputDecoration(
                                    labelText: 'Contractor Budget',
                                    prefixIcon: const Icon(
                                        Icons.currency_rupee_rounded),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (!_isContractWork) return null;
                                    if (val == null || val.trim().isEmpty)
                                      return 'Required';
                                    final budget = double.tryParse(val);
                                    if (budget == null) return 'Invalid number';
                                    return null;
                                  },
                                  readOnly: false,
                                ),

                              // Added Contract Start Date and End Date pickers here
                              if (_isContractWork) const SizedBox(height: 16),
                              if (_isContractWork)
                                _buildDatePicker(
                                  context,
                                  "Contract Start Date",
                                  contractStartDate,
                                  (date) => setState(
                                      () => contractStartDate = date),
                                  validator: (val) => contractStartDate == null
                                      ? 'Required'
                                      : null,
                                  enabled: true,
                                ),
                              if (_isContractWork) const SizedBox(height: 16),
                              if (_isContractWork)
                                _buildDatePicker(
                                  context,
                                  "Contract End Date",
                                  contractEndDate,
                                  (date) =>
                                      setState(() => contractEndDate = date),
                                  validator: (val) => contractEndDate == null
                                      ? 'Required'
                                      : null,
                                  enabled: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text('Project Timeline',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor)),
                              const SizedBox(height: 20),
                              _buildDatePicker(
                                context,
                                "Planned Start Date",
                                plannedStartDate,
                                (date) =>
                                    setState(() => plannedStartDate = date),
                                validator: (val) => plannedStartDate == null
                                    ? 'Required'
                                    : null,
                                enabled: isUpdateMode,
                              ),
                              const SizedBox(height: 16),
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
                              const SizedBox(height: 16),
                              _buildDatePicker(
                                context,
                                "Actual Start Date",
                                actualStartDate,
                                (date) =>
                                    setState(() => actualStartDate = date),
                                validator: (val) => actualStartDate == null
                                    ? 'Required'
                                    : null,
                                enabled: true,
                              ),
                              const SizedBox(height: 16),
                              _buildDatePicker(
                                context,
                                "Actual End Date",
                                actualEndDate,
                                (date) =>
                                    setState(() => actualEndDate = date),
                                validator: (val) => actualEndDate == null
                                    ? 'Required'
                                    : null,
                                enabled: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text('Financial Details',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor)),
                              const SizedBox(height: 16),
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
                                      _amountPaidController.text);
                                  if (budget == null) return 'Invalid number';
                                  if (paid != null && budget <= paid)
                                    return 'Budget must be greater than Amount Received';
                                  return null;
                                },
                                readOnly: isUpdateMode,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                context,
                                controller: _amountPaidController,
                                label: 'Amount Received',
                                icon: Icons.currency_rupee_sharp,
                                keyboardType: TextInputType.number,
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                readOnly: false,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                context,
                                controller: _amountSpentController,
                                label: 'Amount Spent',
                                icon: Icons.currency_rupee_sharp,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                context,
                                controller: _balanceAmountController,
                                label: 'Balance Amount',
                                icon: Icons.currency_rupee_outlined,
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
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ],
          ),
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
    final expenseSnapshot = await FirebaseFirestore.instance
        .collection('totalSiteExpensesPerDay')
        .doc(siteId)
        .get();
    if (expenseSnapshot.exists) {
      final data = expenseSnapshot.data()!;
      final totalMgrExpense = (data['totalMgrExpense'] ?? 0).toDouble();
      final totalOrgExpense = (data['totalOrgExpense'] ?? 0).toDouble();
      final totalSiteExpense = (data['totalSiteExpense'] ?? 0).toDouble();
      final totalIncentiveExpenses =
          (data['totalIncentiveExpenses'] ?? 0).toDouble();
      final totalContractorExpense =
          (data['totalContractorExpense'] ?? 0).toDouble();
      final amountSpent = totalMgrExpense +
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
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? const Color(0xFF2c3e50);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
      ),
      style: TextStyle(color: textColor),
      cursorColor: primaryColor,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
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
    final primaryColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? const Color(0xFF2c3e50);

    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      style: TextStyle(color: textColor, fontSize: 16),
      icon: Icon(Icons.arrow_drop_down, color: primaryColor),
      dropdownColor: Colors.white,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyle(color: textColor)),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
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
    final primaryColor = theme.primaryColor;

    return InkWell(
      onTap: enabled ? () => _selectDate(context, initialDate, onSelected) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: primaryColor),
          prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        child: Text(
          formatDate(initialDate),
          style: TextStyle(
            color: initialDate == null ? Colors.grey[600] : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    const successColor = Color(0xFF28a745);
    const warningColor = Color(0xFFffc107);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.save,
          label: isUpdateMode ? 'Update' : 'Save',
          color: successColor,
          onPressed: _saveForm,
        ),
        _buildActionButton(
          context,
          icon: Icons.refresh,
          label: 'Reset',
          color: warningColor,
          onPressed: _resetForm,
        ),
        _buildActionButton(
          context,
          icon: Icons.cancel,
          label: 'Cancel',
          color: errorColor,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSuccessModal(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = const Color(0xFF28a745);
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
                color: successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: successColor, size: 60),
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