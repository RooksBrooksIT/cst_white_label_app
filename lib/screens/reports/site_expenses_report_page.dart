import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '/utils/pdf_templates.dart';
import '/widgets/glass_card.dart';
import '/utils/app_theme.dart';

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

  /// Fetches supervisor, manager, organization, contractor, and incentive entries for each date in range.
  Future<List<Map<String, dynamic>>> _fetchEntriesForRange() async {
    final List<Map<String, dynamic>> entries = [];
    final DateFormat displayDateFormat = DateFormat('dd-MM-yy');

    final siteKeys =
        (await ExpenseService.resolveSiteKeys(widget.siteId)).toList();
    final keysToQuery = siteKeys.take(10).toList();

    if (keysToQuery.isEmpty) return entries;

    // 1. Fetch all collections in parallel up front for high performance
    final fetchResults = await Future.wait([
      // 0, 1: Supervisor entries
      FirestoreService.getCollection('siteSupervisorEntries').where('siteId', whereIn: keysToQuery).get(),
      FirestoreService.getCollection('siteSupervisorEntries').where('site', whereIn: keysToQuery).get(),
      // 2, 3: Manager expenses & entries
      FirestoreService.getCollection('managerExpenses').where('siteId', whereIn: keysToQuery).get(),
      FirestoreService.getCollection('managerEntries').where('siteId', whereIn: keysToQuery).get(),
      // 4, 5: Organization entries & expenses
      FirestoreService.getCollection('organizationEntries').where('siteId', whereIn: keysToQuery).get(),
      FirestoreService.getCollection('organizationExpenses').where('siteId', whereIn: keysToQuery).get(),
      // 6: Contractor entries
      FirestoreService.getCollection('contractorEntries').where('siteId', whereIn: keysToQuery).get(),
      // 7, 8: Incentives & Totals
      FirestoreService.siteSupervisorIncentives.where('siteId', whereIn: keysToQuery).get(),
      FirestoreService.getCollection('totalSiteExpensesPerDay').where('siteId', whereIn: keysToQuery).get(),
    ]);

    final allSupDocs = {...fetchResults[0].docs, ...fetchResults[1].docs};
    final allMgrDocs = {...fetchResults[2].docs, ...fetchResults[3].docs};
    final allOrgDocs = {...fetchResults[4].docs, ...fetchResults[5].docs};
    final allContractorDocs = fetchResults[6].docs;
    final allIncentiveDocs = {...fetchResults[7].docs, ...fetchResults[8].docs};

    final allPettyCash = await ExpenseService.fetchPettyCashForSite(
      siteId: widget.siteId,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      projectStage: widget.projectStage,
    );

    DateTime current = widget.fromDate;
    while (!current.isAfter(widget.toDate)) {
      final docIdDateCompact = DateFormat('ddMMyyyy').format(current);

      // 1. Match supervisor entry for current date
      Map<String, dynamic>? supervisorData;
      // First check doc ID matches (e.g. ST001_19092026)
      for (final doc in allSupDocs) {
        final data = doc.data();
        if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
          continue;
        }
        for (final k in siteKeys) {
          if (doc.id == '${k}_$docIdDateCompact' || doc.id.toLowerCase() == '${k.toLowerCase()}_$docIdDateCompact') {
            if (widget.projectStage != null) {
              final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
              if (docStage == widget.projectStage?.trim()) {
                supervisorData = data;
                break;
              }
            } else {
              supervisorData = data;
              break;
            }
          }
        }
        if (supervisorData != null) break;
      }

      // If not matched by doc ID, match by date field
      if (supervisorData == null) {
        for (final doc in allSupDocs) {
          final data = doc.data();
          if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
              data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
            continue;
          }
          if (ExpenseService.isSameDay(data['date'] ?? data['createdAt'], current)) {
            if (widget.projectStage != null) {
              final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
              if (docStage == widget.projectStage?.trim()) {
                supervisorData = data;
                break;
              }
            } else {
              supervisorData = data;
              break;
            }
          }
        }
      }

      // 2. Match Manager bills for current date
      final List<Map<String, dynamic>> managerBills = [];
      for (final doc in allMgrDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          for (final bill in bills) {
            if (bill is Map && ExpenseService.isSameDay(bill['billDate'] ?? bill['date'], current)) {
              managerBills.add(Map<String, dynamic>.from(bill));
            }
          }
        } else if (data['totalAmount'] != null || data['amount'] != null) {
          if (ExpenseService.isSameDay(data['date'] ?? data['entryDate'] ?? data['createdAt'], current)) {
            managerBills.add({
              'billNo': data['billNo'] ?? data['entryId'] ?? 'MGR-${managerBills.length + 1}',
              'billVendor': data['vendorName'] ?? data['vendor'] ?? 'Direct Manager',
              'billAmount': data['totalAmount'] ?? data['amount'] ?? 0,
              'billDate': data['date'] ?? current.toIso8601String(),
            });
          }
        }
      }

      // 3. Match Organization bills for current date
      final List<Map<String, dynamic>> orgBills = [];
      for (final doc in allOrgDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          for (final bill in bills) {
            if (bill is Map && ExpenseService.isSameDay(bill['billDate'] ?? bill['date'], current)) {
              orgBills.add(Map<String, dynamic>.from(bill));
            }
          }
        } else if (data['totalAmount'] != null || data['amount'] != null) {
          if (ExpenseService.isSameDay(data['date'] ?? data['entryDate'] ?? data['createdAt'], current)) {
            orgBills.add({
              'billNo': data['billNo'] ?? data['entryId'] ?? 'ORG-${orgBills.length + 1}',
              'billVendor': data['vendorName'] ?? data['vendor'] ?? 'Direct Organization',
              'billAmount': data['totalAmount'] ?? data['amount'] ?? 0,
              'billDate': data['date'] ?? current.toIso8601String(),
            });
          }
        }
      }

      // 4. Match Contractor expenses for current date
      final List<Map<String, dynamic>> contractorEntries = [];
      for (final doc in allContractorDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'] ?? data['workStage'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }
        if (ExpenseService.isSameDay(data['date'] ?? data['createdAt'], current)) {
          contractorEntries.add(data);
        }
      }

      // 5. Match Incentive Entries for current date
      final List<Map<String, dynamic>> incentiveEntries = [];
      for (final doc in allIncentiveDocs) {
        final data = doc.data();
        if (ExpenseService.isSameDay(data['date'] ?? data['updatedAt'] ?? data['createdAt'] ?? data['timestamp'], current)) {
          incentiveEntries.add(data);
        }
      }

      // 6. Match Petty Cash for current date
      final List<Map<String, dynamic>> pettyCashEntries = [];
      for (final pc in allPettyCash) {
        if (ExpenseService.isSameDay(pc['date'], current)) {
          pettyCashEntries.add(pc);
        }
      }

      final hasSupervisor = supervisorData != null && (supervisorData['totalAmount'] ?? 0) != 0;
      final hasManager = managerBills.isNotEmpty;
      final hasOrg = orgBills.isNotEmpty;
      final hasContractor = contractorEntries.isNotEmpty;
      final hasIncentives = incentiveEntries.isNotEmpty;
      final hasPettyCash = pettyCashEntries.isNotEmpty;

      if (hasSupervisor || hasManager || hasOrg || hasContractor || hasIncentives || hasPettyCash) {
        entries.add({
          'date': displayDateFormat.format(current),
          'dateTime': current,
          'supervisorData': supervisorData,
          'managerBills': managerBills,
          'orgBills': orgBills,
          'contractorEntries': contractorEntries,
          'incentiveEntries': incentiveEntries,
          'pettyCashEntries': pettyCashEntries,
        });
      }
      current = current.add(const Duration(days: 1));
    }
    return entries;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  double _getSupervisorTotalForEntry(Map<String, dynamic> entry) {
    final sup = entry['supervisorData'];
    if (sup == null) return 0;
    return _toDouble(sup['totalAmount'] ?? sup['amount']);
  }

  double _getMaterialsTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    final sup = entry['supervisorData'];
    if (sup != null && sup['materials'] is List) {
      for (final m in (sup['materials'] as List)) {
        if (m is Map) {
          final amt = _toDouble(m['amount']);
          if (amt > 0) {
            total += amt;
          } else {
            total += _toDouble(m['quantity'] ?? m['qty']) * _toDouble(m['unitPrice'] ?? m['price']);
          }
        }
      }
    }
    for (final c in (entry['contractorEntries'] ?? [])) {
      if (c['materials'] is List) {
        for (final m in (c['materials'] as List)) {
          if (m is Map) {
            final amt = _toDouble(m['amount']);
            if (amt > 0) {
              total += amt;
            } else {
              total += _toDouble(m['quantity'] ?? m['qty']) * _toDouble(m['unitPrice'] ?? m['price']);
            }
          }
        }
      }
    }
    return total;
  }

  double _getLabourTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    final sup = entry['supervisorData'];
    if (sup != null && sup['labours'] is List) {
      for (final l in (sup['labours'] as List)) {
        if (l is Map) {
          final amt = _toDouble(l['amount']);
          if (amt > 0) {
            total += amt;
          } else {
            total += _toDouble(l['count']) * _toDouble(l['unitSalary'] ?? l['salary']);
          }
        }
      }
    }
    for (final c in (entry['contractorEntries'] ?? [])) {
      if (c['labours'] is List) {
        for (final l in (c['labours'] as List)) {
          if (l is Map) {
            final amt = _toDouble(l['amount']);
            if (amt > 0) {
              total += amt;
            } else {
              total += _toDouble(l['count']) * _toDouble(l['unitSalary'] ?? l['salary']);
            }
          }
        }
      }
    }
    return total;
  }

  double _getManagerTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    for (final b in (entry['managerBills'] ?? [])) {
      total += _toDouble(b['billAmount'] ?? b['amount']);
    }
    return total;
  }

  double _getOrgTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    for (final b in (entry['orgBills'] ?? [])) {
      total += _toDouble(b['billAmount'] ?? b['amount']);
    }
    return total;
  }

  double _getFoodTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    final sup = entry['supervisorData'];
    if (sup != null) total += _toDouble(sup['food']);
    for (final c in (entry['contractorEntries'] ?? [])) {
      total += _toDouble(c['food']);
    }
    return total;
  }

  double _getTransportTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    final sup = entry['supervisorData'];
    if (sup != null) total += _toDouble(sup['transport']);
    for (final c in (entry['contractorEntries'] ?? [])) {
      total += _toDouble(c['transport']);
    }
    return total;
  }

  double _getFuelTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    final sup = entry['supervisorData'];
    if (sup != null) total += _toDouble(sup['fuel']);
    for (final c in (entry['contractorEntries'] ?? [])) {
      total += _toDouble(c['fuel']);
    }
    return total;
  }

  double _getPettyCashTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    for (final pc in (entry['pettyCashEntries'] ?? [])) {
      total += _toDouble(pc['amount']);
    }
    return total;
  }

  double _getContractorTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    for (final c in (entry['contractorEntries'] ?? [])) {
      total += _toDouble(c['totalAmount'] ?? c['amount']);
    }
    return total;
  }

  double _getIncentiveTotalForEntry(Map<String, dynamic> entry) {
    double total = 0;
    for (final inc in (entry['incentiveEntries'] ?? [])) {
      total += _toDouble(inc['incentiveAmount'] ?? inc['amount']);
    }
    return total;
  }

  double _getDateTotalForEntry(Map<String, dynamic> entry) {
    return _getSupervisorTotalForEntry(entry) +
        _getManagerTotalForEntry(entry) +
        _getOrgTotalForEntry(entry) +
        _getContractorTotalForEntry(entry) +
        _getIncentiveTotalForEntry(entry) +
        _getPettyCashTotalForEntry(entry);
  }

  Future<void> _generateAndPreviewPDF(
    List<Map<String, dynamic>> entries,
    num grandTotal,
  ) async {
    final pdf = pw.Document();
    final DateFormat displayDateFormat = DateFormat('dd-MMM-yyyy');
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.toARGB32());
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    double supSum = 0;
    double matSum = 0;
    double labSum = 0;
    double mgrSum = 0;
    double orgSum = 0;
    double foodSum = 0;
    double transSum = 0;
    double fuelSum = 0;
    double pcSum = 0;
    double contractorSum = 0;
    double incSum = 0;

    for (final entry in entries) {
      supSum += _getSupervisorTotalForEntry(entry);
      matSum += _getMaterialsTotalForEntry(entry);
      labSum += _getLabourTotalForEntry(entry);
      mgrSum += _getManagerTotalForEntry(entry);
      orgSum += _getOrgTotalForEntry(entry);
      foodSum += _getFoodTotalForEntry(entry);
      transSum += _getTransportTotalForEntry(entry);
      fuelSum += _getFuelTotalForEntry(entry);
      pcSum += _getPettyCashTotalForEntry(entry);
      contractorSum += _getContractorTotalForEntry(entry);
      incSum += _getIncentiveTotalForEntry(entry);
    }

    final categoryBreakdown = [
      {'name': 'Site Supervisor Expenses', 'amount': supSum},
      {'name': 'Materials', 'amount': matSum},
      {'name': 'Labour', 'amount': labSum},
      {'name': 'Manager Expenses', 'amount': mgrSum},
      {'name': 'Organization Expenses', 'amount': orgSum},
      {'name': 'Food', 'amount': foodSum},
      {'name': 'Transport', 'amount': transSum},
      {'name': 'Fuel', 'amount': fuelSum},
      {'name': 'Petty Cash', 'amount': pcSum},
      if (contractorSum > 0) {'name': 'Contractor Expenses', 'amount': contractorSum},
      if (incSum > 0) {'name': 'Incentives', 'amount': incSum},
    ];

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
          pw.SizedBox(height: 16),
          pw.Text(
            'CONSOLIDATED EXPENSE BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: pdfPrimaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Expense Category', 'Total Amount (Rs.)'],
            data: categoryBreakdown
                .map((c) => [
                      c['name'].toString(),
                      'Rs. ${(c['amount'] as double).toStringAsFixed(2)}',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey300),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'DAILY BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: pdfPrimaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          ...entries.map((entry) {
            final supervisorTotal = _getSupervisorTotalForEntry(entry);
            final managerTotal = _getManagerTotalForEntry(entry);
            final orgTotal = _getOrgTotalForEntry(entry);
            final contractorTotal = _getContractorTotalForEntry(entry);
            final incentiveTotal = _getIncentiveTotalForEntry(entry);
            final pettyCashTotal = _getPettyCashTotalForEntry(entry);
            final dateTotal = _getDateTotalForEntry(entry);
            final contractorEntries = (entry['contractorEntries'] as List? ?? []);
            final incentiveEntries = (entry['incentiveEntries'] as List? ?? []);
            final pettyCashEntries = (entry['pettyCashEntries'] as List? ?? []);

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
                      'Site Supervisor Entries: Rs. ${supervisorTotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if ((entry['managerBills'] as List? ?? []).isNotEmpty)
                    pw.Text(
                      'Manager Expenses: Rs. ${managerTotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if ((entry['orgBills'] as List? ?? []).isNotEmpty)
                    pw.Text(
                      'Organization Expenses: Rs. ${orgTotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if (pettyCashEntries.isNotEmpty)
                    pw.Text(
                      'Petty Cash: Rs. ${pettyCashTotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if (contractorEntries.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Contractor Expenses: Rs. ${contractorTotal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  if (incentiveEntries.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Supervisor / Extra Incentives: Rs. ${incentiveTotal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 6),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Day Total:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text(
                        'Rs. ${dateTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: pdfPrimaryColor,
                        ),
                      ),
                    ],
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
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Expenses Report',
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
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
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildHeaderInfo(0),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'No data found for the selected range.',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Calculate range totals for all 9 categories
              double totalSup = 0;
              double totalMat = 0;
              double totalLab = 0;
              double totalMgr = 0;
              double totalOrg = 0;
              double totalFood = 0;
              double totalTransport = 0;
              double totalFuel = 0;
              double totalPettyCash = 0;
              double totalContractor = 0;
              double totalIncentive = 0;
              double grandTotal = 0;

              for (final entry in entries) {
                totalSup += _getSupervisorTotalForEntry(entry);
                totalMat += _getMaterialsTotalForEntry(entry);
                totalLab += _getLabourTotalForEntry(entry);
                totalMgr += _getManagerTotalForEntry(entry);
                totalOrg += _getOrgTotalForEntry(entry);
                totalFood += _getFoodTotalForEntry(entry);
                totalTransport += _getTransportTotalForEntry(entry);
                totalFuel += _getFuelTotalForEntry(entry);
                totalPettyCash += _getPettyCashTotalForEntry(entry);
                totalContractor += _getContractorTotalForEntry(entry);
                totalIncentive += _getIncentiveTotalForEntry(entry);
                grandTotal += _getDateTotalForEntry(entry);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderInfo(grandTotal),
                    const SizedBox(height: 16),
                    _buildFinanceSummary(grandTotal),
                    const SizedBox(height: 20),
                    _buildConsolidatedBreakdownCard(
                      supervisorTotal: totalSup,
                      materialsTotal: totalMat,
                      labourTotal: totalLab,
                      managerTotal: totalMgr,
                      organizationTotal: totalOrg,
                      foodTotal: totalFood,
                      transportTotal: totalTransport,
                      fuelTotal: totalFuel,
                      pettyCashTotal: totalPettyCash,
                      contractorTotal: totalContractor,
                      incentiveTotal: totalIncentive,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DAILY BREAKDOWN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entries.length} ${entries.length == 1 ? 'DAY' : 'DAYS'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...entries.map((entry) {
                      final supervisorTotal = _getSupervisorTotalForEntry(entry);
                      final managerTotal = _getManagerTotalForEntry(entry);
                      final orgTotal = _getOrgTotalForEntry(entry);
                      final contractorTotal = _getContractorTotalForEntry(entry);
                      final incentiveTotal = _getIncentiveTotalForEntry(entry);
                      final pettyCashTotal = _getPettyCashTotalForEntry(entry);
                      final dateTotal = _getDateTotalForEntry(entry);

                      final matDay = _getMaterialsTotalForEntry(entry);
                      final labDay = _getLabourTotalForEntry(entry);
                      final foodDay = _getFoodTotalForEntry(entry);
                      final transDay = _getTransportTotalForEntry(entry);
                      final fuelDay = _getFuelTotalForEntry(entry);

                      final contractorEntries = (entry['contractorEntries'] as List? ?? []);
                      final incentiveEntries = (entry['incentiveEntries'] as List? ?? []);
                      final pettyCashEntries = (entry['pettyCashEntries'] as List? ?? []);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      entry['date'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹ ${dateTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (supervisorTotal > 0)
                                    _buildMiniChip('Supervisor', supervisorTotal, Colors.blue),
                                  if (matDay > 0)
                                    _buildMiniChip('Materials', matDay, Colors.indigo),
                                  if (labDay > 0)
                                    _buildMiniChip('Labour', labDay, Colors.teal),
                                  if (managerTotal > 0)
                                    _buildMiniChip('Manager', managerTotal, Colors.deepPurple),
                                  if (orgTotal > 0)
                                    _buildMiniChip('Org', orgTotal, Colors.cyan),
                                  if (foodDay > 0)
                                    _buildMiniChip('Food', foodDay, Colors.orange),
                                  if (transDay > 0)
                                    _buildMiniChip('Transport', transDay, Colors.purple),
                                  if (fuelDay > 0)
                                    _buildMiniChip('Fuel', fuelDay, Colors.brown),
                                  if (pettyCashTotal > 0)
                                    _buildMiniChip('Petty Cash', pettyCashTotal, Colors.green),
                                  if (contractorTotal > 0)
                                    _buildMiniChip('Contractor', contractorTotal, Colors.amber.shade800),
                                  if (incentiveTotal > 0)
                                    _buildMiniChip('Incentives', incentiveTotal, Colors.pink),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              _buildSection(
                                'Site Entries',
                                entry['supervisorData'],
                                isSupervisor: true,
                              ),
                              const SizedBox(height: 12),
                              _buildSection(
                                'Manager Expenses',
                                entry['managerBills'],
                              ),
                              const SizedBox(height: 12),
                              _buildSection(
                                'Organization Expenses',
                                entry['orgBills'],
                              ),
                              const SizedBox(height: 12),
                              _buildContractorSection(
                                'Contractor Expenses',
                                contractorEntries,
                              ),
                              if (pettyCashEntries.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildPettyCashSection(
                                  'Petty Cash Expenses',
                                  pettyCashEntries,
                                ),
                              ],
                              if (incentiveEntries.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildIncentiveSection(
                                  'Supervisor & Extra Incentives',
                                  incentiveEntries,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.picture_as_pdf, size: 22),
                        label: const Text(
                          'Generate PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          await _generateAndPreviewPDF(entries, grandTotal);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceSummary(double grandTotal) {
    return GlassCard(
      color: primaryColor,
      child: Column(
        children: [
          const Text(
            'TOTAL EXPENDITURE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedBreakdownCard({
    required double supervisorTotal,
    required double materialsTotal,
    required double labourTotal,
    required double managerTotal,
    required double organizationTotal,
    required double foodTotal,
    required double transportTotal,
    required double fuelTotal,
    required double pettyCashTotal,
    required double contractorTotal,
    required double incentiveTotal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONSOLIDATED EXPENSES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _expenseItem(
          'Site Supervisor Expenses',
          supervisorTotal,
          Icons.engineering_outlined,
        ),
        _expenseItem(
          'Materials',
          materialsTotal,
          Icons.inventory_2_outlined,
        ),
        _expenseItem(
          'Labour',
          labourTotal,
          Icons.handyman_outlined,
        ),
        _expenseItem(
          'Manager Expenses',
          managerTotal,
          Icons.manage_accounts_outlined,
        ),
        _expenseItem(
          'Organization Expenses',
          organizationTotal,
          Icons.business_outlined,
        ),
        _expenseItem(
          'Food',
          foodTotal,
          Icons.restaurant_outlined,
        ),
        _expenseItem(
          'Transport',
          transportTotal,
          Icons.local_shipping_outlined,
        ),
        _expenseItem(
          'Fuel',
          fuelTotal,
          Icons.local_gas_station_outlined,
        ),
        _expenseItem(
          'Petty Cash',
          pettyCashTotal,
          Icons.payments_outlined,
        ),
        if (contractorTotal > 0)
          _expenseItem(
            'Contractor Expenses',
            contractorTotal,
            Icons.construction_outlined,
          ),
        if (incentiveTotal > 0)
          _expenseItem(
            'Incentives',
            incentiveTotal,
            Icons.emoji_events_outlined,
          ),
      ],
    );
  }

  Widget _expenseItem(
    String label,
    double amount,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: amount > 0 ? textColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(double grandTotal) {
    final DateFormat displayDateFormat = DateFormat('dd-MMM-yyyy');
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Report Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Site', widget.siteId),
          _buildInfoRow('Year', widget.fromDate.year.toString()),
          _buildInfoRow('From', displayDateFormat.format(widget.fromDate)),
          _buildInfoRow('To', displayDateFormat.format(widget.toDate)),
        ],
      ),
    );
  }

  Widget _buildPettyCashSection(
    String title,
    List<dynamic> pettyCashEntries,
  ) {
    if (pettyCashEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    double total = 0;
    for (final pc in pettyCashEntries) {
      total += _toDouble(pc['amount']);
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
        const SizedBox(height: 6),
        ...pettyCashEntries.map((pc) {
          final desc = pc['description']?.toString() ?? '';
          final category = pc['category']?.toString() ?? 'Petty Cash';
          final amt = _toDouble(pc['amount']);
          return Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '• $category${desc.isNotEmpty ? " ($desc)" : ""}',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
                Text(
                  'Rs. ${amt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Petty Cash Total: Rs. ${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: primaryColor,
            ),
          ),
        ),
      ],
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
                color: textColor.withValues(alpha: 0.7),
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
                primaryColor.withValues(alpha: 0.1),
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

  Widget _buildIncentiveSection(
    String title,
    List<dynamic> incentiveEntries,
  ) {
    if (incentiveEntries.isEmpty) {
      return _noDataSection(title);
    }
    num total = 0;
    for (final inc in incentiveEntries) {
      final amt = inc['incentiveAmount'] ?? inc['amount'];
      if (amt is num) {
        total += amt;
      } else if (amt is String) {
        final parsed = double.tryParse(
          amt.toString().replaceAll(RegExp(r'[^0-9.]'), ''),
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
        ...incentiveEntries.map((inc) {
          final name = inc['supervisorName'] ?? inc['name'] ?? 'Supervisor';
          final role = inc['role'] ?? 'Incentive';
          final amt = inc['incentiveAmount'] ?? inc['amount'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
            child: Text(
              '• $name ($role): Rs. $amt',
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          );
        }),
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

