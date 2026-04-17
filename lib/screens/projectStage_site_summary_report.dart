import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';
import '../utils/project_stage_pdf_helper.dart';
import './pdf_preview_page.dart';

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
  bool isLoading = true;
  Map<String, dynamic>? projectInfo;
  Map<String, num> expenseTotals = {};
  num grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        _fetchProjectInfo(),
        _fetchExpenseTotals(),
      ]);
      setState(() {
        projectInfo = results[0] as Map<String, dynamic>?;
        expenseTotals = results[1] as Map<String, num>;
        grandTotal = expenseTotals.values.fold(0, (a, b) => a + b);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchProjectInfo() async {
    final snap = await FirestoreService.getCollection(
      'projects',
    ).where('siteId', isEqualTo: widget.siteId).limit(1).get();
    return snap.docs.isNotEmpty ? snap.docs.first.data() : null;
  }

  Future<Map<String, num>> _fetchExpenseTotals() async {
    final query = await FirestoreService.getCollection('siteSupervisorEntries')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .get();

    num food = 0, fuel = 0, transport = 0, labours = 0, materials = 0;
    for (var doc in query.docs) {
      final data = doc.data();
      food += _toNum(data['food']);
      fuel += _toNum(data['fuel']);
      transport += _toNum(data['transport']);

      if (data['labours'] is List) {
        for (var l in data['labours']) labours += _toNum(l['amount']);
      }
      if (data['materials'] is List) {
        for (var m in data['materials']) materials += _toNum(m['amount']);
      }
    }
    return {
      'Food': food,
      'Fuel': fuel,
      'Transport': transport,
      'Labours': labours,
      'Materials': materials,
    };
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Site Summary Report',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _generatePdf,
        ),
      ],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProjectCard(theme),
                  const SizedBox(height: 24),
                  _buildFinanceCard(theme),
                  const SizedBox(height: 24),
                  _buildBreakdownSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildProjectCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectInfo?['projectName'] ?? 'Project Summary',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Stage: ${widget.projectStage}',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 24),
          _infoRow('Site Location', projectInfo?['siteLocation'] ?? 'N/A'),
          _infoRow('Owner Name', projectInfo?['ownerName'] ?? 'N/A'),
          _infoRow('Status', projectInfo?['status'] ?? 'Active'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(ThemeData theme) {
    final budget = _toNum(projectInfo?['projectBudget']);
    final progress = budget > 0 ? (grandTotal / budget).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STAGE FINANCE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spent: ₹ ${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Budget: ₹ ${budget.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
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
        ...expenseTotals.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹ ${e.value.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf() async {
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.value,
    );
    try {
      final pdfBytes = await ProjectStagePdfHelper.buildSiteSummaryReport(
        siteId: widget.siteId,
        projectStage: widget.projectStage,
        projectInfo: projectInfo,
        expenseTotals: expenseTotals,
        grandTotal: grandTotal,
        primaryColor: pdfPrimaryColor,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName: 'SiteSummary_${widget.siteId}_${widget.projectStage}.pdf',
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
