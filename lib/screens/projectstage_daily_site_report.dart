import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

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
  State<ProjectStageDailySiteExpensesReportPage> createState() => _ProjectStageDailySiteExpensesReportPageState();
}

class _ProjectStageDailySiteExpensesReportPageState extends State<ProjectStageDailySiteExpensesReportPage> {
  bool isLoading = true;
  Map<String, dynamic>? supervisorData;
  double grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  String get _documentId {
    final formattedDate = DateFormat('ddMMyyyy').format(widget.date);
    return '${widget.siteId}_$formattedDate';
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    try {
      final doc = await FirestoreService.getCollection('siteSupervisorEntries').doc(_documentId).get();
      if (doc.exists) {
        supervisorData = doc.data() as Map<String, dynamic>?;
        grandTotal = _toNum(supervisorData?['totalAmount']);
      }
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Daily Site Report',
      actions: [
        IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _generatePdf),
      ],
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : (supervisorData == null)
          ? _buildEmptyState(theme)
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildTotalCard(theme),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdown(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No records found for this date', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY SUMMARY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text(DateFormat('EEEE, dd MMMM yyyy').format(widget.date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Stage: ${widget.projectStage}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor,
      child: Column(
        children: [
          const Text('TOTAL EXPENSES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('₹ ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORIES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        _categoryItem('Material Costs', _calculateMaterials(), Icons.shopping_bag_outlined, theme),
        _categoryItem('Labour Charges', _calculateLabours(), Icons.people_outline, theme),
        _categoryItem('Site Expenses', _calculateMisc(), Icons.miscellaneous_services_outlined, theme),
      ],
    );
  }

  double _calculateMaterials() {
    double total = 0;
    if (supervisorData?['materials'] is List) {
      for (var m in supervisorData!['materials']) total += _toNum(m['amount']);
    }
    return total;
  }

  double _calculateLabours() {
    double total = 0;
    if (supervisorData?['labours'] is List) {
      for (var l in supervisorData!['labours']) total += _toNum(l['amount']);
    }
    return total;
  }

  double _calculateMisc() {
    return _toNum(supervisorData?['food']) + _toNum(supervisorData?['fuel']) + _toNum(supervisorData?['transport']);
  }

  Widget _categoryItem(String label, double amount, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(Theme.of(context).primaryColor.value);
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Daily Project Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Site ID', widget.siteId ?? 'N/A', pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Date', dateFormat.format(widget.date), pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Stage', widget.projectStage, pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Materials Table
          if (supervisorData?['materials'] != null && (supervisorData!['materials'] as List).isNotEmpty) ...[
            pw.Text('Materials Detailed Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Material', 'Quantity', 'Amount'],
              data: (supervisorData!['materials'] as List).map((m) => [
                m['materialName']?.toString() ?? 'N/A',
                m['quantity']?.toString() ?? '0',
                '₹ ${_toNum(m['amount']).toStringAsFixed(2)}',
              ]).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
            pw.SizedBox(height: 20),
          ],

          // Labours Table
          if (supervisorData?['labours'] != null && (supervisorData!['labours'] as List).isNotEmpty) ...[
            pw.Text('Labour Detailed Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Labour Type', 'Count', 'Amount'],
              data: (supervisorData!['labours'] as List).map((l) => [
                l['labourType']?.toString() ?? 'N/A',
                l['labourCount']?.toString() ?? '0',
                '₹ ${_toNum(l['amount']).toStringAsFixed(2)}',
              ]).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
            pw.SizedBox(height: 20),
          ],

          // Other Expenses
          pw.Text('Other Expenses Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Food / Mess', '₹ ${_toNum(supervisorData?['food']).toStringAsFixed(2)}'],
              ['Fuel / Transport', '₹ ${_toNum(supervisorData?['fuel']).toStringAsFixed(2)}'],
              ['Transport / Travel', '₹ ${_toNum(supervisorData?['transport']).toStringAsFixed(2)}'],
            ],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 32),

          // Grand Total
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: pdfPrimaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.Text('₹ ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }
}
