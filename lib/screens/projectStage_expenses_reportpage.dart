import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/project_stage_pdf_helper.dart';
import './pdf_preview_page.dart';

class ProjectStageExpensesReportPage extends StatefulWidget {
  final String siteId;
  final String projectStage;
  final DateTime fromDate;
  final DateTime toDate;

  const ProjectStageExpensesReportPage({
    super.key,
    required this.siteId,
    required this.projectStage,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<ProjectStageExpensesReportPage> createState() =>
      _ProjectStageExpensesReportPageState();
}

class _ProjectStageExpensesReportPageState
    extends State<ProjectStageExpensesReportPage> {
  double supervisorTotal = 0;
  double managerTotal = 0;
  double organizationTotal = 0;
  double contractorTotal = 0;
  double incentiveTotal = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final results = await Future.wait([
      _fetchTotal('siteSupervisorEntries', 'date', 'totalAmount'),
      _fetchTotal('managerEntries', 'entryDate', 'totalAmount'),
      _fetchTotal('organizationEntries', 'entryDate', 'totalAmount'),
      _fetchTotal('contractorEntries', 'date', 'totalAmount'),
      _fetchTotal('siteSupervisorIncentives', 'updatedAt', 'incentiveAmount'),
      _fetchTotal('managerExpenses', 'entryDate', 'totalAmount'),
      _fetchTotal('organizationExpenses', 'entryDate', 'totalAmount'),
    ]);

    setState(() {
      supervisorTotal = results[0];
      managerTotal = results[1] + results[5];
      organizationTotal = results[2] + results[6];
      contractorTotal = results[3];
      incentiveTotal = results[4];
      isLoading = false;
    });
  }

  Future<double> _fetchTotal(
    String collection,
    String dateField,
    String amountField,
  ) async {
    double total = 0;
    // Check both siteId and site field for broader compatibility
    final results = await Future.wait([
      FirestoreService.getCollection(
        collection,
      ).where('siteId', isEqualTo: widget.siteId).get(),
      FirestoreService.getCollection(
        collection,
      ).where('site', isEqualTo: widget.siteId).get(),
    ]);

    final allDocs = {...results[0].docs, ...results[1].docs};

    for (var doc in allDocs) {
      final data = doc.data();

      // Filter by stage manually
      final docStage = (data['projectStage'] ?? data['projectField'])
          ?.toString()
          .trim();
      if (docStage != widget.projectStage.trim()) continue;

      if (data.containsKey('bills') && data['bills'] is List) {
        final bills = data['bills'] as List;
        for (var bill in bills) {
          if (bill is Map) {
            DateTime? billDate;
            final rawDate = bill['billDate'];
            if (rawDate is Timestamp) {
              billDate = rawDate.toDate();
            } else if (rawDate is String) {
              billDate = DateTime.tryParse(rawDate);
            }

            if (billDate != null &&
                billDate.isAfter(
                  widget.fromDate.subtract(const Duration(days: 1)),
                ) &&
                billDate.isBefore(widget.toDate.add(const Duration(days: 1)))) {
              total += _toDouble(bill['billAmount'] ?? bill['amount']);
            }
          }
        }
      } else {
        DateTime? entryDate;
        final rawDate = data[dateField];
        if (rawDate is Timestamp) {
          entryDate = rawDate.toDate();
        } else if (rawDate is String) {
          entryDate = DateTime.tryParse(rawDate);
        }

        if (entryDate != null &&
            entryDate.isAfter(
              widget.fromDate.subtract(const Duration(days: 1)),
            ) &&
            entryDate.isBefore(widget.toDate.add(const Duration(days: 1)))) {
          total += _toDouble(
            data[amountField] ?? data['amount'] ?? data['totalAmount'],
          );
        }
      }
    }
    return total;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final grandTotal =
        supervisorTotal +
        managerTotal +
        organizationTotal +
        contractorTotal +
        incentiveTotal;

    return GlassScaffold(
      title: 'Stage Expense Analysis',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Export PDF',
          onPressed: isLoading ? null : _generatePdf,
        ),
      ],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildFinanceSummary(theme),
                  const SizedBox(height: 24),
                  _buildBreakdownSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(
                widget.projectStage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Period: ${DateFormat('dd MMM').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSummary(ThemeData theme) {
    final grandTotal =
        supervisorTotal +
        managerTotal +
        organizationTotal +
        contractorTotal +
        incentiveTotal;
    return GlassCard(
      color: theme.primaryColor,
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

  Widget _buildBreakdownSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EXPENSE BREAKDOWN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _expenseItem(
          'Supervisor Expenses',
          supervisorTotal,
          Icons.engineering_outlined,
          theme,
        ),
        _expenseItem(
          'Manager Expenses',
          managerTotal,
          Icons.manage_accounts_outlined,
          theme,
        ),
        _expenseItem(
          'Organization Expenses',
          organizationTotal,
          Icons.business_outlined,
          theme,
        ),
        _expenseItem(
          'Contractor Expenses',
          contractorTotal,
          Icons.construction_outlined,
          theme,
        ),
        _expenseItem(
          'Incentives',
          incentiveTotal,
          Icons.emoji_events_outlined,
          theme,
        ),
      ],
    );
  }

  Widget _expenseItem(
    String label,
    double amount,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.value,
    );
    try {
      final pdfBytes = await ProjectStagePdfHelper.buildExpenseRangeReport(
        siteId: widget.siteId,
        projectStage: widget.projectStage,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        supervisorTotal: supervisorTotal,
        managerTotal: managerTotal,
        organizationTotal: organizationTotal,
        contractorTotal: contractorTotal,
        incentiveTotal: incentiveTotal,
        primaryColor: pdfPrimaryColor,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName:
                'ExpenseRange_${widget.siteId}_${DateFormat('ddMMyyyy').format(widget.fromDate)}_${DateFormat('ddMMyyyy').format(widget.toDate)}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }
}
