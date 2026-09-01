import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

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
  final TextEditingController _projectSearchController =
      TextEditingController();
  String _projectSearchFilter = '';

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

  bool isUpdateMode = true;
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
    _projectSearchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _selectProjectData(DocumentSnapshot selectedDoc) {
    final data = selectedDoc.data() as Map<String, dynamic>;
    setState(() {
      selectedProjectId = selectedDoc.id;
      selectedProjectData = Map<String, dynamic>.from(data);
      _projectNameController.text = data['projectName'] ?? '';
      _ownerNameController.text = data['ownerName'] ?? '';
      _ownerPhoneController.text = data['ownerPhoneNumber'] ?? '';
      _amountPaidController.text = (data['amountPaid'] ?? '').toString();
      _projectBudgetController.text = (data['projectBudget'] ?? '').toString();
      projectCategory = data.containsKey('projectCategory') ? data['projectCategory'] : null;
      projectSubCategory = data.containsKey('projectSubCategory') ? data['projectSubCategory'] : null;
      projectContract = data.containsKey('projectContract') ? data['projectContract'] : null;
      projectStage = data.containsKey('projectStage') ? data['projectStage'] : null;
      currentStatus = data.containsKey('projectStatus') ? data['projectStatus'] : null;
      plannedStartDate = data['plannedStartDate'] is Timestamp ? (data['plannedStartDate'] as Timestamp).toDate() : null;
      plannedEndDate = data['plannedEndDate'] is Timestamp ? (data['plannedEndDate'] as Timestamp).toDate() : null;
      actualStartDate = data['actualStartDate'] is Timestamp ? (data['actualStartDate'] as Timestamp).toDate() : null;
      actualEndDate = data['actualEndDate'] is Timestamp ? (data['actualEndDate'] as Timestamp).toDate() : null;
      contractStartDate = data['contractStartDate'] is Timestamp ? (data['contractStartDate'] as Timestamp).toDate() : null;
      contractEndDate = data['contractEndDate'] is Timestamp ? (data['contractEndDate'] as Timestamp).toDate() : null;
      _updateAppBarSiteId = data['siteId'];
      _selectedSiteId = data['siteId'];
      _updateSiteIdController.text = data['siteId'] ?? '';
      _isContractWork = data['isContractWork'] ?? false;
    });
  }

  void _showProjectSearchModal(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String localSearch = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Search & Pick Project',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) {
                        setModalState(() {
                          localSearch = val.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by project name, owner, site ID, stage...',
                        prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.getCollection('projects').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs;
                        final filtered = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['projectName'] ?? '').toString().toLowerCase();
                          final owner = (data['ownerName'] ?? '').toString().toLowerCase();
                          final site = (data['siteId'] ?? data['site'] ?? '').toString().toLowerCase();
                          final cat = (data['projectCategory'] ?? '').toString().toLowerCase();
                          final stage = (data['projectStage'] ?? '').toString().toLowerCase();
                          if (localSearch.isEmpty) return name.trim().isNotEmpty;
                          return name.contains(localSearch) ||
                              owner.contains(localSearch) ||
                              site.contains(localSearch) ||
                              cat.contains(localSearch) ||
                              stage.contains(localSearch);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No matching projects found',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['projectName'] ?? 'Unnamed Project';
                            final owner = data['ownerName'] ?? 'No Owner';
                            final site = data['siteId'] ?? data['site'] ?? 'N/A';
                            final stage = data['projectStage'] ?? 'N/A';
                            final status = data['currentStatus'] ?? data['status'] ?? 'Active';
                            final isSelected = doc.id == selectedProjectId;

                            return InkWell(
                              onTap: () {
                                _selectProjectData(doc);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.business_rounded, color: primaryColor, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0A183D),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                owner,
                                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Site: $site',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (stage != 'N/A') ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Stage: $stage • Status: $status',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: primaryColor, size: 24),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

        final query = await FirestoreService.getCollection(
          'projects',
        ).where('siteId', isEqualTo: _selectedSiteId).get();

        if (query.docs.isNotEmpty) {
          final docId = query.docs.first.id;
          await FirestoreService.getCollection(
            'projects',
          ).doc(docId).update(projectData);
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
        await FirestoreService.getCollection(
          'projects',
        ).doc(selectedProjectId).update(projectData);
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
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Projects & Site Management',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              elevation: 0,
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
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
                  // ── IS CONTRACT WORK CHECKBOX ─────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                            color: Color(0xFF0A183D),
                            fontSize: 15,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: primaryColor,
                        checkColor: Colors.white,
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
                        // ── SELECT PROJECT TO MANAGE ───────────
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Select Project',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showProjectSearchModal(context),
                                    icon: const Icon(Icons.manage_search_rounded, size: 18),
                                    label: const Text(
                                      'Search All',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Live Filter Search Input
                              TextFormField(
                                controller: _projectSearchController,
                                onChanged: (val) {
                                  setState(() {
                                    _projectSearchFilter = val.trim().toLowerCase();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Type project name, owner, or site ID...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13.5,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  suffixIcon: _projectSearchFilter.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.cancel_rounded,
                                            color: Color(0xFF94A3B8),
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _projectSearchController.clear();
                                            setState(() {
                                              _projectSearchFilter = '';
                                            });
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
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
                                            AlwaysStoppedAnimation<Color>(
                                              primaryColor,
                                            ),
                                      ),
                                    );
                                  }
                                  final allDocs = snapshot.data!.docs;
                                  if (allDocs.isEmpty) {
                                    return const Text(
                                      'No projects found',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    );
                                  }

                                  final filteredDocs = allDocs.where((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name = (data['projectName'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final owner = (data['ownerName'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final site = (data['siteId'] ?? data['site'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final cat = (data['projectCategory'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final stage = (data['projectStage'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    if (_projectSearchFilter.isEmpty) {
                                      return name.trim().isNotEmpty;
                                    }
                                    return name.contains(_projectSearchFilter) ||
                                        owner.contains(_projectSearchFilter) ||
                                        site.contains(_projectSearchFilter) ||
                                        cat.contains(_projectSearchFilter) ||
                                        stage.contains(_projectSearchFilter);
                                  }).toList();

                                  final List<Map<String, dynamic>> projectItems = filteredDocs.map<Map<String, dynamic>>((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name = data['projectName'] ?? '';
                                    final owner = data['ownerName'] ?? '';
                                    final site = data['siteId'] ?? data['site'] ?? '';
                                    final siteText = site.toString().isNotEmpty ? ' [$site]' : '';
                                    return <String, dynamic>{
                                      'id': doc.id,
                                      'label': '$name ($owner)$siteText',
                                      'doc': doc,
                                    };
                                  }).toList();

                                  final itemLabels = projectItems
                                      .map((e) => e['label'] as String)
                                      .toList();
                                  final selectedItem = projectItems.firstWhere(
                                    (e) => e['id'] == selectedProjectId,
                                    orElse: () => <String, dynamic>{'label': ''},
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
                                        label: 'Select Project to Manage',
                                        items: itemLabels,
                                        icon: Icons.location_city_rounded,
                                        onChanged: (val) {
                                          final match = projectItems.firstWhere(
                                            (e) => e['label'] == val,
                                            orElse: () => <String, dynamic>{'doc': null},
                                          );
                                          if (match['doc'] != null) {
                                            _selectProjectData(
                                              match['doc'] as DocumentSnapshot,
                                            );
                                            _fetchAndSetAmountSpentAndBalance(
                                              (match['doc'] as DocumentSnapshot)['siteId'],
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      if (selectedProjectId != null)
                                        _buildTextFormField(
                                          context,
                                          controller:
                                              _updateSiteIdController,
                                          label: 'Site ID',
                                          icon:
                                              Icons.location_on_outlined,
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

                        // ── PROJECT DETAILS CARD ────────────────────
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
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
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 18),
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    FirestoreService.getCollection(
                                          'projectCategories',
                                        )
                                        .orderBy('projectCategoryId')
                                        .snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedCategories = [];
                                  if (snapshot.hasData) {
                                    fetchedCategories = snapshot
                                        .data!
                                        .docs
                                        .map(
                                          (doc) =>
                                              doc['projectCategory']
                                                  as String,
                                        )
                                        .toList();
                                  }
                                  String? dropdownValue =
                                      fetchedCategories.contains(
                                        projectCategory,
                                      )
                                      ? projectCategory
                                      : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Project Category',
                                    items: fetchedCategories,
                                    icon: Icons.category_rounded,
                                    onChanged: (value) => setState(
                                      () => projectCategory = value!,
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
                                  'projectSubCategories',
                                ).snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedSubCategories = [];
                                  if (snapshot.hasData) {
                                    fetchedSubCategories = snapshot
                                        .data!
                                        .docs
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
                                        projectSubCategory,
                                      )
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
                                          (doc) =>
                                              doc['projectContract']
                                                  as String,
                                        )
                                        .toSet()
                                        .toList();
                                  }
                                  String? dropdownValue =
                                      fetchedContracts.contains(
                                        projectContract,
                                      )
                                      ? projectContract
                                      : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Project Contract',
                                    items: fetchedContracts,
                                    icon: Icons.description_rounded,
                                    onChanged: (value) => setState(
                                      () => projectContract = value!,
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
                                  'projectStages',
                                ).snapshots(),
                                builder: (context, snapshot) {
                                  List<String> fetchedStages = [];
                                  if (snapshot.hasData) {
                                    final docs =
                                        List<QueryDocumentSnapshot>.from(
                                          snapshot.data!.docs,
                                        );
                                    docs.sort(
                                      (a, b) => a.id.compareTo(b.id),
                                    );
                                    fetchedStages = docs
                                        .map(
                                          (doc) =>
                                              doc['projectStage']
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
                                      () => projectStage = value!,
                                    ),
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
                                          (doc) {
                                            final data = doc.data() as Map<String, dynamic>?;
                                            return (data?['projectState'] ?? data?['projectStatus'])?.toString().trim() ?? '';
                                          },
                                        )
                                        .where((val) => val.isNotEmpty)
                                        .toSet()
                                        .toList();
                                  }
                                  if (currentStatus != null &&
                                      currentStatus!.isNotEmpty &&
                                      !fetchedStates.contains(currentStatus)) {
                                    fetchedStates.insert(0, currentStatus!);
                                  }
                                  String? dropdownValue =
                                      fetchedStates.contains(
                                        currentStatus,
                                      )
                                      ? currentStatus
                                      : null;
                                  return _buildDropdownField(
                                    context,
                                    value: dropdownValue,
                                    label: 'Current Status',
                                    items: fetchedStates,
                                    icon: Icons.timeline_rounded,
                                    onChanged: (val) => setState(
                                      () => currentStatus = val,
                                    ),
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
                                          final data =
                                              d.data()
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
                                            icon:
                                                Icons.engineering_rounded,
                                            onChanged: (val) {
                                              setState(() {
                                                _contractorNameController
                                                        .text =
                                                    val ?? '';
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
                                          padding: const EdgeInsets.only(
                                            top: 24.0,
                                          ),
                                          child: Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E88E5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    14,
                                                  ),
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
                                                final result = await showDialog<String>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
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
                                                              context,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                              controller
                                                                  .text,
                                                            ),
                                                        child: const Text(
                                                          'OK',
                                                        ),
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
                                                        .text = result
                                                        .trim();
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
                                  controller: _contractorBudgetController,
                                  label: 'Contractor Budget',
                                  icon: Icons.currency_rupee_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (!_isContractWork) return null;
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final budget = double.tryParse(val);
                                    if (budget == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildDatePicker(
                                  context,
                                  "Contract Start Date",
                                  contractStartDate,
                                  (date) => setState(
                                    () => contractStartDate = date,
                                  ),
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
                                    () => contractEndDate = date,
                                  ),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
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
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildDatePicker(
                                context,
                                "Planned Start Date",
                                plannedStartDate,
                                (date) => setState(
                                  () => plannedStartDate = date,
                                ),
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
                                  () => actualStartDate = date,
                                ),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
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
                                  color: Color(0xFF0A183D),
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
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final budget = double.tryParse(val);
                                  final paid = double.tryParse(
                                    _amountPaidController.text,
                                  );
                                  if (budget == null) {
                                    return 'Invalid number';
                                  }
                                  if (paid != null && budget < paid) {
                                    return 'Budget must be greater than Amount Received';
                                  }
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
                                icon:
                                    Icons.account_balance_wallet_rounded,
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
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: (value != null && uniqueItems.contains(value.trim()))
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
              return DropdownMenuItem<String>(value: item, child: Text(item));
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
            color: Color(0xFF0A183D),
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
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: brandIconColor,
                  size: 20,
                ),
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
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isUpdateMode ? Icons.check_rounded : Icons.save_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUpdateMode ? 'UPDATE PROJECT' : 'SAVE PROJECT',
                    style: const TextStyle(
                      color: Colors.white,
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
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A183D),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0A183D)),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
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
              child: const Icon(
                Icons.check_circle,
                color: successColor,
                size: 60,
              ),
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
