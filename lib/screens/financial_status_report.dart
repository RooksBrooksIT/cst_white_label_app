import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../utils/pdf_templates.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

class FinancialStatusReportPage extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String projectName;
  final String ownerName;

  const FinancialStatusReportPage({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.projectName,
    required this.ownerName,
  });

  @override
  State<FinancialStatusReportPage> createState() =>
      _FinancialStatusReportPageState();
}

class _FinancialStatusReportPageState extends State<FinancialStatusReportPage> {
  Map<String, dynamic>? projectData;
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      final col = FirestoreService.getCollection('projects');
      QuerySnapshot<Map<String, dynamic>> query = await col
          .where('siteId', isEqualTo: widget.siteId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        query = await col
            .where('siteid', isEqualTo: widget.siteId)
            .limit(1)
            .get();
      }
      if (query.docs.isNotEmpty) {
        setState(() {
          projectData = query.docs.first.data();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMsg = 'Project data not found for site: ${widget.siteId}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error loading project: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GlassScaffold(
      title: 'Financial Status Report',
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: colorScheme.onPrimary,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
          ? _buildErrorView(theme)
          : _buildReportView(theme),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              errorMsg!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            GlassButton(label: 'RETRY', onPressed: _fetchProjectData),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProjectHeader(theme),
          const SizedBox(height: 16),
          _buildInfoSection(theme),
          const SizedBox(height: 16),
          _buildFinancialSummary(theme),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: 'EXPORT PDF',
                  onPressed: _generateAndPreviewPDF,
                  icon: Icons.picture_as_pdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  label: 'REFRESH',
                  onPressed: _fetchProjectData,
                  isSecondary: true,
                  icon: Icons.refresh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProjectHeader(ThemeData theme) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.apartment, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.projectName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.siteName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text('Client Name', style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.ownerName,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Information',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Site ID',
            projectData?['siteid'] ?? projectData?['siteId'] ?? '-',
            Icons.tag,
          ),
          _buildInfoRow(
            'Location',
            projectData?['siteLocation'] ?? '-',
            Icons.location_on_outlined,
          ),
          _buildInfoRow(
            'Actual Start',
            _formatDate(projectData?['actualStartDate']),
            Icons.calendar_today_outlined,
          ),
          _buildInfoRow(
            'Duration',
            '${_calculateDuration()} days',
            Icons.history,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(ThemeData theme) {
    final budget = _parseNum(projectData?['projectBudget']);
    final received = _parseNum(projectData?['amountPaid']);
    final spent = _parseNum(projectData?['amountSpent']);
    final balance = _parseNum(projectData?['amountBalance']);
    final usage = budget > 0 ? (spent / budget * 100).clamp(0, 100) : 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildFinanceTile(
            'Total Budget',
            '₹ $budget',
            theme.colorScheme.primary,
            Icons.account_balance_wallet_outlined,
          ),
          _buildFinanceTile(
            'Total Received',
            '₹ $received',
            Colors.green,
            Icons.arrow_downward_rounded,
          ),
          _buildFinanceTile(
            'Total Spent',
            '₹ $spent',
            Colors.orange,
            Icons.arrow_upward_rounded,
          ),
          _buildFinanceTile(
            'Balance',
            '₹ $balance',
            Colors.blue,
            Icons.account_balance_outlined,
          ),
          const SizedBox(height: 24),
          Text(
            'Budget Utilization (${usage.toStringAsFixed(1)}%)',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: usage / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: usage > 90
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    if (d is Timestamp) return DateFormat('dd MMM yyyy').format(d.toDate());
    if (d is String) return d;
    return '-';
  }

  int _calculateDuration() {
    final start = projectData?['actualStartDate'];
    if (start is! Timestamp) return 0;
    return DateTime.now().difference(start.toDate()).inDays;
  }

  Future<void> _generateAndPreviewPDF() async {
    final pdf = pw.Document();
    final primaryColor = Theme.of(context).primaryColor;
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    final budget = _parseNum(projectData?['projectBudget']);
    final spent = _parseNum(projectData?['amountSpent']);
    final received = _parseNum(projectData?['amountPaid']);
    final balance = budget - spent;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Financial Status Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (context) => [
          // Project Summary Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Project Name',
                widget.projectName,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Site ID',
                widget.siteId,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Client Name',
                widget.ownerName,
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Location',
                projectData?['siteLocation'] ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Start Date',
                _formatDate(projectData?['actualStartDate']),
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Duration',
                '${_calculateDuration()} Days',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Financial Table
          pw.Text(
            'Financial Breakdown',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: pdfPrimaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Financial Metric', 'Amount (INR)'],
            data: [
              ['Total Project Budget', budget.toStringAsFixed(2)],
              ['Total Amount Received', received.toStringAsFixed(2)],
              ['Total Amount Spent', spent.toStringAsFixed(2)],
              ['Remaining Balance', balance.toStringAsFixed(2)],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 32),

          // Progress Indicator (Visual represention)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary Analysis',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Budget Utilization: ',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '${budget > 0 ? (spent / budget * 100).toStringAsFixed(1) : 0}%',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfPrimaryColor,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text(
                      'Estimated Completion Weight: ',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '${projectData?['completionPercentage'] ?? 0}%',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
