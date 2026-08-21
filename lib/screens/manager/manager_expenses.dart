import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ManagerExpenses extends StatefulWidget {
  final bool hideAppBar;
  const ManagerExpenses({super.key, this.hideAppBar = false});

  @override
  State<ManagerExpenses> createState() => _ManagerExpensesState();
}

class _ManagerExpensesState extends State<ManagerExpenses> {
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
  List<Map<String, dynamic>> bills = [];
  List<Map<String, dynamic>> initialBills = [];
  Map<String, String> siteNameMap = {};
  double existingDailyTotal = 0.0;
  File? _selectedBillImage;
  final ImagePicker _picker = ImagePicker();

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadManagerData();
    _loadSiteIds();
    billDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
  }

  void _loadManagerData() {
    final userData = AuthService().userData;
    setState(() {
      managerId =
          userData['username'] ?? userData['UserName'] ?? 'UNKNOWN_MANAGER';
    });
  }

  @override
  void dispose() {
    billNoController.dispose();
    billDateController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorIdController.dispose();
    projectPhaseController.dispose();
    projectNameController.dispose();
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
          projectName = (data['projectName'] ?? data['project_name'])
              ?.toString();
        }
      }

      if (supervisorId != null && supervisorId.isNotEmpty) {
        try {
          final supDoc =
              await FirestoreService.supervisors.doc(supervisorId).get();
          if (supDoc.exists) {
            final supData = supDoc.data();
            supervisorName =
                supData?['username'] ??
                supData?['UserName'] ??
                supData?['name'];
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
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('organisation')
          .child(FirestoreService.currentOrgId)
          .child('expenses')
          .child(
            '${selectedSiteId}_${DateFormat('ddMMyyyy').format(selectedDate)}',
          )
          .child('bill_$billNo.jpg');

      final uploadTask = await storageRef.putFile(image);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadSiteIds(),
      if (selectedSiteId != null) _loadSiteDetails(selectedSiteId!),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data refreshed successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Site ID: $selectedSiteId', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
            Text('Project: $selectedProjectName', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
            Text('Total Bills: ${bills.length}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to submit these manager expenses?',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSubmitting = true);

    try {
      final docRef = FirestoreService.managerEntries.doc(docId);

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
          'entryDate': Timestamp.now(),
        });
      } else {
        await docRef.set({
          'bills': bills,
          'entryDate': Timestamp.now(),
          'managerId': managerId,
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
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 60.0),
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    Widget content = Align(
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
                        children: const [
                          Text(
                            'Manager Expenses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Record manager expenditure, vendor bills & stage logs',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION 1: SITE & PROJECT INFO
              _buildSectionHeader(
                title: '1. Site & Project Details',
                subtitle: 'Choose site ID and verify supervisor/phase info',
                icon: Icons.location_on_rounded,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
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
                          initialValue: siteIds.contains(selectedSiteId) ? selectedSiteId : null,
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 1.8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            ],
          ),
        ),
      ),
    );

    if (widget.hideAppBar) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manager Expenses',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
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
                'Total: ₹${total.toStringAsFixed(2)}',
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
                    '₹${bill['billAmount']?.toString() ?? '0'}',
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
