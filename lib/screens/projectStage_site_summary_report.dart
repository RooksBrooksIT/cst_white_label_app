import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class ProjectstageSiteSummaryReport extends StatefulWidget {
  final String siteId;
  final String projectStage;

  const ProjectstageSiteSummaryReport({
    super.key,
    required this.siteId,
    required this.projectStage,
  });

  @override
  State<ProjectstageSiteSummaryReport> createState() =>
      _ProjectstageSiteSummaryReportState();
}

class _ProjectstageSiteSummaryReportState
    extends State<ProjectstageSiteSummaryReport> {
  // Color constants
  final Color primaryColor = const Color(0xFF0b3470);
  final Color accentColor = const Color(0xFF1e88e5);
  final Color backgroundColor = const Color(0xFFf8f9fa);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color secondaryTextColor = const Color(0xFF7f8c8d);

  bool _isSaving = false;
  bool _isValid = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _validateInputs();
  }

  Future<void> _validateInputs() async {
    setState(() {
      _isValid = false;
      _errorMessage = '';
    });

    if (widget.siteId.isEmpty || widget.projectStage.isEmpty) {
      setState(() {
        _errorMessage = 'Site ID and Project Stage cannot be empty';
      });
      return;
    }

    try {
      final siteDoc = await FirebaseFirestore.instance
          .collection('projects')
          .where('siteId', isEqualTo: widget.siteId)
          .limit(1)
          .get();

      if (siteDoc.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No project found for Site ID: ${widget.siteId}';
        });
        return;
      }

      setState(() {
        _isValid = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating inputs: ${e.toString()}';
      });
    }
  }

  String formatCurrency(num value) {
    final formatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(value);
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not set';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<Map<String, num>> fetchExpenseTotals() async {
    if (!_isValid) return {};

    try {
      final query = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .where('siteId', isEqualTo: widget.siteId)
          .where('projectStage', isEqualTo: widget.projectStage)
          .get();

      final List<String> expenseFields = ['food', 'fuel', 'transport'];
      Map<String, num> totals = {
        for (var f in expenseFields) f: 0,
        'labours': 0,
        'materials': 0,
      };

      for (var doc in query.docs) {
        final data = doc.data();

        for (var field in expenseFields) {
          final value = data[field];
          if (value != null) {
            if (value is int || value is double) {
              totals[field] = (totals[field] ?? 0) + value;
            } else if (value is String) {
              final parsed =
                  num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
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
                final parsed =
                    num.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
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
                final parsed =
                    num.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
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
    if (!_isValid) return 0;

    try {
      final query = await FirebaseFirestore.instance
          .collection('managerEntries')
          .where('siteId', isEqualTo: widget.siteId)
          .where('projectStage', isEqualTo: widget.projectStage)
          .get();

      num total = 0;
      for (var doc in query.docs) {
        final data = doc.data();
        if (data['siteId'] == widget.siteId) {
          final value = data['totalAmount'];
          if (value != null) {
            if (value is int || value is double) {
              total += value;
            } else if (value is String) {
              final parsed =
                  num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
              if (parsed != null) total += parsed;
            }
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
    if (!_isValid) return 0;

    try {
      final query = await FirebaseFirestore.instance
          .collection('organizationEntries')
          .where('siteId', isEqualTo: widget.siteId)
          .where('projectStage', isEqualTo: widget.projectStage)
          .get();

      num total = 0;
      for (var doc in query.docs) {
        final data = doc.data();
        if (data['siteId'] == widget.siteId) {
          final value = data['totalAmount'];
          if (value != null) {
            if (value is int || value is double) {
              total += value;
            } else if (value is String) {
              final parsed =
                  num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
              if (parsed != null) total += parsed;
            }
          }
        }
      }

      return total;
    } catch (e) {
      print('[fetchOrganizationExpenses] Error: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> fetchProjectInfo() async {
    if (!_isValid) return null;

    try {
      final query = await FirebaseFirestore.instance
          .collection('projects')
          .where('siteId', isEqualTo: widget.siteId.trim())
          .get();

      final projectStageInput = widget.projectStage.trim().toLowerCase();
      for (var doc in query.docs) {
        final data = doc.data();
        final projectStageDb =
            (data['projectStage'] ?? '').toString().trim().toLowerCase();
        if (projectStageDb == projectStageInput) {
          return data;
        }
      }
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return null;
    } catch (e) {
      print('[fetchProjectInfo] Error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchContractorExpenses() async {
    if (!_isValid) return [];
    try {
      final query = await FirebaseFirestore.instance
          .collection('contractorEntries')
          .where('siteId', isEqualTo: widget.siteId)
          .where('projectField', isEqualTo: widget.projectStage)
          .get();
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('[fetchContractorExpenses] Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchIncentiveExpenses() async {
    if (!_isValid) return [];
    try {
      final query = await FirebaseFirestore.instance
          .collection('siteSupervisorIncentives')
          .where('siteId', isEqualTo: widget.siteId)
          .where('projectStage', isEqualTo: widget.projectStage)
          .get();
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('[fetchIncentiveExpenses] Error: $e');
      return [];
    }
  }

  Widget _buildContractorExpensesSection(
      BuildContext context, List<Map<String, dynamic>> contractorExpenses) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handyman, color: primaryColor),
                const SizedBox(width: 12),
                Text('Contractor Expenses',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            if (contractorExpenses.isEmpty)
              Text('No contractor expenses recorded',
                  style: TextStyle(color: secondaryTextColor)),
            if (contractorExpenses.isNotEmpty)
              ...contractorExpenses.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contractor: ${entry['contractorName'] ?? ''}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: textColor)),
                        Text('Date: ${entry['date'] ?? ''}',
                            style: TextStyle(color: secondaryTextColor)),
                        Text('Field: ${entry['projectField'] ?? ''}',
                            style: TextStyle(color: secondaryTextColor)),
                        Text(
                            'Total Amount: ${formatCurrency(entry['totalAmount'] ?? 0)}',
                            style: TextStyle(color: textColor)),
                        if (entry['materials'] != null &&
                            entry['materials'] is List &&
                            (entry['materials'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Materials:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                ...List<Map<String, dynamic>>.from(
                                        entry['materials'])
                                    .map((mat) => Text(
                                        '- ${mat['type']}: Qty ${mat['quantity']}, Unit Price ${formatCurrency(mat['unitPrice'] ?? 0)}, Amount ${formatCurrency(mat['amount'] ?? 0)}',
                                        style:
                                            TextStyle(color: secondaryTextColor))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildIncentiveExpensesSection(
      BuildContext context, List<Map<String, dynamic>> incentiveExpenses) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: primaryColor),
                const SizedBox(width: 12),
                Text('Incentive Expenses',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            if (incentiveExpenses.isEmpty)
              Text('No incentive expenses recorded',
                  style: TextStyle(color: secondaryTextColor)),
            if (incentiveExpenses.isNotEmpty)
              ...incentiveExpenses.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount:', style: TextStyle(color: textColor)),
                        Text(formatCurrency(entry['incentiveAmount'] ?? 0),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Site Summary',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !_isValid
            ? _buildErrorScreen(context)
            : FutureBuilder<Map<String, dynamic>?>(
                future: fetchProjectInfo(),
                builder: (context, projectSnapshot) {
                  if (projectSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return _buildLoadingIndicator();
                  }
                  if (projectSnapshot.hasError) {
                    return _buildErrorScreen(context,
                        message:
                            'Failed to load project data: ${projectSnapshot.error}');
                  }
                  if (!projectSnapshot.hasData ||
                      projectSnapshot.data == null) {
                    final emptyProject = <String, dynamic>{};
                    return _buildMainContent(context, emptyProject);
                  }

                  final project = projectSnapshot.data!;
                  return _buildMainContent(context, project);
                },
              ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, {String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: primaryColor, size: 48),
          const SizedBox(height: 16),
          Text(
            message ?? _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(color: primaryColor),
    );
  }

  Widget _buildMainContent(BuildContext context, Map<String, dynamic> project) {
    return FutureBuilder<Map<String, num>>(
      future: fetchExpenseTotals(),
      builder: (context, expenseSnapshot) {
        if (expenseSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }
        if (expenseSnapshot.hasError) {
          return _buildErrorScreen(context,
              message: 'Failed to load expenses: ${expenseSnapshot.error}');
        }
        final expenseTotals = expenseSnapshot.data ?? {};
        num totalSupervisorExpenses =
            expenseTotals.values.fold(0, (a, b) => a + b);
        return FutureBuilder<List<num>>(
          future: Future.wait([
            fetchManagerExpenses(),
            fetchOrganizationExpenses(),
          ]),
          builder: (context, otherSnapshot) {
            if (otherSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            }
            if (otherSnapshot.hasError) {
              return _buildErrorScreen(context,
                  message:
                      'Failed to load other expenses: ${otherSnapshot.error}');
            }
            final managerExpenses = otherSnapshot.data?[0] ?? 0;
            final orgExpenses = otherSnapshot.data?[1] ?? 0;
            return FutureBuilder<List<List<Map<String, dynamic>>>>(
              future: Future.wait([
                fetchContractorExpenses(),
                fetchIncentiveExpenses(),
              ]),
              builder: (context, extraSnapshot) {
                if (extraSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                }
                if (extraSnapshot.hasError) {
                  return _buildErrorScreen(context,
                      message:
                          'Failed to load extra expenses: ${extraSnapshot.error}');
                }
                final contractorExpenses = extraSnapshot.data?[0] ?? [];
                final incentiveExpenses = extraSnapshot.data?[1] ?? [];
                final contractorTotal = contractorExpenses.fold<num>(
                    0, (sum, entry) => sum + (entry['totalAmount'] ?? 0));
                final incentiveTotal = incentiveExpenses.fold<num>(
                    0, (sum, entry) => sum + (entry['incentiveAmount'] ?? 0));
                final grandTotal = totalSupervisorExpenses +
                    managerExpenses +
                    orgExpenses +
                    contractorTotal +
                    incentiveTotal;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildProjectOverviewCard(context, project),
                      const SizedBox(height: 24),
                      _buildExpenseSection(
                        context,
                        expenseTotals: expenseTotals,
                        totalSupervisorExpenses: totalSupervisorExpenses,
                        managerExpenses: managerExpenses,
                        orgExpenses: orgExpenses,
                        grandTotal: grandTotal,
                        budget: (project['projectBudget'] ?? 0) as num,
                      ),
                      const SizedBox(height: 24),
                      _buildContractorExpensesSection(context, contractorExpenses),
                      const SizedBox(height: 16),
                      _buildIncentiveExpensesSection(context, incentiveExpenses),
                      const SizedBox(height: 24),
                      _buildGrandTotalCard(context, grandTotal,
                          (project['projectBudget'] ?? 0) as num),
                      const SizedBox(height: 24),
                      _buildPdfButton(
                        context,
                        project,
                        expenseTotals,
                        totalSupervisorExpenses,
                        managerExpenses,
                        orgExpenses,
                        grandTotal,
                        contractorExpenses: contractorExpenses,
                        incentiveExpenses: incentiveExpenses,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProjectOverviewCard(
      BuildContext context, Map<String, dynamic> project) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Project Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Site ID', widget.siteId),
            _buildInfoRow('Project Stage', widget.projectStage),
            _buildInfoRow(
                'Project Name', project['projectName']?.toString() ?? 'N/A'),
            _buildInfoRow('Start Date',
                formatDate(project['plannedStartDate'] as Timestamp?)),
            _buildInfoRow('Budget',
                formatCurrency((project['projectBudget'] ?? 0) as num)),
            _buildInfoRow('Amount Spent',
                formatCurrency((project['amountSpent'] ?? 0) as num)),
            _buildInfoRow(
                'Current Status', project['status']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection(
    BuildContext context, {
    required Map<String, num> expenseTotals,
    required num totalSupervisorExpenses,
    required num managerExpenses,
    required num orgExpenses,
    required num grandTotal,
    required num budget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Expense Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpenseCard(
          context,
          title: 'Site Supervisor Expenses',
          icon: Icons.engineering,
          expenseTotals: expenseTotals,
          total: totalSupervisorExpenses,
        ),
        const SizedBox(height: 16),
        _buildSimpleExpenseCard(
          context,
          title: 'Manager Expenses',
          icon: Icons.manage_accounts,
          amount: managerExpenses,
        ),
        const SizedBox(height: 16),
        _buildSimpleExpenseCard(
          context,
          title: 'Organization Expenses',
          icon: Icons.business,
          amount: orgExpenses,
        ),
      ],
    );
  }

  Widget _buildGrandTotalCard(
      BuildContext context, num grandTotal, num budget) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.calculate, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              Text(
                'Total Expenses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCurrency(grandTotal),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(grandTotal / budget * 100).toStringAsFixed(1)}% of total budget',
            style: TextStyle(
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfButton(
      BuildContext context,
      Map<String, dynamic> project,
      Map<String, num> expenseTotals,
      num totalExpenses,
      num managerExpenses,
      num orgExpenses,
      num grandTotal,
      {List<Map<String, dynamic>> contractorExpenses = const [],
      List<Map<String, dynamic>> incentiveExpenses = const []}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving
            ? null
            : () async {
                setState(() => _isSaving = true);
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async {
                    return await _generatePdf(
                      project: project,
                      expenseTotals: expenseTotals,
                      totalExpenses: totalExpenses,
                      managerExpenses: managerExpenses,
                      orgExpenses: orgExpenses,
                      grandTotal: grandTotal,
                      contractorExpenses: contractorExpenses,
                      incentiveExpenses: incentiveExpenses,
                    );
                  },
                );
                setState(() => _isSaving = false);
              },
        icon: const Icon(Icons.picture_as_pdf),
        label: Text(_isSaving ? 'Generating PDF...' : 'Generate PDF Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Map<String, num> expenseTotals,
    required num total,
  }) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenseTotals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No expenses recorded',
                  style: TextStyle(
                    color: secondaryTextColor,
                  ),
                ),
              )
            else
              Column(
                children: [
                  ...expenseTotals.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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

  Widget _buildSimpleExpenseCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required num amount,
  }) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(color: textColor),
                ),
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
    required num grandTotal,
    List<Map<String, dynamic>> contractorExpenses = const [],
    List<Map<String, dynamic>> incentiveExpenses = const [],
  }) async {
    final pdf = pw.Document();
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
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Site Summary Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(primaryColor.value),
                ),
              ),
              if (logo != null)
                pw.Image(
                  logo,
                  width: 80,
                  height: 80,
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Project: $projectName',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text('Site Location: $site'),
          pw.Text('Start Date: ${formatDate(plannedStartDate)}'),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Budget',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(budget)}',
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Amount Spent',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '₹${NumberFormat('#,##,###').format(amountSpent)}',
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Current Status',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        currentStatus,
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
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
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
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
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Category',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
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
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              entry.key[0].toUpperCase() +
                                  entry.key.substring(1),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
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
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
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
                  padding: const pw.EdgeInsets.all(12),
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
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
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
                        style: const pw.TextStyle(fontSize: 16),
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
              color: PdfColor.fromInt(primaryColor.value),
              border: pw.Border.all(
                  color: PdfColor.fromInt(primaryColor.value)),
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
                    color: PdfColor.fromInt(primaryColor.value),
                  ),
                ),
                pw.Text(
                  '₹${NumberFormat('#,##,###').format(grandTotal)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(primaryColor.value),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Generated on ${dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<pw.MemoryImage?> _getLogoImage() async {
    try {
      final byteData =
          await rootBundle.load('assets/images/splash_screen_logo.png');
      final buffer = byteData.buffer;
      return pw.MemoryImage(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }
}