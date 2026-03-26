import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/expense_service.dart';

class OrganizationExpenses extends StatefulWidget {
  const OrganizationExpenses({super.key});

  @override
  _OrganizationExpensesState createState() => _OrganizationExpensesState();
}

class _OrganizationExpensesState extends State<OrganizationExpenses> {
  final Color primaryColor = const Color(0xFF003768);

  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false; // Track submission state

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();
  final supervisorController = TextEditingController();
  final projectPhaseController = TextEditingController();

  List<Map<String, String>> bills = [];

  // Helper functions
  Widget _buildLabeledTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildBillTable() {
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No bills added yet.',
          style: TextStyle(),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(primaryColor.withOpacity(0.1)),
        columns: const [
          DataColumn(label: Text('Bill No')),
          DataColumn(label: Text('Bill Date')),
          DataColumn(label: Text('Bill Vendor')),
          DataColumn(label: Text('Bill Amount')),
          DataColumn(label: Text('Delete')),
        ],
        rows: bills
            .asMap()
            .entries
            .map(
              (entry) => DataRow(
                cells: [
                  DataCell(Text(entry.value['billNo']!)),
                  DataCell(Text(entry.value['billDate']!)),
                  DataCell(Text(entry.value['billVendor']!)),
                  DataCell(Text(entry.value['billAmount']!)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          bills.removeAt(entry.key);
                        });
                      },
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
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

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Site: ${selectedSiteId ?? 'Not selected'}'),
                Text('Date: ${DateFormat('dd/MM/yy').format(selectedDate)}'),
                Text('Total Bills: ${bills.length}'),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to submit this expense entry?',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _submitExpenseData();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitExpenseData() async {
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
      final entryRef = FirestoreService.organizationEntries
          .doc(newDocId);
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
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Your data was submitted successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle()),
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
    final snapshot = await FirestoreService.siteSupervisorMap
        .get();
    siteIds = snapshot.docs
        .map((doc) => doc.data()['site'] as String?)
        .where((site) => site != null && site.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList();
    setState(() {
      isLoadingSites = false;
    });
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
          selectedSupervisorId = null;
          selectedProjectPhase = null;
          supervisorController.clear();
          projectPhaseController.clear();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Organization Expenses',
          style: TextStyle( fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        toolbarHeight: 50,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Site & Project Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    isLoadingSites
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            value: selectedSiteId,
                            decoration: const InputDecoration(
                              labelText: 'Site ID',
                              border: OutlineInputBorder(),
                            ),
                            items: siteIds
                                .map(
                                  (site) => DropdownMenuItem<String>(
                                    value: site,
                                    child: Text(site),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: supervisorController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: projectPhaseController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Project Phase',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Date:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _selectDate(context),
                          label: Text(
                            DateFormat('dd/MM/yy').format(selectedDate),
                            style: const TextStyle(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Add Bill',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLabeledTextField('Bill No', billNoController),
                    _buildLabeledTextField(
                      'Bill Date',
                      TextEditingController(
                        text: DateFormat('dd/MM/yy').format(selectedDate),
                      ),
                      enabled: false,
                    ),
                    _buildLabeledTextField('Bill Vendor', billVendorController),
                    _buildLabeledTextField('Bill Amount', billAmountController),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addBill,
                          label: const Text(
                            "Upload Bill",
                            style: TextStyle(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _addBill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, ),
                              SizedBox(width: 4),
                              const Text(
                                'Add',
                                style: TextStyle(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Bills List',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBillTable(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting ? null : _resetForm,
                    child: const Text(
                      'Reset',
                      style: TextStyle(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                                ),
                              );
                              return;
                            }
                            _showConfirmationDialog();
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
