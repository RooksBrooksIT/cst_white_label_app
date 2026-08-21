import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class OrganizationExpenses extends StatefulWidget {
  const OrganizationExpenses({super.key});

  @override
  OrganizationExpensesState createState() => OrganizationExpensesState();
}

class OrganizationExpensesState extends State<OrganizationExpenses> {
  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();
  final supervisorController = TextEditingController();
  final projectPhaseController = TextEditingController();

  List<Map<String, String>> bills = [];

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadSiteIds();
  }

  @override
  void dispose() {
    billNoController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorController.dispose();
    projectPhaseController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteIds() async {
    setState(() {
      isLoadingSites = true;
    });
    try {
      final snapshot = await FirestoreService.getCollection('Site').get();
      siteIds = snapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .toList();

      setState(() {
        isLoadingSites = false;
      });
    } catch (e) {
      siteIds = [];
      setState(() {
        isLoadingSites = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load site IDs')),
        );
      }
    }
  }

  Widget _buildLabeledTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
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
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: primaryColor, size: 20.0)
                : null,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
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
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildBillTable(bool isDesktop, bool isTablet, bool isMobile) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              const Text(
                'No bills added yet',
                style: TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill bill details above and click "Add Bill to List"',
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
      try {
        total += double.parse(
          bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
      } catch (_) {}
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
                          bill['billVendor'] ?? 'Vendor',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Bill No: ${bill['billNo'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${bill['billAmount'] ?? '0'}',
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

  void _addBill() {
    final no = billNoController.text.trim();
    final vendor = billVendorController.text.trim();
    final amountStr = billAmountController.text.trim();

    if (no.isEmpty || vendor.isEmpty || amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all bill fields before adding.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      bills.add({
        'billNo': no,
        'billVendor': vendor,
        'billAmount': amountStr,
      });
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
    });
  }

  void _removeBill(int index) {
    setState(() {
      bills.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      selectedSiteId = null;
      selectedSupervisorId = null;
      selectedProjectPhase = null;
      selectedDate = DateTime.now();
      supervisorController.clear();
      projectPhaseController.clear();
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
      bills.clear();
    });
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
      });
    }
  }

  void _showConfirmationDialog(bool isDesktop, bool isTablet, bool isMobile) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirm Submission',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Site: ${selectedSiteId ?? 'Not selected'}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                Text('Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                Text('Total Bills: ${bills.length}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to submit this expense entry?',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _submitExpenseData(isDesktop, isTablet, isMobile);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitExpenseData(bool isDesktop, bool isTablet, bool isMobile) async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });

    if (selectedSiteId == null ||
        selectedSupervisorId == null ||
        selectedProjectPhase == null ||
        bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details and add at least one bill.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSubmitting = false;
      });
      return;
    }

    try {
      String projectName = '';
      try {
        final projectSnap = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: selectedSiteId)
            .limit(1)
            .get();
        if (projectSnap.docs.isNotEmpty) {
          projectName = projectSnap.docs.first.data()['projectName'] ?? '';
        }
      } catch (_) {}

      final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
      final newDocId = '${selectedSiteId}_$dateStr';

      final entryRef = FirestoreService.organizationEntries.doc(newDocId);
      final entrySnap = await entryRef.get();

      List<dynamic> existingBills = [];
      double existingTotal = 0;
      if (entrySnap.exists) {
        final data = entrySnap.data() as Map<String, dynamic>;
        existingBills = data['bills'] ?? [];
        existingTotal = (data['totalAmount'] ?? 0).toDouble();
      }

      double newTotal = 0;
      final billsData = bills.map((bill) {
        double amount = 0;
        try {
          amount = double.parse(
            bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
          );
        } catch (_) {}
        newTotal += amount;
        return {
          'billNo': bill['billNo'],
          'billVendor': bill['billVendor'],
          'billAmount': amount,
          'billDate': Timestamp.fromDate(selectedDate),
          'billCopy': 'billURL',
        };
      }).toList();

      final allBills = [...existingBills, ...billsData];
      final totalAmount = existingTotal + newTotal;

      final entry = {
        'siteId': selectedSiteId,
        'supervisorName': selectedSupervisorId,
        'projectStage': selectedProjectPhase,
        'projectName': projectName,
        'entryDate': Timestamp.now(),
        'bills': allBills,
        'totalAmount': totalAmount,
      };

      await entryRef.set(entry);

      double orgExpenseTotalAmount = 0;
      final allEntrySnap = await entryRef.get();
      if (allEntrySnap.exists) {
        final data = allEntrySnap.data() as Map<String, dynamic>;
        final billsList = data['bills'] as List<dynamic>? ?? [];
        for (var bill in billsList) {
          final amt = (bill['billAmount'] ?? 0).toDouble();
          orgExpenseTotalAmount += amt;
        }
      }

      final summary = {
        'date': selectedDate.toIso8601String(),
        'orgExpenseTotalAmount': orgExpenseTotalAmount,
        'projectName': projectName,
        'projectStage': selectedProjectPhase ?? '',
        'siteId': selectedSiteId ?? '',
      };

      await FirestoreService.organizationExpenseSummary
          .doc(newDocId)
          .set(summary);

      await ExpenseService.updateTotalOrgExpenseForSite(selectedSiteId!);

      _resetForm();

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
                  'Expense Data Submitted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Organization expense record has been successfully updated.',
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
      }
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit expense data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    if (!mounted) return;
    setState(() {
      isLoadingSiteDetails = true;
    });
    try {
      final snapshot = await FirestoreService.siteSupervisorMap
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final supervisor = data['supervisor'] as String?;
        final projectStage = data['projectStage'] as String?;
        setState(() {
          selectedSupervisorId = supervisor;
          selectedProjectPhase = projectStage;
          supervisorController.text = supervisor ?? '';
          projectPhaseController.text = projectStage ?? '';
          isLoadingSiteDetails = false;
        });
      } else {
        setState(() {
          selectedSupervisorId = 'Not Assigned';
          selectedProjectPhase = 'Not Assigned';
          supervisorController.text = 'Not Assigned';
          projectPhaseController.text = 'Not Assigned';
          isLoadingSiteDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingSiteDetails = false;
        });
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

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Organization Expenses',
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
            onPressed: _loadSiteIds,
            tooltip: 'Refresh Sites',
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
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
                            Icons.business_center_rounded,
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
                                'Organization Expenses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Record company expenditure, vendor bills & project stage logs',
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
                                });
                                if (value != null) {
                                  _loadSiteDetails(value);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                  _buildLabeledTextField(
                    'Supervisor ID',
                    supervisorController,
                    enabled: false,
                    prefixIcon: Icons.person_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Project Phase',
                    projectPhaseController,
                    enabled: false,
                    prefixIcon: Icons.flag_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
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
                    subtitle: 'Enter vendor, bill number and amount',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledTextField(
                    'Bill No',
                    billNoController,
                    prefixIcon: Icons.numbers_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Bill Vendor',
                    billVendorController,
                    prefixIcon: Icons.store_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Bill Amount',
                    billAmountController,
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addBill,
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
                  _buildBillTable(isDesktop, isTablet, isMobile),

                  const SizedBox(height: 28),

                  // ACTION BUTTONS ROW
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
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
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    if (selectedSiteId == null ||
                                        selectedSupervisorId == null ||
                                        selectedProjectPhase == null ||
                                        bills.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please fill all details and add at least one bill.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    _showConfirmationDialog(isDesktop, isTablet, isMobile);
                                  },
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
                                    'Submit Expenses',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A183D),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            onPressed: isSubmitting ? null : _resetForm,
                            icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF64748B)),
                            label: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
}
