import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DailySiteExpensesReportPage extends StatefulWidget {
  final String supervisorId;
  final String? siteId;
  final DateTime date;

  const DailySiteExpensesReportPage({
    super.key,
    required this.supervisorId,
    required this.siteId,
    required this.date,
  });

  @override
  State<DailySiteExpensesReportPage> createState() =>
      _DailySiteExpensesReportPageState();
}

class _DailySiteExpensesReportPageState
    extends State<DailySiteExpensesReportPage> {
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4a7cda);
  static const Color backgroundColor = Color(0xFFf8f9fa);
  static const Color textColor = Color(0xFF2c3e50);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF2e7d32);
  static const Color warningColor = Color(0xFFed6c02);

  String get _documentId {
    final formattedDate = DateFormat('ddMMyyyy').format(widget.date);
    return '${widget.siteId}_$formattedDate';
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

    // Contractor Expenses
    final contractorQuery = await FirebaseFirestore.instance
        .collection('contractorEntries')
        .where('siteId', isEqualTo: widget.siteId)
        .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(widget.date))
        .get();
    final allContractorDocs = contractorQuery.docs;

    // Incentive Expenses
    final incentiveQuery = await FirebaseFirestore.instance
        .collection('totalSiteExpensesPerDay')
        .where('siteId', isEqualTo: widget.siteId)
        .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(widget.date))
        .get();
    final incentiveDoc = (incentiveQuery.docs.isNotEmpty)
        ? incentiveQuery.docs.first
        : null;

    return {
      'supervisor': supervisorDoc.exists ? supervisorDoc : null,
      'managerEntries': allManagerDocs,
      'organizationEntries': allOrgDocs,
      'contractorEntries': allContractorDocs,
      'incentiveDoc': incentiveDoc,
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

  // PDF generation function for all details
  Future<Uint8List> _generatePdf({
    required Map<String, dynamic>? supervisorData,
    required List<Map<String, dynamic>> managerBills,
    required List<Map<String, dynamic>> orgBills,
    required List<Map<String, dynamic>> contractorBills,
    required num supervisorTotal,
    required num managerTotal,
    required num orgTotal,
    required num contractorTotal,
    required num grandTotal,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text(
            'Daily Site Expenses Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Supervisor ID: ${widget.supervisorId}'),
          pw.Text('Site ID: ${widget.siteId ?? "N/A"}'),
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
          if (contractorBills.isNotEmpty) ...[
            pw.Text(
              'Contractor Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfContractorTable(contractorBills),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Contractor Total: ₹$contractorTotal',
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
                color: PdfColor.fromInt(primaryColor.value),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Grand Total',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '₹$grandTotal',
                    style: pw.TextStyle(
                      color: PdfColors.white,
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

  pw.Widget _pdfBillsTable(List<Map<String, dynamic>> bills) {
    final tableRows = bills.map((bill) {
      String billDate = '-';
      if (bill['billDate'] != null) {
        if (bill['billDate'] is String) {
          billDate = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.parse(bill['billDate']));
        } else if (bill['billDate'] is Timestamp) {
          billDate = DateFormat(
            'yyyy-MM-dd',
          ).format((bill['billDate'] as Timestamp).toDate());
        }
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

  pw.Widget _pdfContractorTable(List<Map<String, dynamic>> contractorBills) {
    final tableRows = <List<String>>[];

    for (var bill in contractorBills) {
      // Construct rows for expenses, labours and materials similar to supervisor
      if (bill.isEmpty) continue;

      // Expenses
      final expenseFields = [
        {'type': 'Food', 'key': 'food'},
        {'type': 'Fuel', 'key': 'fuel'},
        {'type': 'Transport', 'key': 'transport'},
      ];
      for (var field in expenseFields) {
        if (bill.containsKey(field['key'])) {
          tableRows.add([
            'Expense',
            field['type']!,
            '-',
            '-',
            '${bill[field['key']]}',
          ]);
        }
      }

      // Labours
      final labours = bill['labours'] ?? [];
      for (var labour in labours) {
        tableRows.add([
          'Labour',
          labour['type']?.toString() ?? '',
          labour['count']?.toString() ?? '',
          '', // unit - skipping for contractor table for simplicity
          labour['amount']?.toString() ?? '',
        ]);
      }

      // Materials
      final materials = bill['materials'] ?? [];
      for (var material in materials) {
        tableRows.add([
          'Material',
          material['type']?.toString() ?? '',
          material['quantity']?.toString() ?? '',
          '', // unitPrice skipped for PDF preview simplicity
          material['amount']?.toString() ?? '',
        ]);
      }
    }
    return pw.Table.fromTextArray(
      headers: ['Type', 'Item', 'Quantity', 'Unit', 'Amount'],
      data: tableRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFD1C4E9)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Daily Site Expenses Report',
          style: TextStyle(
            
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(),
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }
          final supervisorDoc = snapshot.data?['supervisor'];
          final managerEntries =
              snapshot.data?['managerEntries'] as List<DocumentSnapshot>;
          final orgEntries =
              snapshot.data?['organizationEntries'] as List<DocumentSnapshot>;
          final contractorEntries =
              snapshot.data?['contractorEntries'] as List<DocumentSnapshot>;
          final incentiveDoc = snapshot.data?['incentiveDoc'];

          if (supervisorDoc == null &&
              (managerEntries.isEmpty) &&
              (orgEntries.isEmpty) &&
              (contractorEntries.isEmpty) &&
              incentiveDoc == null) {
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
                      Icon(Icons.receipt_long, size: 48, color: primaryColor),
                      SizedBox(height: 16),
                      Text(
                        'No report found for this date.',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Extract data
          final supervisorData = supervisorDoc?.data() as Map<String, dynamic>?;

          final orgData = (orgEntries.isNotEmpty)
              ? orgEntries.first.data() as Map<String, dynamic>?
              : null;

          // Top section info
          final managerData =
              (managerEntries.isNotEmpty)
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
          final projectName =
              supervisorData?['projectName'] ??
              managerData?['projectName'] ??
              orgData?['projectName'] ??
              '-';

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
                  final billDate = bill['billDate'];
                  if (billDate == null) return false;
                  DateTime? billDateObj;
                  if (billDate is String) {
                    billDateObj = DateTime.tryParse(billDate);
                  } else if (billDate is Timestamp) {
                    billDateObj = billDate.toDate();
                  }
                  return billDateObj != null &&
                      DateFormat('yyyy-MM-dd').format(billDateObj) ==
                          selectedDateStr;
                }).toList();
                managerRows.addAll(
                  bills.map<DataRow>((bill) {
                    String billDateStr = '-';
                    final billDate = bill['billDate'];
                    if (billDate != null) {
                      DateTime? billDateObj;
                      if (billDate is String) {
                        billDateObj = DateTime.tryParse(billDate);
                      } else if (billDate is Timestamp) {
                        billDateObj = billDate.toDate();
                      }
                      if (billDateObj != null) {
                        billDateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(billDateObj);
                      }
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
                // Sum up only the displayed bills
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
                  final billDate = bill['billDate'];
                  DateTime? billDateObj;
                  if (billDate is String) {
                    billDateObj = DateTime.tryParse(billDate);
                  } else if (billDate is Timestamp) {
                    billDateObj = billDate.toDate();
                  }
                  return billDateObj != null &&
                      DateFormat('yyyy-MM-dd').format(billDateObj) ==
                          selectedDateStr;
                }).toList();
                orgRows.addAll(
                  filteredBills.map<DataRow>((bill) {
                    String billDate = '-';
                    if (bill['billDate'] != null) {
                      if (bill['billDate'] is String) {
                        billDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.parse(bill['billDate']));
                      } else if (bill['billDate'] is Timestamp) {
                        billDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format((bill['billDate'] as Timestamp).toDate());
                      }
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
                // Sum up totals for filtered bills only
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

          // Contractor Expenses Table
          List<DataRow> contractorRows = [];
          num contractorTotal = 0;
          if (contractorEntries.isNotEmpty) {
            for (final doc in contractorEntries) {
              final contractorData = doc.data() as Map<String, dynamic>?;
              if (contractorData != null) {
                contractorRows.addAll([
                  ..._buildExpenseRows(contractorData),
                  ..._buildLabourRows(contractorData['labours'] ?? []),
                  ..._buildMaterialRows(contractorData['materials'] ?? []),
                ]);
                contractorTotal += contractorData['totalAmount'] ?? 0;
              }
            }
          }

          // Incentive Expenses Data
          num incentiveTotal = 0;
          if (incentiveDoc != null) {
            final incentiveData = incentiveDoc.data() as Map<String, dynamic>?;
            incentiveTotal = incentiveData?['totalIncentiveExpenses'] ?? 0;
          }

          final totalAmount =
              (supervisorTotal is num ? supervisorTotal : 0) +
              (managerTotal is num ? managerTotal : 0) +
              (orgTotal is num ? orgTotal : 0) +
              (contractorTotal is num ? contractorTotal : 0) +
              (incentiveTotal is num ? incentiveTotal : 0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment,
                              color: primaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Report Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildInfoRow('Site ID', siteId),
                        _buildInfoRow('Supervisor', supervisorName),
                        _buildInfoRow('Project', projectName),
                        _buildInfoRow('Date', formattedDate),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                if (supervisorRows.isNotEmpty) ...[
                  _buildSectionHeader('Site Supervisor Expenses'),
                  SizedBox(height: 12),
                  _buildDataTable(
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
                  _buildSubtotalCard('Supervisor Total', supervisorTotal),
                  SizedBox(height: 24),
                ],

                if (managerRows.isNotEmpty) ...[
                  _buildSectionHeader('Manager Expenses'),
                  SizedBox(height: 12),
                  _buildDataTable(
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
                  _buildSubtotalCard('Manager Total', managerTotal),
                  SizedBox(height: 24),
                ],

                if (orgRows.isNotEmpty) ...[
                  _buildSectionHeader('Organization Expenses'),
                  SizedBox(height: 12),
                  _buildDataTable(
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
                  _buildSubtotalCard('Organization Total', orgTotal),
                  SizedBox(height: 24),
                ],

                if (contractorRows.isNotEmpty) ...[
                  _buildSectionHeader('Contractor Expenses'),
                  SizedBox(height: 12),
                  _buildDataTable(
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
                    rows: contractorRows,
                  ),
                  SizedBox(height: 16),
                  _buildSubtotalCard('Contractor Total', contractorTotal),
                  SizedBox(height: 24),
                ],

                // Grand Total Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.summarize,  size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Grand Total',
                          style: TextStyle(
                            
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '₹$totalAmount',
                          style: TextStyle(
                            
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // PDF Button
                Center(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      Icons.picture_as_pdf,
                      
                      size: 20,
                    ),
                    label: Text(
                      'Generate PDF Report',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () async {
                      // Gather all data for PDF
                      final selectedDateStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(widget.date);
                      // Supervisor
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
                      // Manager
                      List<Map<String, dynamic>> managerBills = [];
                      num managerTotal = 0;
                      for (var doc in managerEntries) {
                        final managerData = doc.data() as Map<String, dynamic>?;
                        if (managerData != null &&
                            managerData['bills'] != null) {
                          final bills = (managerData['bills'] as List<dynamic>)
                              .where((bill) {
                                final billDate = bill['billDate'];
                                if (billDate == null) return false;
                                DateTime? billDateObj;
                                if (billDate is String) {
                                  billDateObj = DateTime.tryParse(billDate);
                                } else if (billDate is Timestamp) {
                                  billDateObj = billDate.toDate();
                                }
                                return billDateObj != null &&
                                    DateFormat(
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
                      // Organization
                      List<Map<String, dynamic>> orgBills = [];
                      num orgTotal = 0;
                      for (final doc in orgEntries) {
                        final orgData = doc.data() as Map<String, dynamic>?;
                        if (orgData != null && orgData['bills'] != null) {
                          final bills = orgData['bills'] as List<dynamic>;
                          final filteredBills = bills.where((bill) {
                            final billDate = bill['billDate'];
                            DateTime? billDateObj;
                            if (billDate is String) {
                              billDateObj = DateTime.tryParse(billDate);
                            } else if (billDate is Timestamp) {
                              billDateObj = billDate.toDate();
                            }
                            return billDateObj != null &&
                                DateFormat('yyyy-MM-dd').format(billDateObj) ==
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

                      // Contractor
                      List<Map<String, dynamic>> contractorBills = [];
                      num contractorTotal = 0;
                      for (final doc in contractorEntries) {
                        final contractorData =
                            doc.data() as Map<String, dynamic>?;
                        if (contractorData != null) {
                          contractorBills.add(contractorData);
                          contractorTotal += contractorData['totalAmount'] ?? 0;
                        }
                      }

                      final grandTotal =
                          supervisorTotal +
                          managerTotal +
                          orgTotal +
                          contractorTotal;

                      final pdfBytes = await _generatePdf(
                        supervisorData: supervisor,
                        managerBills: managerBills,
                        orgBills: orgBills,
                        contractorBills: contractorBills,
                        supervisorTotal: supervisorTotal,
                        managerTotal: managerTotal,
                        orgTotal: orgTotal,
                        contractorTotal: contractorTotal,
                        grandTotal: grandTotal,
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowHeight: 40,
          horizontalMargin: 16,
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(
            primaryColor.withOpacity(0.1),
          ),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildSubtotalCard(String label, num amount) {
    return Align(
      alignment: Alignment.centerRight,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: primaryColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '$label: ₹$amount',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
