import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class SiteSummaryPage extends StatefulWidget {
  final String siteId;
  final String? projectStage;

  const SiteSummaryPage({super.key, required this.siteId, this.projectStage});

  @override
  State<SiteSummaryPage> createState() => _SiteSummaryPageState();
}

class _SiteSummaryPageState extends State<SiteSummaryPage> {
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get accentColor => Theme.of(context).colorScheme.secondary;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF2c3e50);
  Color get cardColor => Theme.of(context).cardColor;
  Color get successColor => const Color(0xFF2e7d32);
  Color get warningColor => const Color(0xFFed6c02);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    print('[SiteSummaryPage] Loaded with siteId: ${widget.siteId}');
  }

  String formatCurrency(num value) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not set';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<Map<String, num>> fetchExpenseTotals() async {
    try {
      final query = await FirestoreService.getCollection(
        'siteSupervisorEntries',
      ).where('siteId', isEqualTo: widget.siteId).get();

      final List<String> expenseFields = ['food', 'fuel', 'transport'];
      Map<String, num> totals = {
        for (var f in expenseFields) f: 0,
        'labours': 0,
        'materials': 0,
      };

      for (var doc in query.docs) {
        final data = doc.data();

        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        for (var field in expenseFields) {
          final value = data[field];
          if (value != null) {
            if (value is int || value is double) {
              totals[field] = (totals[field] ?? 0) + value;
            } else if (value is String) {
              final parsed = num.tryParse(
                value.replaceAll(RegExp(r'[^0-9.]'), ''),
              );
              if (parsed != null) {
                totals[field] = (totals[field] ?? 0) + parsed;
              }
            }
          }
        }
        if (data['labours'] != null && data['labours'] is List) {
          for (var labour in data['labours']) {
            if (labour is Map && labour['amount'] != null) {
              final amount = labour['amount'];
              if (amount is int || amount is double) {
                totals['labours'] = (totals['labours'] ?? 0) + amount;
              } else if (amount is String) {
                final parsed = num.tryParse(
                  amount.replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                if (parsed != null) {
                  totals['labours'] = (totals['labours'] ?? 0) + parsed;
                }
              }
            }
          }
        }
        if (data['materials'] != null && data['materials'] is List) {
          for (var material in data['materials']) {
            if (material is Map && material['amount'] != null) {
              final amount = material['amount'];
              if (amount is int || amount is double) {
                totals['materials'] = (totals['materials'] ?? 0) + amount;
              } else if (amount is String) {
                final parsed = num.tryParse(
                  amount.replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                if (parsed != null) {
                  totals['materials'] = (totals['materials'] ?? 0) + parsed;
                }
              }
            }
          }
        }
      }
      return totals;
    } catch (e) {
      print('[fetchExpenseTotals] Error: $e');
      return {};
    }
  }

  Future<num> fetchManagerExpenses() async {
    try {
      final query = await FirestoreService.getCollection(
        'managerExpenses',
      ).where('siteId', isEqualTo: widget.siteId).get();
      num total = 0;
      for (var doc in query.docs) {
        final data = doc.data();

        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        final value = data['totalAmount'];
        if (value != null) {
          if (value is int || value is double) {
            total += value;
          } else if (value is String) {
            final parsed = num.tryParse(
              value.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            if (parsed != null) total += parsed;
          }
        }
      }
      return total;
    } catch (e) {
      print('[fetchManagerExpenses] Error: $e');
      return 0;
    }
  }

  Future<num> fetchOrganizationExpenses() async {
    try {
      final query = await FirestoreService.getCollection(
        'organizationEntries',
      ).where('siteId', isEqualTo: widget.siteId).get();
      num total = 0;
      for (var doc in query.docs) {
        final data = doc.data();

        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        final value = data['totalAmount'];
        if (value != null) {
          if (value is int || value is double) {
            total += value;
          } else if (value is String) {
            final parsed = num.tryParse(
              value.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            if (parsed != null) total += parsed;
          }
        }
      }
      return total;
    } catch (e) {
      print('[fetchOrganizationExpenses] Error: $e');
      return 0;
    }
  }

  Future<Map<String, num>> fetchContractorAndIncentiveExpenses() async {
    try {
      final query = await FirestoreService.getCollection(
        'totalSiteExpensesPerDay',
      ).where('siteId', isEqualTo: widget.siteId).get();

      num totalContractorExpense = 0;
      num totalIncentiveExpenses = 0;

      for (var doc in query.docs) {
        final data = doc.data();

        // Filter by stage if provided
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        if (data['totalContractorExpense'] != null) {
          final value = data['totalContractorExpense'];
          if (value is int || value is double) {
            totalContractorExpense += value;
          } else if (value is String) {
            final parsed = num.tryParse(
              value.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            if (parsed != null) totalContractorExpense += parsed;
          }
        }
        if (data['totalIncentiveExpenses'] != null) {
          final value = data['totalIncentiveExpenses'];
          if (value is int || value is double) {
            totalIncentiveExpenses += value;
          } else if (value is String) {
            final parsed = num.tryParse(
              value.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            if (parsed != null) totalIncentiveExpenses += parsed;
          }
        }
      }

      return {
        'contractor': totalContractorExpense,
        'incentive': totalIncentiveExpenses,
      };
    } catch (e) {
      print('[fetchContractorAndIncentiveExpenses] Error: $e');
      return {'contractor': 0, 'incentive': 0};
    }
  }

  Future<Map<String, dynamic>?> fetchProjectInfo() async {
    try {
      final query = await FirestoreService.getCollection(
        'projects',
      ).where('siteId', isEqualTo: widget.siteId).limit(1).get();

      Map<String, dynamic>? data = query.docs.isNotEmpty
          ? query.docs.first.data()
          : null;

      // Fallback to fetch from 'Site' collection if project data is missing or has no location
      if (data == null ||
          (data['siteLocation'] == null && data['location'] == null)) {
        final siteDoc = await FirestoreService.getCollection(
          'Site',
        ).doc(widget.siteId).get();
        if (siteDoc.exists) {
          final siteData = siteDoc.data()!;
          if (data == null) {
            data = siteData;
          } else {
            // Merge missing location info into project data
            data['siteLocation'] =
                siteData['location'] ?? siteData['siteLocation'];
            data['siteName'] = data['siteName'] ?? siteData['siteName'];
          }
        }
      }
      return data;
    } catch (e) {
      print('[fetchProjectInfo] Error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Site Summary',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: fetchProjectInfo(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              );
            }
            if (projectSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: primaryColor, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load project data',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (!projectSnapshot.hasData || projectSnapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, color: primaryColor, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Project not found',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No project found for site ID: ${widget.siteId}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            }

            final project = projectSnapshot.data!;
            final site =
                project['siteLocation']?.toString() ??
                project['location']?.toString() ??
                'N/A';
            final projectName = project['projectName']?.toString() ?? 'N/A';
            final budget = (project['projectBudget'] ?? 0) as num;
            final plannedStartDate = project['plannedStartDate'] as Timestamp?;
            final amountSpent = (project['amountSpent'] ?? 0) as num;
            final currentStatus = project['currentStatus']?.toString() ?? 'N/A';

            return FutureBuilder<Map<String, num>>(
              future: fetchExpenseTotals(),
              builder: (context, expenseSnapshot) {
                if (expenseSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  );
                }
                if (expenseSnapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: primaryColor,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load expenses',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final expenseTotals = expenseSnapshot.data ?? {};
                num totalSupervisorExpenses = expenseTotals.values.fold(
                  0,
                  (a, b) => a + b,
                );

                return FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    fetchManagerExpenses(),
                    fetchOrganizationExpenses(),
                    fetchContractorAndIncentiveExpenses(),
                  ]),
                  builder: (context, otherSnapshot) {
                    if (otherSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                        ),
                      );
                    }
                    final managerExpenses = otherSnapshot.data?[0] ?? 0;
                    final orgExpenses = otherSnapshot.data?[1] ?? 0;
                    final contractorIncentive =
                        otherSnapshot.data?[2] ??
                        {'contractor': 0, 'incentive': 0};

                    final contractorExpenses =
                        contractorIncentive['contractor'] ?? 0;
                    final incentiveExpenses =
                        contractorIncentive['incentive'] ?? 0;

                    final grandTotal =
                        totalSupervisorExpenses +
                        managerExpenses +
                        orgExpenses +
                        contractorExpenses +
                        incentiveExpenses;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Project Overview Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: EdgeInsets.only(bottom: 20),
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.assignment,
                                        color: primaryColor,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Project Overview',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  _buildInfoRow('Site Location', site),
                                  _buildInfoRow('Project Name', projectName),
                                  _buildInfoRow(
                                    'Start Date',
                                    formatDate(plannedStartDate),
                                  ),
                                  _buildInfoRow(
                                    'Budget',
                                    formatCurrency(budget),
                                  ),
                                  _buildInfoRow(
                                    'Amount Spent',
                                    formatCurrency(amountSpent),
                                  ),
                                  _buildInfoRow(
                                    'Current Status',
                                    currentStatus,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expenses Section
                          Text(
                            'Expense Breakdown',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 12),

                          // Site Supervisor Expenses
                          _buildExpenseCard(
                            title: 'Site Supervisor Expenses',
                            icon: Icons.engineering,
                            expenseTotals: expenseTotals,
                            total: totalSupervisorExpenses,
                          ),
                          SizedBox(height: 16),

                          // Manager Expenses
                          _buildSimpleExpenseCard(
                            title: 'Manager Expenses',
                            icon: Icons.manage_accounts,
                            amount: managerExpenses,
                          ),
                          SizedBox(height: 16),

                          // Organization Expenses
                          _buildSimpleExpenseCard(
                            title: 'Organization Expenses',
                            icon: Icons.business,
                            amount: orgExpenses,
                          ),
                          SizedBox(height: 16),

                          // Contractor Expenses
                          _buildSimpleExpenseCard(
                            title: 'Contractor Expenses',
                            icon: Icons.construction,
                            amount: contractorExpenses,
                          ),
                          SizedBox(height: 16),

                          // Incentive Expenses
                          _buildSimpleExpenseCard(
                            title: 'Incentive Expenses',
                            icon: Icons.monetization_on,
                            amount: incentiveExpenses,
                          ),
                          SizedBox(height: 24),

                          // Grand Total Card
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calculate,
                                      color: primaryColor,
                                      size: 28,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Total Expenses',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  formatCurrency(grandTotal),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${(grandTotal / budget * 100).toStringAsFixed(1)}% of total budget',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),

                          // PDF Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isSaving = true;
                                      });
                                      await Printing.layoutPdf(
                                        onLayout: (PdfPageFormat format) async {
                                          return await _generatePdf(
                                            project: project,
                                            expenseTotals: expenseTotals,
                                            totalExpenses:
                                                totalSupervisorExpenses,
                                            managerExpenses: managerExpenses,
                                            orgExpenses: orgExpenses,
                                            contractorExpenses:
                                                contractorExpenses,
                                            incentiveExpenses:
                                                incentiveExpenses,
                                            grandTotal: grandTotal,
                                          );
                                        },
                                      );
                                      setState(() {
                                        _isSaving = false;
                                      });
                                    },
                              icon: Icon(Icons.picture_as_pdf),
                              label: Text(
                                _isSaving
                                    ? 'Generating PDF...'
                                    : 'Generate PDF Report',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard({
    required String title,
    required IconData icon,
    required Map<String, num> expenseTotals,
    required num total,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (expenseTotals.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No expenses recorded',
                  style: TextStyle(color: textColor.withOpacity(0.6)),
                ),
              )
            else
              Column(
                children: [
                  ...expenseTotals.entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: TextStyle(color: textColor),
                          ),
                          Text(
                            formatCurrency(entry.value),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        formatCurrency(total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
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

  Widget _buildSimpleExpenseCard({
    required String title,
    required IconData icon,
    required num amount,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount', style: TextStyle(color: textColor)),
                Text(
                  formatCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf({
    required Map<String, dynamic> project,
    required Map<String, num> expenseTotals,
    required num totalExpenses,
    required num managerExpenses,
    required num orgExpenses,
    required num contractorExpenses,
    required num incentiveExpenses,
    required num grandTotal,
  }) async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final site = project['siteLocation']?.toString() ?? 'N/A';
    final projectName = project['projectName']?.toString() ?? 'N/A';
    final budget = (project['projectBudget'] ?? 0) as num;
    final plannedStartDate = project['plannedStartDate'] as Timestamp?;
    final amountSpent = (project['amountSpent'] ?? 0) as num;
    final currentStatus = project['currentStatus']?.toString() ?? 'N/A';
    final dateFormat = DateFormat('dd MMM yyyy');

    final logo = await _getLogoImage();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Site Summary Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Project Name',
                projectName,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox('Site Location', site, pdfPrimaryColor),
              PdfTemplates.buildMetaBox(
                'Start Date',
                formatDate(plannedStartDate),
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Budget',
                '₹${NumberFormat('#,##,###').format(budget)}',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Amount Spent',
                '₹${NumberFormat('#,##,###').format(amountSpent)}',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Current Status',
                currentStatus,
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Expense Details',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(primaryColor.value),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Site Supervisor Expenses',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          expenseTotals.isEmpty
              ? pw.Text('No expenses recorded')
              : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Category',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...expenseTotals.entries.map((entry) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text(
                              entry.key[0].toUpperCase() +
                                  entry.key.substring(1),
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '₹${NumberFormat('#,##,###').format(entry.value)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '₹${NumberFormat('#,##,###').format(totalExpenses)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Manager Expenses',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(managerExpenses)}',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Organization Expenses',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(orgExpenses)}',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Contractor Expenses',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(contractorExpenses)}',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Incentive Expenses',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(incentiveExpenses)}',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: pdfPrimaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL EXPENSES',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '₹${NumberFormat('#,##,###').format(grandTotal)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
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
    return pdf.save();
  }

  Future<pw.MemoryImage?> _getLogoImage() async {
    try {
      // Replace with your actual logo asset
      final byteData = await rootBundle.load(
        'assets/images/splash_screen_logo.png',
      );
      final buffer = byteData.buffer;
      return pw.MemoryImage(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }
}
