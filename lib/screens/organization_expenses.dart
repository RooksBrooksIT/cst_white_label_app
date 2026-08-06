import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/expense_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_scaffold.dart';

class OrganizationExpenses extends StatefulWidget {
  const OrganizationExpenses({super.key});

  @override
  _OrganizationExpensesState createState() => _OrganizationExpensesState();
}

class _OrganizationExpensesState extends State<OrganizationExpenses> {
  Color primaryColor = AppTheme.primaryColor.value;

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

  @override
  void initState() {
    super.initState();
    AppTheme.primaryColor.addListener(_onPrimaryColorChanged);
    _loadSiteIds();
  }

  void _onPrimaryColorChanged() {
    setState(() {
      primaryColor = AppTheme.primaryColor.value;
    });
  }

  @override
  void dispose() {
    AppTheme.primaryColor.removeListener(_onPrimaryColorChanged);
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
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 20.0 : 16.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: primaryColor, size: isDesktop ? 24.0 : 20.0)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: primaryColor, width: 2.0),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20.0 : 16.0,
            vertical: isDesktop ? 20.0 : 16.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBillTable(bool isDesktop, bool isTablet, bool isMobile) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 40.0 : 32.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: isDesktop ? 80.0 : 64.0,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              Text(
                'No bills added yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isDesktop ? 18.0 : 16.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bills.length,
      separatorBuilder: (context, index) => SizedBox(height: isDesktop ? 16.0 : 12.0),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20.0 : 16.0,
              vertical: isDesktop ? 12.0 : 8.0,
            ),
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(Icons.receipt_rounded, color: primaryColor, size: isDesktop ? 28.0 : 24.0),
            ),
            title: Text(
              bill['billVendor']!,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isDesktop ? 18.0 : 16.0),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isDesktop ? 6.0 : 4.0),
                Text('Bill No: ${bill['billNo']} • ${bill['billDate']}', style: TextStyle(fontSize: isDesktop ? 14.0 : 12.0)),
                SizedBox(height: isDesktop ? 6.0 : 4.0),
                Text(
                  bill['billAmount']!,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 16.0 : 15.0,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red, size: isDesktop ? 28.0 : 24.0),
              onPressed: () {
                setState(() {
                  bills.removeAt(index);
                });
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.light(primary: primaryColor),
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

  void _addBill() {
    if (billNoController.text.isNotEmpty &&
        billVendorController.text.isNotEmpty &&
        billAmountController.text.isNotEmpty) {
      setState(() {
        bills.add({
          'billNo': billNoController.text,
          'billDate': DateFormat('dd/MM/yy').format(selectedDate),
          'billVendor': billVendorController.text,
          'billAmount': '₹ ${billAmountController.text}',
        });

        billNoController.clear();
        billVendorController.clear();
        billAmountController.clear();
      });
    }
  }

  void _resetForm() {
    setState(() {
      bills.clear();
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
      selectedSiteId = null;
      selectedSupervisorId = null;
      selectedProjectPhase = null;
      selectedDate = DateTime.now();
    });
  }

  Future<void> _showConfirmationDialog(bool isDesktop, bool isTablet, bool isMobile) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Submission', style: TextStyle(fontSize: isDesktop ? 20.0 : 18.0)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Site: ${selectedSiteId ?? 'Not selected'}', style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0)),
                Text('Date: ${DateFormat('dd/MM/yy').format(selectedDate)}', style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0)),
                Text('Total Bills: ${bills.length}', style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0)),
                SizedBox(height: isDesktop ? 20.0 : 16.0),
                Text(
                  'Are you sure you want to submit this expense entry?',
                  style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20.0 : 16.0,
                  vertical: isDesktop ? 14.0 : 12.0,
                ),
              ),
              child: Text('OK', style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0)),
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
        ),
      );
      setState(() {
        isSubmitting = false;
      });
      return;
    }

    try {
      // Fetch projectName for selectedSiteId
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

      // Format date for docId
      final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
      final newDocId = '${selectedSiteId}_$dateStr';

      // 1. Save/merge to organizationEntries
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

      // Merge bills and total
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

      // 2. Save/update summary in organizationExpenseSummary
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

      // Update totalOrgExpense in totalSiteExpensesPerDay
      await ExpenseService.updateTotalOrgExpenseForSite(selectedSiteId!);

      // Immediately reset the form after successful submission
      _resetForm();

      // Show success dialog
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
              Icon(Icons.check_circle, color: Colors.green, size: isDesktop ? 80.0 : 60.0),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              Text(
                'Your data was submitted successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isDesktop ? 20.0 : 18.0, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK', style: TextStyle(color: Colors.black, fontSize: isDesktop ? 15.0 : 13.0)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error saving to Firestore:');
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit expense data')),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
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
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      title: 'Company Expenses',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: Colors.white, size: isDesktop ? 28.0 : 24.0),
          onPressed: _loadSiteIds,
          tooltip: 'Refresh Site IDs',
        ),
        SizedBox(width: isDesktop ? 12.0 : 8.0),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 900.0 : double.infinity),
            child: Column(
              children: [
                _buildSectionCard(
                  title: 'Site & Project Info',
                  icon: Icons.location_on_rounded,
                  child: Column(
                    children: [
                      isLoadingSites
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedSiteId,
                              decoration: InputDecoration(
                                labelText: 'Site ID',
                                prefixIcon: Icon(
                                  Icons.business_rounded,
                                  color: primaryColor,
                                  size: isDesktop ? 24.0 : 20.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 20.0 : 16.0,
                                  vertical: isDesktop ? 20.0 : 16.0,
                                ),
                              ),
                              items: siteIds
                                  .map(
                                    (site) => DropdownMenuItem<String>(
                                      value: site,
                                      child: Text(
                                        site,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
                      SizedBox(height: isDesktop ? 20.0 : 16.0),
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
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 20.0 : 16.0,
                            vertical: isDesktop ? 20.0 : 16.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12.0),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: primaryColor,
                                size: isDesktop ? 24.0 : 20.0,
                              ),
                              SizedBox(width: isDesktop ? 16.0 : 12.0),
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: isDesktop ? 17.0 : 16.0,
                                  color: Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: TextStyle(
                                  fontSize: isDesktop ? 17.0 : 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                SizedBox(height: isDesktop ? 24.0 : 16.0),
                _buildSectionCard(
                  title: 'Add Bill',
                  icon: Icons.receipt_long_rounded,
                  child: Column(
                    children: [
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
                        child: ElevatedButton.icon(
                          onPressed: _addBill,
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: isDesktop ? 24.0 : 20.0,
                          ),
                          label: Text(
                            "Add Bill to List",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 17.0 : 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(vertical: isDesktop ? 20.0 : 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                SizedBox(height: isDesktop ? 24.0 : 16.0),
                _buildSectionCard(
                  title: 'Bills List',
                  icon: Icons.list_alt_rounded,
                  child: _buildBillTable(isDesktop, isTablet, isMobile),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                SizedBox(height: isDesktop ? 32.0 : 24.0),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isDesktop ? 20.0 : 16.0),
                          side: BorderSide(color: Colors.grey.shade400, width: 2.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onPressed: isSubmitting ? null : _resetForm,
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: isDesktop ? 17.0 : 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 20.0 : 16.0),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(vertical: isDesktop ? 20.0 : 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 4.0,
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
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                                _showConfirmationDialog(isDesktop, isTablet, isMobile);
                              },
                        child: isSubmitting
                            ? SizedBox(
                                width: isDesktop ? 28.0 : 24.0,
                                height: isDesktop ? 28.0 : 24.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Submit Expenses',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isDesktop ? 17.0 : 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 40.0 : 32.0),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Card(
      elevation: 4.0,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 14.0 : 10.0),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(icon, color: primaryColor, size: isDesktop ? 32.0 : 24.0),
                ),
                SizedBox(width: isDesktop ? 20.0 : 16.0),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 20.0 : 18.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 24.0 : 20.0),
            child,
          ],
        ),
      ),
    );
  }
}
