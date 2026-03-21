import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProjectStageDailySiteExpensesReportPage extends StatefulWidget {
  final String supervisorId;
  final String? siteId;
  final DateTime date;
  final String projectStage;

  const ProjectStageDailySiteExpensesReportPage({
    super.key,
    required this.supervisorId,
    required this.siteId,
    required this.date,
    required this.projectStage,
  });

  @override
  State<ProjectStageDailySiteExpensesReportPage> createState() =>
      _ProjectStageDailySiteExpensesReportPageState();
}

class _ProjectStageDailySiteExpensesReportPageState
    extends State<ProjectStageDailySiteExpensesReportPage> {
  // Updated color scheme with #0b3470 as primary
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLightColor = const Color(0xFF4a5c8b);
  final Color primaryDarkColor = const Color(0xFF001258);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color secondaryColor = const Color(0xFFff7d00);
  final Color backgroundColor = const Color(0xFFf8f9fa);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF333333);
  final Color textLightColor = const Color(0xFF6c757d);

  String? _siteName;
  bool _siteNameLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSiteName();
  }

  Future<void> _fetchSiteName() async {
    if (widget.siteId == null) return;
    setState(() {
      _siteNameLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Site')
          .doc(widget.siteId)
          .get();
      if (doc.exists) {
        setState(() {
          _siteName = doc.data()?['siteName']?.toString() ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _siteName = '';
      });
    } finally {
      setState(() {
        _siteNameLoading = false;
      });
    }
  }

  String get _documentId {
    final formattedDate = DateFormat('ddMMyyyy').format(widget.date);
    return '${widget.siteId}_$formattedDate';
  }

  /// Helper function to parse a dynamic Firestore date field (Timestamp or String) to DateTime?
  DateTime? _parseFirestoreDate(dynamic dateField) {
    if (dateField == null) {
      return null;
    } else if (dateField is Timestamp) {
      return dateField.toDate();
    } else if (dateField is String) {
      return DateTime.tryParse(dateField);
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchAllReports() async {
    final supervisorDoc = await FirebaseFirestore.instance
        .collection('siteSupervisorEntries')
        .doc(_documentId)
        .get();
    final managerQuery = await FirebaseFirestore.instance
        .collection('managerEntries')
        .where('siteId', isEqualTo: widget.siteId)
        .get();
    final allManagerDocs = managerQuery.docs;
    final orgQuery = await FirebaseFirestore.instance
        .collection('organizationEntries')
        .where('siteId', isEqualTo: widget.siteId)
        .get();
    final allOrgDocs = orgQuery.docs;

    // Fetch contract expenses filtered by siteId, date, and projectStage
    final contractQuery = await FirebaseFirestore.instance
        .collection('contractorEntries')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .get();
    // Filter by date and projectStage in Dart to handle any type issues
    final contractDocs = contractQuery.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final entryDateObj = _parseFirestoreDate(data['date']);

      final isSameDate =
          entryDateObj != null &&
          DateFormat('yyyy-MM-dd').format(entryDateObj) ==
              DateFormat('yyyy-MM-dd').format(widget.date);

      // Project stage already filtered in query, but double check
      final isSameStage = data['projectStage'] == widget.projectStage;

      return isSameDate && isSameStage;
    }).toList();

    return {
      'supervisor': supervisorDoc.exists ? supervisorDoc : null,
      'managerEntries': allManagerDocs,
      'organizationEntries': allOrgDocs,
      'contractorEntries': contractDocs,
    };
  }

  List<DataRow> _buildLabourRows(List<dynamic> labours) {
    return labours.map<DataRow>((labour) {
      return DataRow(
        cells: [
          DataCell(Text('Labour', style: TextStyle(color: textColor))),
          DataCell(
            Text(labour['type'] ?? '', style: TextStyle(color: textColor)),
          ),
          DataCell(
            Text(
              '${labour['count'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
          DataCell(
            Text(
              '${labour['unitSalary'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
          DataCell(
            Text(
              '${labour['amount'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      );
    }).toList();
  }

  List<DataRow> _buildMaterialRows(List<dynamic> materials) {
    return materials.map<DataRow>((material) {
      return DataRow(
        cells: [
          DataCell(Text('Material', style: TextStyle(color: textColor))),
          DataCell(
            Text(material['type'] ?? '', style: TextStyle(color: textColor)),
          ),
          DataCell(
            Text(
              '${material['quantity'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
          DataCell(
            Text(
              '${material['unitPrice'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
          DataCell(
            Text(
              '${material['amount'] ?? ''}',
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      );
    }).toList();
  }

  List<DataRow> _buildExpenseRows(Map<String, dynamic> data) {
    final List<DataRow> rows = [];
    final expenseFields = [
      {'type': 'Food', 'key': 'food'},
      {'type': 'Fuel', 'key': 'fuel'},
      {'type': 'Transport', 'key': 'transport'},
    ];
    for (var field in expenseFields) {
      if (data.containsKey(field['key'])) {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text('Expense', style: TextStyle(color: textColor))),
              DataCell(
                Text(field['type']!, style: TextStyle(color: textColor)),
              ),
              DataCell(Text('-', style: TextStyle(color: textColor))),
              DataCell(Text('-', style: TextStyle(color: textColor))),
              DataCell(
                Text(
                  '${data[field['key']]}',
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        );
      }
    }
    return rows;
  }

  // PDF generation and other UI related code here remains largely unchanged,
  // except replacing all date parsing with _parseFirestoreDate helper function.

  pw.Widget _pdfBillsTable(List<Map<String, dynamic>> bills) {
    final tableRows = bills.map((bill) {
      String billDate = '-';
      final billDateRaw = bill['billDate'];
      final parsedDate = _parseFirestoreDate(billDateRaw);
      if (parsedDate != null) {
        billDate = DateFormat('yyyy-MM-dd').format(parsedDate);
      }
      return [
        bill['billNo']?.toString() ?? '-',
        bill['billVendor']?.toString() ?? '-',
        bill['billAmount']?.toString() ?? '-',
        billDate,
      ];
    }).toList();
    return pw.Table.fromTextArray(
      headers: ['Bill No', 'Vendor', 'Amount', 'Date'],
      data: tableRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Daily Site Expenses Report'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading report data...',
                    style: TextStyle(color: primaryColor, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          final supervisorDoc = snapshot.data?['supervisor'];
          final managerEntries =
              snapshot.data?['managerEntries'] as List<DocumentSnapshot>;
          final orgEntries =
              snapshot.data?['organizationEntries'] as List<DocumentSnapshot>;

          if (supervisorDoc == null &&
              managerEntries.isEmpty &&
              orgEntries.isEmpty) {
            return Center(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: textLightColor),
                      SizedBox(height: 16),
                      Text(
                        'No report found for this date.',
                        style: TextStyle(fontSize: 16, color: textLightColor),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Extract data
          final supervisorData = supervisorDoc?.data() as Map<String, dynamic>?;
          final orgData = orgEntries.isNotEmpty
              ? orgEntries.first.data() as Map<String, dynamic>?
              : null;

          final contractEntries =
              snapshot.data?['contractorEntries'] as List<DocumentSnapshot>;
          List<DataRow> contractRows = [];
          num contractTotal = 0;
          if (contractEntries.isNotEmpty) {
            for (final doc in contractEntries) {
              final contractData = doc.data() as Map<String, dynamic>?;
              if (contractData != null) {
                // Add main expense fields
                final expenseFields = [
                  {'type': 'Food', 'key': 'food'},
                  {'type': 'Fuel', 'key': 'fuel'},
                  {'type': 'Transport', 'key': 'transport'},
                ];
                for (var field in expenseFields) {
                  if (contractData.containsKey(field['key'])) {
                    contractRows.add(
                      DataRow(
                        cells: [
                          DataCell(
                            Text('Expense', style: TextStyle(color: textColor)),
                          ),
                          DataCell(
                            Text(
                              field['type']!,
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          DataCell(
                            Text('-', style: TextStyle(color: textColor)),
                          ),
                          DataCell(
                            Text('-', style: TextStyle(color: textColor)),
                          ),
                          DataCell(
                            Text(
                              '${contractData[field['key']]}',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ],
                      ),
                    );
                    contractTotal +=
                        num.tryParse(contractData[field['key']].toString()) ??
                        0;
                  }
                }
                // Add labours
                final labours =
                    (contractData['labours'] ?? []) as List<dynamic>;
                for (var labour in labours) {
                  contractRows.add(
                    DataRow(
                      cells: [
                        DataCell(
                          Text('Labour', style: TextStyle(color: textColor)),
                        ),
                        DataCell(
                          Text(
                            labour['type'] ?? '',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${labour['count'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${labour['unitSalary'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${labour['amount'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ],
                    ),
                  );
                  contractTotal +=
                      num.tryParse(labour['amount']?.toString() ?? '0') ?? 0;
                }
                // Add materials
                final materials =
                    (contractData['materials'] ?? []) as List<dynamic>;
                for (var material in materials) {
                  contractRows.add(
                    DataRow(
                      cells: [
                        DataCell(
                          Text('Material', style: TextStyle(color: textColor)),
                        ),
                        DataCell(
                          Text(
                            material['type'] ?? '',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${material['quantity'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${material['unitPrice'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${material['amount'] ?? ''}',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ],
                    ),
                  );
                  contractTotal +=
                      num.tryParse(material['amount']?.toString() ?? '0') ?? 0;
                }
              }
            }
          }

          final managerData = managerEntries.isNotEmpty
              ? managerEntries.first.data() as Map<String, dynamic>?
              : null;

          final siteId =
              widget.siteId ??
              supervisorData?['siteId'] ??
              managerData?['siteId'] ??
              orgData?['siteId'] ??
              'N/A';

          final supervisorName =
              supervisorData?['supervisorName'] ??
              managerData?['supervisorName'] ??
              orgData?['supervisorName'] ??
              widget.supervisorId;

          // Supervisor Expenses Table
          List<DataRow> supervisorRows = [];
          if (supervisorData != null) {
            final labours = (supervisorData['labours'] ?? []) as List<dynamic>;
            final materials =
                (supervisorData['materials'] ?? []) as List<dynamic>;
            supervisorRows = [
              ..._buildExpenseRows(supervisorData),
              ..._buildLabourRows(labours),
              ..._buildMaterialRows(materials),
            ];
          }
          final supervisorTotal = supervisorData?['totalAmount'] ?? 0;

          // Manager Expenses Table
          List<DataRow> managerRows = [];
          num managerTotal = 0;
          if (managerEntries.isNotEmpty) {
            final selectedDateStr = DateFormat(
              'yyyy-MM-dd',
            ).format(widget.date);
            for (var doc in managerEntries) {
              final managerData = doc.data() as Map<String, dynamic>?;
              if (managerData != null && managerData['bills'] != null) {
                final bills = (managerData['bills'] as List<dynamic>).where((
                  bill,
                ) {
                  final billDateObj = _parseFirestoreDate(bill['billDate']);
                  if (billDateObj == null) return false;
                  return DateFormat('yyyy-MM-dd').format(billDateObj) ==
                      selectedDateStr;
                }).toList();

                managerRows.addAll(
                  bills.map<DataRow>((bill) {
                    String billDateStr = '-';
                    final parsedDate = _parseFirestoreDate(bill['billDate']);
                    if (parsedDate != null) {
                      billDateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
                    }
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            bill['billNo']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            bill['billVendor']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            bill['billAmount']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(billDateStr, style: TextStyle(color: textColor)),
                        ),
                      ],
                    );
                  }),
                );

                for (final bill in bills) {
                  if (bill['billAmount'] is num) {
                    managerTotal += bill['billAmount'] as num;
                  } else if (bill['billAmount'] is String) {
                    final parsed = double.tryParse(
                      bill['billAmount'].toString().replaceAll(
                        RegExp(r'[^0-9.]'),
                        '',
                      ),
                    );
                    if (parsed != null) managerTotal += parsed;
                  }
                }
              }
            }
          }

          // Organization Expenses Table
          List<DataRow> orgRows = [];
          num orgTotal = 0;
          if (orgEntries.isNotEmpty) {
            final selectedDateStr = DateFormat(
              'yyyy-MM-dd',
            ).format(widget.date);
            for (final doc in orgEntries) {
              final orgData = doc.data() as Map<String, dynamic>?;
              if (orgData != null && orgData['bills'] != null) {
                final bills = orgData['bills'] as List<dynamic>;
                final filteredBills = bills.where((bill) {
                  final billDateObj = _parseFirestoreDate(bill['billDate']);
                  if (billDateObj == null) return false;
                  return DateFormat('yyyy-MM-dd').format(billDateObj) ==
                      selectedDateStr;
                }).toList();
                orgRows.addAll(
                  filteredBills.map<DataRow>((bill) {
                    String billDate = '-';
                    final parsedDate = _parseFirestoreDate(bill['billDate']);
                    if (parsedDate != null) {
                      billDate = DateFormat('yyyy-MM-dd').format(parsedDate);
                    }
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            bill['billNo']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            bill['billVendor']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(
                            bill['billAmount']?.toString() ?? '-',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        DataCell(
                          Text(billDate, style: TextStyle(color: textColor)),
                        ),
                      ],
                    );
                  }),
                );

                for (final bill in filteredBills) {
                  if (bill['billAmount'] is num) {
                    orgTotal += bill['billAmount'] as num;
                  } else if (bill['billAmount'] is String) {
                    final parsed = double.tryParse(
                      bill['billAmount'].toString().replaceAll(
                        RegExp(r'[^0-9.]'),
                        '',
                      ),
                    );
                    if (parsed != null) orgTotal += parsed;
                  }
                }
              }
            }
          }

          final totalAmount =
              supervisorTotal + managerTotal + orgTotal + contractTotal;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.summarize, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'DAILY EXPENSE REPORT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,

                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildInfoRowWhite('Site ID', siteId),
                        _siteNameLoading
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Site Name:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _siteName != null && _siteName!.isNotEmpty
                            ? _buildInfoRowWhite('Site Name', _siteName!)
                            : SizedBox.shrink(),
                        _buildInfoRowWhite('Supervisor', supervisorName),
                        _buildInfoRowWhite(
                          'Project Stage',
                          widget.projectStage,
                        ),
                        _buildInfoRowWhite('Date', formattedDate),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                if (supervisorRows.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Site Supervisor Expenses',
                    Icons.engineering,
                  ),
                  SizedBox(height: 12),
                  _buildDataTable(
                    headerColor: primaryLightColor.withOpacity(0.2),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Type',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Item',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Quantity',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Unit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: supervisorRows,
                  ),
                  SizedBox(height: 16),
                  _buildSubtotalCard(
                    'Supervisor Total',
                    supervisorTotal,
                    primaryLightColor,
                  ),
                  SizedBox(height: 24),
                ],

                if (managerRows.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Manager Expenses',
                    Icons.manage_accounts,
                  ),
                  SizedBox(height: 12),
                  _buildDataTable(
                    headerColor: primaryLightColor.withOpacity(0.2),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Bill No',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Vendor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: managerRows,
                  ),
                  SizedBox(height: 16),
                  _buildSubtotalCard(
                    'Manager Total',
                    managerTotal,
                    primaryLightColor,
                  ),
                  SizedBox(height: 24),
                ],

                if (orgRows.isNotEmpty) ...[
                  _buildSectionHeader('Organization Expenses', Icons.business),
                  SizedBox(height: 12),
                  _buildDataTable(
                    headerColor: primaryLightColor.withOpacity(0.2),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Bill No',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Vendor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: orgRows,
                  ),
                  SizedBox(height: 16),
                  _buildSubtotalCard(
                    'Organization Total',
                    orgTotal,
                    primaryLightColor,
                  ),
                  SizedBox(height: 24),
                ],

                if (contractRows.isNotEmpty) ...[
                  _buildSectionHeader('Contract Expenses', Icons.handshake),
                  SizedBox(height: 12),
                  _buildDataTable(
                    headerColor: primaryLightColor.withOpacity(0.2),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Type',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Item',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Quantity',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Unit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: contractRows,
                  ),
                  SizedBox(height: 16),
                  _buildSubtotalCard(
                    'Contract Total',
                    contractTotal,
                    primaryLightColor,
                  ),
                  SizedBox(height: 24),
                ],

                // Grand Total Card
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryDarkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.summarize, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'GRAND TOTAL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // PDF Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.picture_as_pdf, size: 24),
                    label: Text(
                      'Generate PDF Report',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.4),
                    ),
                    onPressed: () async {
                      String? projectStage = widget.projectStage;
                      if (projectStage.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please select a valid project stage before generating the report.',
                            ),
                            backgroundColor: primaryColor,
                          ),
                        );
                        return;
                      }
                      final selectedDateStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(widget.date);
                      final supervisor = supervisorData;
                      num supervisorTotal = 0;
                      if (supervisor != null) {
                        final expenseFields = [
                          {'type': 'Food', 'key': 'food'},
                          {'type': 'Fuel', 'key': 'fuel'},
                          {'type': 'Transport', 'key': 'transport'},
                        ];
                        for (var field in expenseFields) {
                          if (supervisor.containsKey(field['key'])) {
                            supervisorTotal +=
                                num.tryParse(
                                  supervisor[field['key']].toString(),
                                ) ??
                                0;
                          }
                        }
                        final labours =
                            (supervisor['labours'] ?? []) as List<dynamic>;
                        for (var labour in labours) {
                          supervisorTotal +=
                              num.tryParse(
                                labour['amount']?.toString() ?? '0',
                              ) ??
                              0;
                        }
                        final materials =
                            (supervisor['materials'] ?? []) as List<dynamic>;
                        for (var material in materials) {
                          supervisorTotal +=
                              num.tryParse(
                                material['amount']?.toString() ?? '0',
                              ) ??
                              0;
                        }
                      }
                      List<Map<String, dynamic>> managerBills = [];
                      num managerTotal = 0;
                      for (var doc in managerEntries) {
                        final managerData = doc.data() as Map<String, dynamic>?;
                        if (managerData != null &&
                            managerData['bills'] != null) {
                          final bills = (managerData['bills'] as List<dynamic>)
                              .where((bill) {
                                final billDateObj = _parseFirestoreDate(
                                  bill['billDate'],
                                );
                                if (billDateObj == null) return false;
                                return DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(billDateObj) ==
                                    selectedDateStr;
                              })
                              .toList();
                          for (var bill in bills) {
                            managerBills.add(Map<String, dynamic>.from(bill));
                            managerTotal +=
                                num.tryParse(
                                  bill['billAmount']?.toString() ?? '0',
                                ) ??
                                0;
                          }
                        }
                      }
                      List<Map<String, dynamic>> orgBills = [];
                      num orgTotal = 0;
                      for (final doc in orgEntries) {
                        final orgData = doc.data() as Map<String, dynamic>?;
                        if (orgData != null && orgData['bills'] != null) {
                          final bills = orgData['bills'] as List<dynamic>;
                          final filteredBills = bills.where((bill) {
                            final billDateObj = _parseFirestoreDate(
                              bill['billDate'],
                            );
                            if (billDateObj == null) return false;
                            return DateFormat(
                                  'yyyy-MM-dd',
                                ).format(billDateObj) ==
                                selectedDateStr;
                          }).toList();
                          for (var bill in filteredBills) {
                            orgBills.add(Map<String, dynamic>.from(bill));
                            orgTotal +=
                                num.tryParse(
                                  bill['billAmount']?.toString() ?? '0',
                                ) ??
                                0;
                          }
                        }
                      }
                      List<Map<String, dynamic>> contractEntriesList = [];
                      num contractTotal = 0;
                      for (final doc in contractEntries) {
                        final contractData =
                            doc.data() as Map<String, dynamic>?;
                        if (contractData != null) {
                          contractEntriesList.add(
                            Map<String, dynamic>.from(contractData),
                          );
                          final expenseFields = [
                            {'type': 'Food', 'key': 'food'},
                            {'type': 'Fuel', 'key': 'fuel'},
                            {'type': 'Transport', 'key': 'transport'},
                          ];
                          for (var field in expenseFields) {
                            if (contractData.containsKey(field['key'])) {
                              contractTotal +=
                                  num.tryParse(
                                    contractData[field['key']].toString(),
                                  ) ??
                                  0;
                            }
                          }
                          final labours =
                              (contractData['labours'] ?? []) as List<dynamic>;
                          for (var labour in labours) {
                            contractTotal +=
                                num.tryParse(
                                  labour['amount']?.toString() ?? '0',
                                ) ??
                                0;
                          }
                          final materials =
                              (contractData['materials'] ?? [])
                                  as List<dynamic>;
                          for (var material in materials) {
                            contractTotal +=
                                num.tryParse(
                                  material['amount']?.toString() ?? '0',
                                ) ??
                                0;
                          }
                        }
                      }
                      final grandTotal =
                          supervisorTotal +
                          managerTotal +
                          orgTotal +
                          contractTotal;
                      final pdfBytes = await _generatePdf(
                        supervisorData: supervisor,
                        managerBills: managerBills,
                        orgBills: orgBills,
                        supervisorTotal: supervisorTotal,
                        managerTotal: managerTotal,
                        orgTotal: orgTotal,
                        contractTotal: contractTotal,
                        grandTotal: grandTotal,
                        contractEntries: contractEntriesList,
                      );
                      await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                    },
                  ),
                ),

                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textLightColor,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWhite(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Icon(Icons.arrow_forward_ios, color: primaryColor, size: 16),
        ],
      ),
    );
  }

  Widget _buildDataTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    Color? headerColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowHeight: 40,
          horizontalMargin: 16,
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(
            headerColor ?? primaryLightColor.withOpacity(0.2),
          ),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildSubtotalCard(String label, num amount, Color color) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '$label: ₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf({
    required Map<String, dynamic>? supervisorData,
    required List<Map<String, dynamic>> managerBills,
    required List<Map<String, dynamic>> orgBills,
    required num supervisorTotal,
    required num managerTotal,
    required num orgTotal,
    required num contractTotal,
    required num grandTotal,
    required List<Map<String, dynamic>> contractEntries,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text(
            'ProjectStage Daily Site Expenses Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Supervisor ID: ${widget.supervisorId}'),
          pw.Text('Site ID: ${widget.siteId ?? "N/A"}'),
          pw.Text('Project Stage: ${widget.projectStage}'),
          pw.Text('Date: $formattedDate'),
          pw.SizedBox(height: 16),

          // Supervisor Section
          if (supervisorData != null) ...[
            pw.Text(
              'Site Supervisor Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfSupervisorTable(supervisorData),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Supervisor Total: ₹$supervisorTotal',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Manager Section
          if (managerBills.isNotEmpty) ...[
            pw.Text(
              'Manager Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfBillsTable(managerBills),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Manager Total: ₹$managerTotal',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Organization Section
          if (orgBills.isNotEmpty) ...[
            pw.Text(
              'Organization Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfBillsTable(orgBills),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Organization Total: ₹$orgTotal',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Contractor Section
          if (contractEntries.isNotEmpty) ...[
            pw.Text(
              'Contractor Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfContractorTable(contractEntries),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Contractor Total: ₹$contractTotal',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Grand Total
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF4CAF50),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Grand Total',
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xFFFFFFFF),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '₹$grandTotal',
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xFFFFFFFF),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfContractorTable(List<Map<String, dynamic>> entries) {
    final tableRows = <List<String>>[];
    for (final entry in entries) {
      // Expense fields
      final expenseFields = [
        {'type': 'Food', 'key': 'food'},
        {'type': 'Fuel', 'key': 'fuel'},
        {'type': 'Transport', 'key': 'transport'},
      ];
      for (var field in expenseFields) {
        if (entry.containsKey(field['key'])) {
          tableRows.add([
            'Expense',
            field['type']!,
            '-',
            '-',
            '${entry[field['key']]}',
          ]);
        }
      }
      // Labours
      final labours = (entry['labours'] ?? []) as List<dynamic>;
      for (var labour in labours) {
        tableRows.add([
          'Labour',
          labour['type'] ?? '',
          '${labour['count'] ?? ''}',
          '${labour['unitSalary'] ?? ''}',
          '${labour['amount'] ?? ''}',
        ]);
      }
      // Materials
      final materials = (entry['materials'] ?? []) as List<dynamic>;
      for (var material in materials) {
        tableRows.add([
          'Material',
          material['type'] ?? '',
          '${material['quantity'] ?? ''}',
          '${material['unitPrice'] ?? ''}',
          '${material['amount'] ?? ''}',
        ]);
      }
    }
    return pw.Table.fromTextArray(
      headers: ['Type', 'Item', 'Quantity', 'Unit', 'Amount'],
      data: tableRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
    );
  }

  pw.Widget _pdfSupervisorTable(Map<String, dynamic> data) {
    final labours = (data['labours'] ?? []) as List<dynamic>;
    final materials = (data['materials'] ?? []) as List<dynamic>;
    final expenseFields = [
      {'type': 'Food', 'key': 'food'},
      {'type': 'Fuel', 'key': 'fuel'},
      {'type': 'Transport', 'key': 'transport'},
    ];
    final tableRows = <List<String>>[];
    for (var field in expenseFields) {
      if (data.containsKey(field['key'])) {
        tableRows.add([
          'Expense',
          field['type']!,
          '-',
          '-',
          '${data[field['key']]}',
        ]);
      }
    }
    for (var labour in labours) {
      tableRows.add([
        'Labour',
        labour['type'] ?? '',
        '${labour['count'] ?? ''}',
        '${labour['unitSalary'] ?? ''}',
        '${labour['amount'] ?? ''}',
      ]);
    }
    for (var material in materials) {
      tableRows.add([
        'Material',
        material['type'] ?? '',
        '${material['quantity'] ?? ''}',
        '${material['unitPrice'] ?? ''}',
        '${material['amount'] ?? ''}',
      ]);
    }
    return pw.Table.fromTextArray(
      headers: ['Type', 'Item', 'Quantity', 'Unit', 'Amount'],
      data: tableRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
    );
  }
}
