import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/expense_service.dart';

class ManagerExpenses extends StatefulWidget {
  const ManagerExpenses({super.key});

  @override
  _ManagerExpensesState createState() => _ManagerExpensesState();
}

class _ManagerExpensesState extends State<ManagerExpenses> {
  final Color primaryColor = const Color(0xFF003768);

  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false; // Loading state for submit button

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();

  List<Map<String, String>> bills = [];

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

  Widget _buildTextFieldWithLoad(String label) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBillTable() {
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No bills added yet.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          primaryColor.withOpacity(0.1),
        ),
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

  @override
  void initState() {
    super.initState();
    _loadSiteIds();
  }

  Future<void> _loadSiteIds() async {
    setState(() {
      isLoadingSites = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
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
    setState(() {
      isLoadingSiteDetails = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
        .where('site', isEqualTo: siteId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      selectedSupervisorId = data['supervisor'] as String?;
      selectedProjectPhase = data['projectStage'] as String?;
    } else {
      selectedSupervisorId = null;
      selectedProjectPhase = null;
    }
    setState(() {
      isLoadingSiteDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manager Expenses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      controller: TextEditingController(
                        text: selectedSupervisorId ?? '',
                      ),
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(
                        text: selectedProjectPhase ?? '',
                      ),
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
                            style: const TextStyle(color: Colors.white),
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
                            style: TextStyle(color: Colors.white),
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
                            children: const [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(color: Colors.white),
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
            SizedBox(
              width: double.infinity,
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
                    : () async {
                        setState(() {
                          isSubmitting = true;
                        });

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
                          setState(() {
                            isSubmitting = false;
                          });
                          return;
                        }

                        try {
                          double totalAmount = 0;
                          final billsData = bills.map((bill) {
                            double amount = 0;
                            try {
                              amount = double.parse(
                                bill['billAmount']!.replaceAll(
                                  RegExp(r'[^0-9.]'),
                                  '',
                                ),
                              );
                            } catch (_) {}
                            totalAmount += amount;
                            return {
                              'billNo': bill['billNo'],
                              'billVendor': bill['billVendor'],
                              'billAmount': amount,
                              'billDate': Timestamp.fromDate(selectedDate),
                              'billCopy': 'billURL',
                            };
                          }).toList();

                          String projectName = '';
                          try {
                            final projectSnap = await FirebaseFirestore.instance
                                .collection('siteSupervisorMap')
                                .where('site', isEqualTo: selectedSiteId)
                                .limit(1)
                                .get();
                            if (projectSnap.docs.isNotEmpty) {
                              projectName =
                                  projectSnap.docs.first
                                      .data()['projectName'] ??
                                  '';
                            }
                          } catch (_) {}

                          final dateStr = DateFormat(
                            'ddMMyyyy',
                          ).format(selectedDate);
                          final newDocId = '${selectedSiteId}_$dateStr';
                          final entryRef = FirebaseFirestore.instance
                              .collection('managerEntries')
                              .doc(newDocId);

                          final entrySnap = await entryRef.get();
                          List<dynamic> existingBills = [];
                          double existingTotal = 0;
                          if (entrySnap.exists) {
                            final data =
                                entrySnap.data() as Map<String, dynamic>;
                            existingBills = data['bills'] ?? [];
                            existingTotal = (data['totalAmount'] ?? 0)
                                .toDouble();
                          }

                          double newTotal = 0;
                          final newBillsData = bills.map((bill) {
                            double amount = 0;
                            try {
                              amount = double.parse(
                                bill['billAmount']!.replaceAll(
                                  RegExp(r'[^0-9.]'),
                                  '',
                                ),
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

                          final allBills = [...existingBills, ...newBillsData];
                          final totalAmountUpdated = existingTotal + newTotal;
                          final entry = {
                            'siteId': selectedSiteId,
                            'supervisorName': selectedSupervisorId,
                            'projectStage': selectedProjectPhase,
                            'projectName': projectName,
                            'entryDate': Timestamp.now(),
                            'bills': allBills,
                            'totalAmount': totalAmountUpdated,
                          };

                          await entryRef.set(entry);

                          double mgrExpenseTotalAmount = 0;
                          final allEntrySnap = await entryRef.get();
                          if (allEntrySnap.exists) {
                            final data =
                                allEntrySnap.data() as Map<String, dynamic>;
                            final billsList =
                                data['bills'] as List<dynamic>? ?? [];
                            for (var bill in billsList) {
                              final amt = (bill['billAmount'] ?? 0).toDouble();
                              mgrExpenseTotalAmount += amt;
                            }
                          }

                          final summary = {
                            'date': selectedDate.toIso8601String(),
                            'mgrExpenseTotalAmount': mgrExpenseTotalAmount,
                            'projectName': projectName,
                            'projectStage': selectedProjectPhase ?? '',
                            'siteId': selectedSiteId ?? '',
                          };

                          await FirebaseFirestore.instance
                              .collection('managerExpenseSummary')
                              .doc(newDocId)
                              .set(summary);

                          await ExpenseService.updateTotalMgrExpenseForSite(
                            selectedSiteId!,
                          );

                          await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Your data was submitted successfully!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                Center(
                                  child: RawMaterialButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    elevation: 3.0,
                                    fillColor: const Color.fromARGB(
                                      255,
                                      109,
                                      32,
                                      32,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 50,
                                      minHeight: 50,
                                    ),
                                    shape: const CircleBorder(),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          setState(() {
                            bills.clear();
                          });
                        } catch (e) {
                          print('Error saving to Firestore: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Error saving data. Please try again.',
                              ),
                            ),
                          );
                        } finally {
                          setState(() {
                            isSubmitting = false;
                          });
                        }
                      },
                child: isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
