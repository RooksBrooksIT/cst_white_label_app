import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/app_storage_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

class ManagerExpenses extends StatefulWidget {
  final bool hideAppBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ManagerExpenses({
    super.key,
    this.hideAppBar = false,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<ManagerExpenses> createState() => _ManagerExpensesState();
}

class _ManagerExpensesState extends State<ManagerExpenses>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- ENTRY TAB STATE ---
  String? selectedSiteId;
  String? selectedProjectName;
  String? selectedSupervisorId;
  String? selectedSupervisorName;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingBills = false;
  bool isSubmitting = false;
  bool isUploadingImage = false;

  final billNoController = TextEditingController();
  final billDateController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  final supervisorIdController = TextEditingController();
  final projectPhaseController = TextEditingController();
  final projectNameController = TextEditingController();

  String? managerId;
  String? managerName;
  String? managerRole;
  List<Map<String, dynamic>> bills = [];
  List<Map<String, dynamic>> initialBills = [];
  Map<String, String> siteNameMap = {};
  double existingDailyTotal = 0.0;
  File? _selectedBillImage;
  final ImagePicker _picker = ImagePicker();

  // --- LOGS TAB STATE ---
  final TextEditingController _logSearchController = TextEditingController();
  String _logSearchQuery = '';
  String _selectedLogSite = 'All';
  String _selectedLogRaiser = 'All'; // 'All', 'Manager', 'Supervisor'
  String _selectedLogDateFilter = 'All Time'; // 'All Time', 'Today', 'This Month'

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadManagerData();
    _loadSiteIds();
    billDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
  }

  void _loadManagerData() {
    final userData = AuthService().userData;
    setState(() {
      managerId = (userData['username'] ??
              userData['UserName'] ??
              userData['uid'] ??
              'UNKNOWN_MANAGER')
          .toString();
      managerName = (userData['FullName'] ??
              userData['fullName'] ??
              userData['username'] ??
              userData['UserName'] ??
              'Manager')
          .toString();
      managerRole = (userData['role'] ??
              userData['userRole'] ??
              userData['Designation'] ??
              'Manager')
          .toString();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    billNoController.dispose();
    billDateController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorIdController.dispose();
    projectPhaseController.dispose();
    projectNameController.dispose();
    _logSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteIds() async {
    setState(() => isLoadingSites = true);
    try {
      final sitesSnapshot = await FirestoreService.sites.get();
      final Map<String, String> names = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };

      final fetchedSiteIds = sitesSnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .toList();

      setState(() {
        siteNameMap = names;
        siteIds = fetchedSiteIds..sort();
        isLoadingSites = false;

        if (siteIds.length == 1) {
          selectedSiteId = siteIds.first;
          _loadSiteDetails(selectedSiteId!);
        }
      });
    } catch (e) {
      debugPrint('Error loading site IDs: $e');
      setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    String? supervisorId;
    String? supervisorName;
    String? projectPhase;
    String? projectName;

    try {
      final docRef = FirestoreService.siteSupervisorMap.doc(siteId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        supervisorId = data['supervisor']?.toString();
        projectPhase = data['projectStage']?.toString();
        projectName = (data['projectName'] ?? data['project_name'])?.toString();
      } else {
        final mapSnapshot = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: siteId)
            .limit(1)
            .get();
        if (mapSnapshot.docs.isNotEmpty) {
          final data = mapSnapshot.docs.first.data();
          supervisorId = data['supervisor']?.toString();
          projectPhase = data['projectStage']?.toString();
          projectName =
              (data['projectName'] ?? data['project_name'])?.toString();
        }
      }

      if (supervisorId != null && supervisorId.isNotEmpty) {
        try {
          final supDoc =
              await FirestoreService.supervisors.doc(supervisorId).get();
          if (supDoc.exists) {
            final supData = supDoc.data();
            supervisorName =
                supData?['username'] ?? supData?['UserName'] ?? supData?['name'];
          }
        } catch (e) {
          debugPrint('Error fetching supervisor details: $e');
        }
      }

      projectName ??= siteNameMap[siteId] ?? 'N/A';

      if (mounted) {
        setState(() {
          selectedSupervisorId = supervisorId ?? 'NOT_ASSIGNED';
          selectedSupervisorName = supervisorName ?? supervisorId ?? 'N/A';
          selectedProjectPhase = projectPhase ?? 'N/A';
          selectedProjectName = projectName;

          supervisorIdController.text =
              supervisorName != null && supervisorName.isNotEmpty
                  ? '$supervisorName ($supervisorId)'
                  : (supervisorId ?? 'Not Assigned');
          projectPhaseController.text = projectPhase ?? 'Not Assigned';
          projectNameController.text = projectName ?? 'Not Assigned';
        });
      }
    } catch (e) {
      debugPrint('Error loading site details: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0A183D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        billDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
      });
    }
  }

  Future<void> _pickBillImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _selectedBillImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadBillImage(File image, String billNo) async {
    try {
      if (selectedSiteId == null) return null;
      return await AppStorageService.uploadExpenseBill(
        siteId: selectedSiteId!,
        billNo: billNo,
        dateFormatted: DateFormat('ddMMyyyy').format(selectedDate),
        file: image,
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addBill() async {
    if (billNoController.text.isEmpty ||
        billVendorController.text.isEmpty ||
        billAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all bill fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedSiteId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Site first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isUploadingImage = true);

    try {
      String billUrl = "billURL";
      if (_selectedBillImage != null) {
        final uploadedUrl = await _uploadBillImage(
          _selectedBillImage!,
          billNoController.text,
        );
        if (uploadedUrl != null) {
          billUrl = uploadedUrl;
        }
      }

      final amount = double.tryParse(billAmountController.text) ?? 0.0;

      setState(() {
        bills.add({
          'billAmount': amount,
          'billCopy': billUrl,
          'billDate': Timestamp.fromDate(selectedDate),
          'billNo': billNoController.text,
          'billVendor': billVendorController.text,
          'raisedBy': managerId ?? 'Manager',
          'raisedByName': managerName ?? managerId ?? 'Manager',
          'userRole': managerRole ?? 'Manager',
          'createdAt': Timestamp.now(),
        });

        billNoController.clear();
        billVendorController.clear();
        billAmountController.clear();
        _selectedBillImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding bill: $e')));
      }
    } finally {
      setState(() => isUploadingImage = false);
    }
  }

  void _removeBill(int index) {
    setState(() {
      bills.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (selectedSiteId == null ||
        selectedSupervisorId == null ||
        selectedProjectPhase == null ||
        selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid site'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one bill'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
    final docId = '${selectedSiteId}_$dateStr';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Expense Submission',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Site ID: $selectedSiteId'),
            Text('Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
            Text('Bills to Add: ${bills.length}'),
            const SizedBox(height: 8),
            Text(
              'Total New Amount: ₹${bills.fold<double>(0.0, (acc, item) => acc + (item['billAmount'] as num).toDouble()).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSubmitting = true);

    try {
      final docRef = FirestoreService.managerExpenses.doc(docId);

      double newSessionTotal = 0.0;
      for (var bill in bills) {
        final amount = bill['billAmount'];
        if (amount is num) {
          newSessionTotal += amount.toDouble();
        }
      }

      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final existingData = docSnap.data() as Map<String, dynamic>;
        final List<dynamic> existingBills = existingData['bills'] ?? [];

        final combinedBills = [...existingBills, ...bills];

        double totalAmount = 0.0;
        for (var bill in combinedBills) {
          final amount = bill['billAmount'];
          if (amount is num) {
            totalAmount += amount.toDouble();
          }
        }

        await docRef.update({
          'bills': combinedBills,
          'totalAmount': totalAmount,
          'managerId': managerId,
          'managerName': managerName,
          'userRole': managerRole,
          'raisedBy': managerId,
          'raisedByName': managerName,
          'entryDate': Timestamp.now(),
        });
      } else {
        await docRef.set({
          'bills': bills,
          'entryDate': Timestamp.now(),
          'createdAt': Timestamp.now(),
          'managerId': managerId,
          'managerName': managerName,
          'userRole': managerRole,
          'raisedBy': managerId,
          'raisedByName': managerName,
          'projectName': selectedProjectName,
          'projectStage': selectedProjectPhase,
          'siteId': selectedSiteId,
          'supervisorName': selectedSupervisorId,
          'totalAmount': newSessionTotal,
        });
      }

      double managerExpenseTotalAmount = 0;
      final allEntrySnap = await docRef.get();
      if (allEntrySnap.exists) {
        final data = allEntrySnap.data() as Map<String, dynamic>;
        final billsList = data['bills'] as List<dynamic>? ?? [];
        for (var bill in billsList) {
          final amt = (bill['billAmount'] ?? 0).toDouble();
          managerExpenseTotalAmount += amt;
        }
      }

      final summaryData = {
        'date': selectedDate.toIso8601String(),
        'managerExpenseTotalAmount': managerExpenseTotalAmount,
        'managerId': managerId ?? '',
        'managerName': managerName ?? '',
        'projectName': selectedProjectName ?? '',
        'projectStage': selectedProjectPhase ?? '',
        'siteId': selectedSiteId ?? '',
      };

      await FirestoreService.managerExpenseSummary.doc(docId).set(summaryData);

      await ExpenseService.updateTotalMgrExpenseForSite(selectedSiteId!);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 60.0),
                const SizedBox(height: 16.0),
                const Text(
                  'Expenses Submitted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Manager expense entry has been successfully logged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Switch to Logs tab to view the newly logged entry
                  _tabController.animateTo(1);
                },
                child: const Text('View Logs',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        setState(() {
          bills = [];
          initialBills = [];
          existingDailyTotal = 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error submitting expenses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit expenses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return PopScope(
      canPop: widget.onBack == null && Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.onBack != null) {
          widget.onBack!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: widget.hideAppBar
            ? null
            : AppBar(
                iconTheme: const IconThemeData(color: Colors.white),
                automaticallyImplyLeading: false,
                title: const Text(
                  'Manager Expenses',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                leading: (widget.showBackButton ||
                        widget.onBack != null ||
                        Navigator.canPop(context))
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                        onPressed: () {
                          if (widget.onBack != null) {
                            widget.onBack!();
                          } else if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      )
                    : null,
              ),
        body: SafeArea(
          child: Column(
            children: [
              // Custom Styled Top Segment Tab Bar
              _buildCustomTabBar(primaryColor),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEntryTab(context, primaryColor, darkAccent),
                    _buildLogsTab(context, primaryColor, darkAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CUSTOM TAB BAR ---
  Widget _buildCustomTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_document, size: 17),
                SizedBox(width: 8),
                Text('Expense Entry'),
              ],
            ),
          ),
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 17),
                SizedBox(width: 8),
                Text('Expense Logs'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: EXPENSE ENTRY FORM
  // ===========================================================================
  Widget _buildEntryTab(
      BuildContext context, Color primaryColor, Color darkAccent) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 28.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record Manager Expenses',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Log bills & link raiser credentials (${managerName ?? "Manager"})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // SECTION 1: SITE & PROJECT INFO
              _buildSectionHeader(
                title: '1. Site & Project Details',
                subtitle: 'Choose site ID and verify supervisor/phase info',
                icon: Icons.location_on_rounded,
                color: primaryColor,
              ),
              const SizedBox(height: 14),
              isLoadingSites
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Site ID *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: siteIds.contains(selectedSiteId)
                              ? selectedSiteId
                              : null,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Select Site ID',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.business_rounded,
                              color: primaryColor,
                              size: 20.0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: primaryColor, width: 1.8),
                            ),
                          ),
                          items: siteIds
                              .map(
                                (site) => DropdownMenuItem<String>(
                                  value: site,
                                  child: Text(
                                    site,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSiteId = value;
                              selectedSupervisorId = null;
                              selectedProjectPhase = null;
                              selectedProjectName = null;
                              supervisorIdController.clear();
                              projectPhaseController.clear();
                              projectNameController.clear();
                              bills = [];
                              initialBills = [];
                              existingDailyTotal = 0.0;
                            });
                            if (value != null) {
                              _loadSiteDetails(value);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
              _buildCustomField(
                label: 'Supervisor',
                controller: supervisorIdController,
                icon: Icons.person_rounded,
                readOnly: true,
              ),
              _buildCustomField(
                label: 'Project Phase',
                controller: projectPhaseController,
                icon: Icons.timeline_rounded,
                readOnly: true,
              ),
              _buildCustomField(
                label: 'Project Name',
                controller: projectNameController,
                icon: Icons.assignment_rounded,
                readOnly: true,
              ),

              // Date Picker Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entry Date *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: primaryColor,
                            size: 20.0,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Expense Date:',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // SECTION 2: ADD BILL DETAILS
              _buildSectionHeader(
                title: '2. Add Bill Details',
                subtitle: 'Upload bill copy, vendor and amount',
                icon: Icons.receipt_long_rounded,
                color: Colors.indigo,
              ),
              const SizedBox(height: 16),
              _buildImagePicker(isDesktop, isTablet, isMobile),
              const SizedBox(height: 14),
              _buildCustomField(
                label: 'Bill Number',
                controller: billNoController,
                icon: Icons.numbers_rounded,
              ),
              _buildCustomField(
                label: 'Bill Date',
                controller: billDateController,
                icon: Icons.calendar_today_rounded,
                readOnly: true,
              ),
              _buildCustomField(
                label: 'Vendor Name',
                controller: billVendorController,
                icon: Icons.storefront_rounded,
              ),
              _buildCustomField(
                label: 'Amount (₹)',
                controller: billAmountController,
                icon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isUploadingImage ? null : _addBill,
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  label: const Text(
                    "Add Bill to List",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // SECTION 3: BILLS OVERVIEW
              _buildSectionHeader(
                title: '3. Expense Bills Overview',
                subtitle: 'Review added bills before final submission',
                icon: Icons.list_alt_rounded,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              _buildBillsListSection(isDesktop, isTablet, isMobile),

              const SizedBox(height: 28),

              // SUBMIT BUTTON
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3.0,
                    shadowColor: primaryColor.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  onPressed: isSubmitting || bills.isEmpty ? null : _handleSubmit,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: isSubmitting
                      ? const SizedBox(
                          width: 22.0,
                          height: 22.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Submit Manager Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: EXPENSE LOGS & AUDIT ACTIVITY HISTORY
  // ===========================================================================
  Widget _buildLogsTab(
      BuildContext context, Color primaryColor, Color darkAccent) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.managerExpenses.snapshots(),
      builder: (context, mgrSnap) {
        if (mgrSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error loading expense logs: ${mgrSnap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (mgrSnap.connectionState == ConnectionState.waiting &&
            !mgrSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mgrDocs = mgrSnap.data?.docs ?? [];

        // Ingest and convert all manager expense records
        final List<Map<String, dynamic>> allLogs = [];

        for (var doc in mgrDocs) {
          final data = doc.data();
          final docId = doc.id;
          final siteId = data['siteId']?.toString() ??
              docId.split('_').firstOrNull ??
              'N/A';
          final projectName = data['projectName']?.toString() ??
              siteNameMap[siteId] ??
              'Unnamed Project';
          final projectStage = data['projectStage']?.toString() ?? 'N/A';
          final managerId = (data['managerId'] ??
                  data['raisedBy'] ??
                  data['username'] ??
                  'Manager')
              .toString();
          final managerName = (data['managerName'] ??
                  data['raisedByName'] ??
                  managerId)
              .toString();
          final userRole =
              (data['userRole'] ?? data['role'] ?? 'Manager').toString();

          final rawEntryDate = data['entryDate'] ?? data['createdAt'] ?? data['date'];
          DateTime recordDate = DateTime.now();
          if (rawEntryDate is Timestamp) {
            recordDate = rawEntryDate.toDate();
          } else if (rawEntryDate is String) {
            recordDate = DateTime.tryParse(rawEntryDate) ?? DateTime.now();
          }

          final rawBills = data['bills'] as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> parsedBills = [];
          double totalAmt = 0.0;

          for (var b in rawBills) {
            if (b is Map) {
              final bAmt = (b['billAmount'] is num)
                  ? (b['billAmount'] as num).toDouble()
                  : (double.tryParse(b['billAmount']?.toString() ?? '') ?? 0.0);
              totalAmt += bAmt;

              DateTime bDate = recordDate;
              final rawBDate = b['billDate'];
              if (rawBDate is Timestamp) {
                bDate = rawBDate.toDate();
              } else if (rawBDate is String) {
                bDate = DateTime.tryParse(rawBDate) ?? recordDate;
              }

              DateTime? bCreatedAt;
              final rawBCreatedAt = b['createdAt'];
              if (rawBCreatedAt is Timestamp) {
                bCreatedAt = rawBCreatedAt.toDate();
              }

              parsedBills.add({
                'billNo': b['billNo']?.toString() ?? 'N/A',
                'billVendor': b['billVendor']?.toString() ?? 'Vendor',
                'billAmount': bAmt,
                'billCopy': b['billCopy']?.toString() ?? '',
                'billDate': bDate,
                'createdAt': bCreatedAt ?? recordDate,
                'raisedBy': (b['raisedBy'] ?? managerId).toString(),
                'raisedByName': (b['raisedByName'] ?? managerName).toString(),
                'userRole': (b['userRole'] ?? userRole).toString(),
              });
            }
          }

          if (totalAmt == 0.0 && data['totalAmount'] is num) {
            totalAmt = (data['totalAmount'] as num).toDouble();
          }

          allLogs.add({
            'docId': docId,
            'source': 'Manager Expenses',
            'siteId': siteId,
            'siteName': siteNameMap[siteId] ?? projectName,
            'projectName': projectName,
            'projectStage': projectStage,
            'raisedById': managerId,
            'raisedByName': managerName,
            'userRole': userRole,
            'totalAmount': totalAmt,
            'recordDate': recordDate,
            'bills': parsedBills,
            'rawData': data,
          });
        }

        // Sort logs in descending order (Newest first)
        allLogs.sort((a, b) {
          final DateTime dateA = a['recordDate'] as DateTime;
          final DateTime dateB = b['recordDate'] as DateTime;
          return dateB.compareTo(dateA);
        });

        // Apply filters & search
        final filteredLogs = allLogs.where((log) {
          final query = _logSearchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              log['siteId'].toString().toLowerCase().contains(query) ||
              log['siteName'].toString().toLowerCase().contains(query) ||
              log['projectName'].toString().toLowerCase().contains(query) ||
              log['projectStage'].toString().toLowerCase().contains(query) ||
              log['raisedByName'].toString().toLowerCase().contains(query) ||
              log['raisedById'].toString().toLowerCase().contains(query) ||
              (log['bills'] as List<Map<String, dynamic>>).any((b) =>
                  b['billNo'].toString().toLowerCase().contains(query) ||
                  b['billVendor'].toString().toLowerCase().contains(query));

          final matchesSite = _selectedLogSite == 'All' ||
              log['siteId'].toString().toLowerCase() ==
                  _selectedLogSite.toLowerCase();

          final matchesRaiser = _selectedLogRaiser == 'All' ||
              log['userRole'].toString().toLowerCase().contains(
                  _selectedLogRaiser.toLowerCase());

          bool matchesDate = true;
          final now = DateTime.now();
          final logDate = log['recordDate'] as DateTime;
          if (_selectedLogDateFilter == 'Today') {
            matchesDate = logDate.year == now.year &&
                logDate.month == now.month &&
                logDate.day == now.day;
          } else if (_selectedLogDateFilter == 'This Month') {
            matchesDate =
                logDate.year == now.year && logDate.month == now.month;
          }

          return matchesSearch && matchesSite && matchesRaiser && matchesDate;
        }).toList();

        // Calculate KPI totals
        double totalExpenseSum = 0.0;
        int totalBillsCount = 0;
        final Set<String> uniqueRaisers = {};

        for (var log in filteredLogs) {
          totalExpenseSum += (log['totalAmount'] as double);
          totalBillsCount += (log['bills'] as List).length;
          uniqueRaisers.add(log['raisedByName'].toString());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final hPad = Responsive.horizontalPadding(context);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI SUMMARY HEADER BANNER
                  _buildLogsKpiHeader(
                    primaryColor: primaryColor,
                    darkAccent: darkAccent,
                    totalExpense: totalExpenseSum,
                    totalLogs: filteredLogs.length,
                    totalBills: totalBillsCount,
                    totalRaisers: uniqueRaisers.length,
                    isWide: isWide,
                  ),
                  const SizedBox(height: 18),

                  // FILTER & SEARCH CONTROLS
                  _buildLogsFilterControls(primaryColor),
                  const SizedBox(height: 16),

                  // SECTION TITLE & ACTIVE FILTERS BAR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Activity Logs & Audit Records',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.16)),
                        ),
                        child: Text(
                          '${filteredLogs.length} Records',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // LOGS LIST
                  if (filteredLogs.isEmpty)
                    _buildEmptyLogsState(primaryColor)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildExpenseLogCard(
                          log: log,
                          primaryColor: primaryColor,
                          onTap: () => _showLogDetailsModal(context, log),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- LOGS KPI HEADER ---
  Widget _buildLogsKpiHeader({
    required Color primaryColor,
    required Color darkAccent,
    required double totalExpense,
    required int totalLogs,
    required int totalBills,
    required int totalRaisers,
    required bool isWide,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            darkAccent,
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Expense Audit & Activity Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'Live Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Amount & Grid of KPIs
          Text(
            '₹${_formatCurrency(totalExpense)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const Text(
            'Total Logged Expenditure',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLogsKpiSubItem(
                label: 'Total Logs',
                value: '$totalLogs',
                icon: Icons.receipt_long_rounded,
              ),
              _buildLogsKpiSubItem(
                label: 'Attached Bills',
                value: '$totalBills',
                icon: Icons.attach_file_rounded,
              ),
              _buildLogsKpiSubItem(
                label: 'Active Raisers',
                value: '$totalRaisers',
                icon: Icons.people_alt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsKpiSubItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- LOGS FILTER CONTROLS ---
  Widget _buildLogsFilterControls(Color primaryColor) {
    final List<String> siteFilterList = ['All', ...siteIds];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _logSearchController,
              onChanged: (val) {
                setState(() => _logSearchQuery = val.trim());
              },
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search by Raiser, Vendor, Bill No, Site...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                  size: 18,
                ),
                suffixIcon: _logSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _logSearchController.clear();
                          setState(() => _logSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Dropdowns Row
          Row(
            children: [
              // Site Dropdown
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: siteFilterList.contains(_selectedLogSite)
                          ? _selectedLogSite
                          : 'All',
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: siteFilterList
                          .map((site) => DropdownMenuItem<String>(
                                value: site,
                                child: Text(
                                  site == 'All' ? 'All Sites' : site,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogSite = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Raiser Role Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLogRaiser,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: ['All', 'Manager', 'Supervisor']
                          .map((role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(
                                  role == 'All' ? 'All Roles' : role,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogRaiser = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Date Timeline Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLogDateFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: ['All Time', 'Today', 'This Month']
                          .map((filter) => DropdownMenuItem<String>(
                                value: filter,
                                child: Text(filter,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogDateFilter = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- LOG CARD COMPONENT ---
  Widget _buildExpenseLogCard({
    required Map<String, dynamic> log,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final String raisedByName = log['raisedByName']?.toString() ?? 'Manager';
    final String raisedById = log['raisedById']?.toString() ?? '';
    final String userRole = log['userRole']?.toString() ?? 'Manager';
    final String siteId = log['siteId']?.toString() ?? 'N/A';
    final String siteName = log['siteName']?.toString() ?? siteId;
    final String projectStage = log['projectStage']?.toString() ?? 'N/A';
    final double totalAmount = log['totalAmount'] as double;
    final DateTime recordDate = log['recordDate'] as DateTime;
    final List<Map<String, dynamic>> billsList =
        (log['bills'] as List).cast<Map<String, dynamic>>();

    final isManager = userRole.toLowerCase().contains('manager');
    final roleColor = isManager
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Raiser Profile Badge & Record Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Raiser Info
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              roleColor.withValues(alpha: 0.18),
                              roleColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isManager
                                ? Icons.account_circle_rounded
                                : Icons.engineering_rounded,
                            color: roleColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    raisedByName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: roleColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'User ID: $raisedById',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Date & Time Chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(recordDate),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Middle: Site & Stage Badges + Expense Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Site & Stage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.apartment_rounded,
                                    size: 12, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    siteId,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (projectStage != 'N/A') ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  projectStage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        siteName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Total Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_formatCurrency(totalAmount)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${billsList.length} ${billsList.length == 1 ? "Bill" : "Bills"} logged',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Itemized Bills Chips / Preview if present
            if (billsList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: billsList.take(2).map((bill) {
                    final vendor = bill['billVendor']?.toString() ?? 'Vendor';
                    final bNo = bill['billNo']?.toString() ?? 'N/A';
                    final bAmt = (bill['billAmount'] is num)
                        ? (bill['billAmount'] as num).toDouble()
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_rounded,
                              size: 14, color: primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$vendor ($bNo)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${_formatCurrency(bAmt)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Bottom Action Bar: View Audit Details Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      'View Audit Breakdown',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- LOG DETAILS MODAL ---
  void _showLogDetailsModal(BuildContext context, Map<String, dynamic> log) {
    final String raisedByName = log['raisedByName']?.toString() ?? 'Manager';
    final String raisedById = log['raisedById']?.toString() ?? '';
    final String userRole = log['userRole']?.toString() ?? 'Manager';
    final String siteId = log['siteId']?.toString() ?? 'N/A';
    final String siteName = log['siteName']?.toString() ?? siteId;
    final String projectName = log['projectName']?.toString() ?? 'N/A';
    final String projectStage = log['projectStage']?.toString() ?? 'N/A';
    final double totalAmount = log['totalAmount'] as double;
    final DateTime recordDate = log['recordDate'] as DateTime;
    final List<Map<String, dynamic>> billsList =
        (log['bills'] as List).cast<Map<String, dynamic>>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Expense Audit Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Detailed raiser info and itemized bill copies',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 22, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Raiser Profile Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RAISER PROFILE & CREDENTIALS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.15),
                                    child: Icon(Icons.person_rounded,
                                        color: primaryColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          raisedByName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '$userRole • User ID: $raisedById',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Site & Timestamp Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildModalInfoRow(
                                  'Site ID', siteId, Icons.business_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Site Name', siteName,
                                  Icons.location_on_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Project', projectName,
                                  Icons.assignment_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Project Phase', projectStage,
                                  Icons.timeline_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow(
                                'Recorded Date & Time',
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(recordDate),
                                Icons.calendar_today_rounded,
                              ),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow(
                                'Total Expense',
                                '₹${_formatCurrency(totalAmount)}',
                                Icons.currency_rupee_rounded,
                                isBoldValue: true,
                                valueColor: primaryColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Itemized Bills Title
                        Text(
                          'Itemized Bills (${billsList.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Itemized Bills List
                        if (billsList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No individual bills attached for this entry.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: billsList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final b = billsList[index];
                              final vendor =
                                  b['billVendor']?.toString() ?? 'Vendor';
                              final bNo = b['billNo']?.toString() ?? 'N/A';
                              final bAmt = (b['billAmount'] is num)
                                  ? (b['billAmount'] as num).toDouble()
                                  : 0.0;
                              final bCopy = b['billCopy']?.toString() ?? '';
                              final bDate = b['billDate'] as DateTime?;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            vendor,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${_formatCurrency(bAmt)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Bill No: $bNo',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (bDate != null) ...[
                                          const Text(' • ',
                                              style: TextStyle(
                                                  color: Color(0xFF94A3B8))),
                                          Text(
                                            DateFormat('dd MMM yyyy')
                                                .format(bDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (bCopy.isNotEmpty &&
                                        bCopy != 'billURL') ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () {
                                          _showBillImagePreview(context, bCopy);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.image_rounded,
                                                  size: 14,
                                                  color: primaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                'View Attached Bill Copy',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isBoldValue = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isBoldValue ? 14 : 12.5,
              fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showBillImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Bill Attachment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: const Color(0xFF0F172A),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: const [
                        Icon(Icons.broken_image_rounded,
                            size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Unable to load bill image preview',
                            style: TextStyle(fontSize: 12)),
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

  Widget _buildEmptyLogsState(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No expense logs found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Expense and bill entries logged by managers and supervisors will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // --- HELPER BUILDERS & FORMATTERS ---
  String _formatCurrency(num value) {
    if (value == 0) return '0.00';
    final isNegative = value < 0;
    final absVal = value.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) {
      final res = '$intPart.$decPart';
      return isNegative ? '-$res' : res;
    }

    final last3 = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    final formatted = '${buffer.toString()}.$decPart';
    return isNegative ? '-$formatted' : formatted;
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
            prefixIcon: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildImagePicker(
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return InkWell(
      onTap: _pickBillImage,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        height: 130.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: _selectedBillImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedBillImage!, fit: BoxFit.cover),
                    Positioned(
                      top: 8.0,
                      right: 8.0,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF0A183D),
                        radius: 16,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 16),
                          onPressed: () =>
                              setState(() => _selectedBillImage = null),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    size: 36.0,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Upload Bill Copy (Optional)',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBillsListSection(
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (isLoadingBills) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              const Text(
                'No bills added yet',
                style: TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add bill details above and tap "Add Bill to List"',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    double total = 0;
    for (var bill in bills) {
      final amt = bill['billAmount'];
      if (amt is num) {
        total += amt.toDouble();
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${bills.length} Bill(s) Added',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  fontSize: 13,
                ),
              ),
              Text(
                'Total: ₹${_formatCurrency(total)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill['billVendor']?.toString() ?? 'Vendor',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Bill No: ${bill['billNo']?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_formatCurrency(bill['billAmount'] is num ? bill['billAmount'] : double.tryParse(bill['billAmount'].toString()) ?? 0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    onPressed: () => _removeBill(index),
                    tooltip: 'Remove Bill',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
