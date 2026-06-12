import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class SiteExpensesReportPage extends StatefulWidget {
  final String siteId;
  final DateTime fromDate;
  final DateTime toDate;
  final String? projectStage;

  const SiteExpensesReportPage({
    super.key,
    required this.siteId,
    required this.fromDate,
    required this.toDate,
    required String supervisorId,
    this.projectStage,
  });

  @override
  State<SiteExpensesReportPage> createState() => _SiteExpensesReportPageState();
}

class _SiteExpensesReportPageState extends State<SiteExpensesReportPage> {
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get accentColor => Theme.of(context).colorScheme.secondary;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF2c3e50);
  Color get cardColor => Theme.of(context).cardColor;
  Color get successColor => const Color(0xFF2e7d32);
  Color get warningColor => const Color(0xFFed6c02);

  Future<List<Map<String, dynamic>>>? _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _fetchEntriesForRange();
  }

  /// Fetches supervisor, manager, organization, and contractor entries for each date in range.
  Future<List<Map<String, dynamic>>> _fetchEntriesForRange() async {
    final List<Map<String, dynamic>> entries = [];
    final DateFormat docIdDateFormat = DateFormat('ddMMyyyy');
    final DateFormat displayDateFormat = DateFormat('dd-MM-yy');

    DateTime current = widget.fromDate;
    while (!current.isAfter(widget.toDate)) {
      final docId = '${widget.siteId}_${docIdDateFormat.format(current)}';

      // Supervisor entry
      final supervisorDoc = await FirestoreService.getCollection(
        'siteSupervisorEntries',
      ).doc(docId).get();
      Map<String, dynamic>? supervisorData;
      if (supervisorDoc.exists) {
        final data = supervisorDoc.data() as Map<String, dynamic>?;
        if (widget.projectStage != null) {
          final docStage = (data?['projectStage'] ?? data?['projectField'])
              ?.toString()
              .trim();
          if (docStage == widget.projectStage?.trim()) {
            supervisorData = data;
          }
        } else {
          supervisorData = data;
        }
      }

      // Manager bills for this date
      final managerQuery = await FirestoreService.getCollection(
        'managerExpenses',
      ).where('siteId', isEqualTo: widget.siteId).get();
      List<Map<String, dynamic>> managerBills = [];
      for (final doc in managerQuery.docs) {
        final data = doc.data();
        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        if (data['bills'] != null) {
          for (final bill in data['bills']) {
            DateTime? billDateObj;
            if (bill['billDate'] is String) {
              billDateObj = DateTime.tryParse(bill['billDate']);
            } else if (bill['billDate'] is Timestamp) {
              billDateObj = bill['billDate'].toDate();
            }
            if (billDateObj != null &&
                billDateObj.year == current.year &&
                billDateObj.month == current.month &&
                billDateObj.day == current.day) {
              managerBills.add(Map<String, dynamic>.from(bill));
            }
          }
        }
      }

      // Organization bills for this date
      final orgQuery = await FirestoreService.getCollection(
        'organizationEntries',
      ).where('siteId', isEqualTo: widget.siteId).get();
      List<Map<String, dynamic>> orgBills = [];
      for (final doc in orgQuery.docs) {
        final data = doc.data();
        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        if (data['bills'] != null) {
          for (final bill in data['bills']) {
            DateTime? billDateObj;
            if (bill['billDate'] is String) {
              billDateObj = DateTime.tryParse(bill['billDate']);
            } else if (bill['billDate'] is Timestamp) {
              billDateObj = bill['billDate'].toDate();
            }
            if (billDateObj != null &&
                billDateObj.year == current.year &&
                billDateObj.month == current.month &&
                billDateObj.day == current.day) {
              orgBills.add(Map<String, dynamic>.from(bill));
            }
          }
        }
      }

      // Contractor expenses for this date
      Query<Map<String, dynamic>> contractorQuery =
          FirestoreService.getCollection('contractorEntries')
              .where('siteId', isEqualTo: widget.siteId)
              .where(
                'date',
                isEqualTo: DateFormat('yyyy-MM-dd').format(current),
              );

      final contractorSnapshot = await contractorQuery.get();
      List<Map<String, dynamic>> contractorEntries = [];
      for (final doc in contractorSnapshot.docs) {
        final data = doc.data();
        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }
        contractorEntries.add(data);
      }

      final hasSupervisor =
          supervisorData != null && (supervisorData['totalAmount'] ?? 0) != 0;
      final hasManager = managerBills.isNotEmpty;
      final hasOrg = orgBills.isNotEmpty;
      final hasContractor = contractorEntries.isNotEmpty;

      if (hasSupervisor || hasManager || hasOrg || hasContractor) {
        entries.add({
          'date': displayDateFormat.format(current),
          'supervisorData': supervisorData,
          'managerBills': managerBills,
          'orgBills': orgBills,
          'contractorEntries': contractorEntries,
        });
      }
      current = current.add(const Duration(days: 1));
    }
    return entries;
  }

  Future<void> _generateAndPreviewPDF(
    List<Map<String, dynamic>> entries,
    num grandTotal,
  ) async {
    final pdf = pw.Document();
    final DateFormat displayDateFormat = DateFormat('dd-MMM-yyyy');
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Site Expenses Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Site ID',
                widget.siteId,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Year',
                widget.fromDate.year.toString(),
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Date Range',
                '${displayDateFormat.format(widget.fromDate)} - ${displayDateFormat.format(widget.toDate)}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          ...entries.map((entry) {
            num supervisorTotal = 0;
            if (entry['supervisorData'] != null &&
                entry['supervisorData']['totalAmount'] != null) {
              supervisorTotal = entry['supervisorData']['totalAmount'] is num
                  ? entry['supervisorData']['totalAmount']
                  : num.tryParse(
                          entry['supervisorData']['totalAmount'].toString(),
                        ) ??
                        0;
            }

            num managerTotal = 0;
            for (final bill in (entry['managerBills'] ?? [])) {
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

            num orgTotal = 0;
            for (final bill in (entry['orgBills'] ?? [])) {
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

            num contractorTotal = 0;
            final contractorEntries = entry['contractorEntries'] ?? [];
            for (final contractor in contractorEntries) {
              if (contractor['totalAmount'] is num) {
                contractorTotal += contractor['totalAmount'] as num;
              } else if (contractor['totalAmount'] is String) {
                final parsed = double.tryParse(
                  contractor['totalAmount'].toString().replaceAll(
                    RegExp(r'[^0-9.]'),
                    '',
                  ),
                );
                if (parsed != null) contractorTotal += parsed;
              }
            }

            num dateTotal =
                supervisorTotal + managerTotal + orgTotal + contractorTotal;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.grey100,
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Date: ${entry['date']}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (entry['supervisorData'] != null)
                    pw.Text(
                      'Site Entries Total: Rs. $supervisorTotal',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  if ((entry['managerBills'] as List).isNotEmpty)
                    pw.Text(
                      'Manager Expenses Total: Rs. $managerTotal',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  if ((entry['orgBills'] as List).isNotEmpty)
                    pw.Text(
                      'Organization Expenses Total: Rs. $orgTotal',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  if (contractorEntries.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Contractor Expenses:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        ...contractorEntries.map<pw.Widget>((contractor) {
                          final labors =
                              contractor['labours'] as List<dynamic>? ?? [];
                          final materials =
                              contractor['materials'] as List<dynamic>? ?? [];
                          return pw.Container(
                            margin: const pw.EdgeInsets.symmetric(vertical: 6),
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400),
                              borderRadius: pw.BorderRadius.circular(6),
                              color: PdfColors.white,
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Contractor: ${contractor['contractorName'] ?? '-'} | Project: ${contractor['projectField'] ?? '-'}',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  'Food: Rs. ${contractor['food'] ?? 0} | Fuel: Rs. ${contractor['fuel'] ?? 0} | Transport: Rs. ${contractor['transport'] ?? 0}',
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Labours:',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Column(
                                  children: labors.map<pw.Widget>((labour) {
                                    return pw.Text(
                                      '${labour['type']}: ${labour['count']} x Rs. ${labour['unitSalary']} = Rs. ${labour['amount']}',
                                    );
                                  }).toList(),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Materials:',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Column(
                                  children: materials.map<pw.Widget>((
                                    material,
                                  ) {
                                    return pw.Text(
                                      '${material['type']}: ${material['quantity']} x Rs. ${material['unitPrice']} = Rs. ${material['amount']}',
                                    );
                                  }).toList(),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Total Amount: Rs. ${contractor['totalAmount'] ?? 0}',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Total Amount: Rs. $dateTotal',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: pdfPrimaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Grand Total:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Rs. ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Site Expenses Report',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderInfo(),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _entriesFuture ??= _fetchEntriesForRange(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        'No data found for the selected range.',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }
                  // Calculate grand total
                  num grandTotal = 0;
                  List<Widget> cards = [];
                  for (final entry in entries) {
                    num supervisorTotal = 0;
                    if (entry['supervisorData'] != null &&
                        entry['supervisorData']['totalAmount'] != null) {
                      supervisorTotal =
                          entry['supervisorData']['totalAmount'] is num
                          ? entry['supervisorData']['totalAmount']
                          : num.tryParse(
                                  entry['supervisorData']['totalAmount']
                                      .toString(),
                                ) ??
                                0;
                    }
                    num managerTotal = 0;
                    for (final bill in (entry['managerBills'] ?? [])) {
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
                    num orgTotal = 0;
                    for (final bill in (entry['orgBills'] ?? [])) {
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
                    num contractorTotal = 0;
                    final contractorEntries = entry['contractorEntries'] ?? [];
                    for (final contractor in contractorEntries) {
                      if (contractor['totalAmount'] is num) {
                        contractorTotal += contractor['totalAmount'] as num;
                      } else if (contractor['totalAmount'] is String) {
                        final parsed = double.tryParse(
                          contractor['totalAmount'].toString().replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ),
                        );
                        if (parsed != null) contractorTotal += parsed;
                      }
                    }
                    num dateTotal =
                        supervisorTotal +
                        managerTotal +
                        orgTotal +
                        contractorTotal;
                    grandTotal += dateTotal;

                    cards.add(
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border(
                            left: BorderSide(color: primaryColor, width: 6),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      entry['date'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.receipt_long, color: primaryColor),
                                ],
                              ),
                              SizedBox(height: 16),
                              _buildSection(
                                'Site Entries',
                                entry['supervisorData'],
                                isSupervisor: true,
                              ),
                              SizedBox(height: 12),
                              _buildSection(
                                'Manager Expenses',
                                entry['managerBills'],
                              ),
                              SizedBox(height: 12),
                              _buildSection(
                                'Organization Expenses',
                                entry['orgBills'],
                              ),
                              SizedBox(height: 12),
                              _buildContractorSection(
                                'Contractor Expenses',
                                contractorEntries,
                              ),
                              SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Total Amount: Rs. $dateTotal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  // Add grand total at the end
                  cards.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Card(
                        color: primaryColor.withOpacity(0.1),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: primaryColor, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              'Grand Total: Rs. $grandTotal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  // Add Generate PDF button at the end
                  cards.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0, top: 0),
                      child: Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: Icon(Icons.picture_as_pdf, size: 24),
                          label: Text(
                            'Generate PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () async {
                            await _generateAndPreviewPDF(entries, grandTotal);
                          },
                        ),
                      ),
                    ),
                  );
                  return ListView.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) => cards[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final DateFormat displayDateFormat = DateFormat('dd-MMM-yyyy');
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                Icon(Icons.location_on, color: primaryColor, size: 24),
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
            _buildInfoRow('Site', widget.siteId),
            _buildInfoRow('Year', widget.fromDate.year.toString()),
            _buildInfoRow('From', displayDateFormat.format(widget.fromDate)),
            _buildInfoRow('To', displayDateFormat.format(widget.toDate)),
          ],
        ),
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
            width: 60,
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
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    dynamic data, {
    bool isSupervisor = false,
  }) {
    if (isSupervisor) {
      if (data == null) {
        return _noDataSection(title);
      }
      final total = data['totalAmount'] ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryColor,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Total: Rs. $total',
            style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
          ),
        ],
      );
    } else if (data is List && data.isNotEmpty) {
      num total = 0;
      for (final bill in data) {
        if (bill['billAmount'] is num) {
          total += bill['billAmount'] as num;
        } else if (bill['billAmount'] is String) {
          final parsed = double.tryParse(
            bill['billAmount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''),
          );
          if (parsed != null) total += parsed;
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryColor,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                primaryColor.withOpacity(0.1),
              ),
              columns: [
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
              rows: data.map<DataRow>((bill) {
                String billDate = '-';
                if (bill['billDate'] != null) {
                  if (bill['billDate'] is String) {
                    try {
                      billDate = DateFormat(
                        'dd-MM-yy',
                      ).format(DateTime.parse(bill['billDate']));
                    } catch (_) {}
                  } else if (bill['billDate'] is Timestamp) {
                    billDate = DateFormat(
                      'dd-MM-yy',
                    ).format((bill['billDate'] as Timestamp).toDate());
                  }
                }
                return DataRow(
                  cells: [
                    DataCell(Text(bill['billNo']?.toString() ?? '-')),
                    DataCell(Text(bill['billVendor']?.toString() ?? '-')),
                    DataCell(
                      Text('Rs. ${bill['billAmount']?.toString() ?? '-'}'),
                    ),
                    DataCell(Text(billDate)),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: Rs. $total',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: primaryColor,
              ),
            ),
          ),
        ],
      );
    } else {
      return _noDataSection(title);
    }
  }

  Widget _buildContractorSection(
    String title,
    List<dynamic> contractorEntries,
  ) {
    if (contractorEntries.isEmpty) {
      return _noDataSection(title);
    }
    num total = 0;
    for (final c in contractorEntries) {
      if (c['totalAmount'] is num) {
        total += c['totalAmount'] as num;
      } else if (c['totalAmount'] is String) {
        final parsed = double.tryParse(
          c['totalAmount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (parsed != null) total += parsed;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: primaryColor,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Total: Rs. $total',
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
        ),
      ],
    );
  }

  Widget _noDataSection(String title) {
    return Text(
      '$title: No data',
      style: TextStyle(color: warningColor, fontStyle: FontStyle.italic),
    );
  }
}
