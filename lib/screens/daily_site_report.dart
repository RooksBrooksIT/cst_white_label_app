import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

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
  String get _documentId {
    final formattedDate = DateFormat('ddMMyyyy').format(widget.date);
    return '${widget.siteId}_$formattedDate';
  }

  Future<Map<String, dynamic>> _fetchAllReports() async {
    final supervisorDoc = await FirestoreService.getCollection(
      'siteSupervisorEntries',
    ).doc(_documentId).get();
    final managerQuery = await FirestoreService.getCollection(
      'managerExpenses',
    ).where('siteId', isEqualTo: widget.siteId).limit(20).get();
    final orgQuery = await FirestoreService.getCollection(
      'organizationExpenses',
    ).where('siteId', isEqualTo: widget.siteId).limit(20).get();
    final contractorQuery =
        await FirestoreService.getCollection('contractorEntries')
            .where('siteId', isEqualTo: widget.siteId)
            .where(
              'date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(widget.date),
            )
            .limit(20)
            .get();
    final incentiveQuery =
        await FirestoreService.getCollection('totalSiteExpensesPerDay')
            .where('siteId', isEqualTo: widget.siteId)
            .where(
              'date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(widget.date),
            )
            .limit(1)
            .get();

    return {
      'supervisor': supervisorDoc.exists ? supervisorDoc : null,
      'managerEntries': managerQuery.docs,
      'organizationEntries': orgQuery.docs,
      'contractorEntries': contractorQuery.docs,
      'incentiveDoc': incentiveQuery.docs.isNotEmpty
          ? incentiveQuery.docs.first
          : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final dateStr = DateFormat('dd MMM yyyy').format(widget.date);

    return GlassScaffold(
      title: 'Daily Site Report',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => _handlePdfExport(context),
        ),
      ],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));

          final data = snapshot.data!;
          final supervisorDoc = data['supervisor'] as DocumentSnapshot?;
          final managerEntries =
              data['managerEntries'] as List<DocumentSnapshot>;
          final orgEntries =
              data['organizationEntries'] as List<DocumentSnapshot>;
          final contractorEntries =
              data['contractorEntries'] as List<DocumentSnapshot>;
          final incentiveDoc = data['incentiveDoc'] as DocumentSnapshot?;

          if (supervisorDoc == null &&
              managerEntries.isEmpty &&
              orgEntries.isEmpty &&
              contractorEntries.isEmpty &&
              incentiveDoc == null) {
            return _buildNoDataView(theme, dateStr);
          }

          final supervisorData = supervisorDoc?.data() as Map<String, dynamic>?;
          final totalAmount = _calculateTotal(data);

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryHeader(theme, dateStr, totalAmount),
                const SizedBox(height: 24),
                if (supervisorData != null)
                  _buildSupervisorSection(theme, supervisorData),
                if (managerEntries.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildBillsSection(theme, 'Manager Expenses', managerEntries),
                ],
                if (orgEntries.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildBillsSection(
                    theme,
                    'Organization Expenses',
                    orgEntries,
                  ),
                ],
                if (contractorEntries.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildContractorSection(theme, contractorEntries),
                ],
                const SizedBox(height: 40),
                GlassButton(
                  label: 'EXPORT FULL REPORT',
                  onPressed: () => _handlePdfExport(context),
                  icon: Icons.picture_as_pdf,
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoDataView(ThemeData theme, String dateStr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No entries found for $dateStr',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: 'REFRESH',
            onPressed: () => setState(() {}),
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, String date, num total) {
    return GlassCard(
      color: theme.primaryColor,
      child: Column(
        children: [
          Text(
            'TOTAL DAILY EXPENDITURE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${total.toStringAsFixed(2)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorSection(ThemeData theme, Map<String, dynamic> data) {
    final labours = List<Map<String, dynamic>>.from(data['labours'] ?? []);
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITE SUPERVISOR ENTRIES',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (labours.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Labour'),
            ...labours.map(
              (l) => _buildDetailRow(
                l['type'],
                '${l['count']} workers',
                '₹${l['amount']}',
              ),
            ),
            const Divider(height: 24),
          ],
          if (materials.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Materials'),
            ...materials.map(
              (m) => _buildDetailRow(
                m['type'],
                '${m['quantity']} units',
                '₹${m['amount']}',
              ),
            ),
            const Divider(height: 24),
          ],
          _buildSectionTitle(theme, 'Other Expenses'),
          _buildDetailRow('Food', '', '₹${data['food'] ?? 0}'),
          _buildDetailRow('Fuel', '', '₹${data['fuel'] ?? 0}'),
          _buildDetailRow('Transport', '', '₹${data['transport'] ?? 0}'),
          const Divider(height: 24),
          _buildTotalRow(theme, 'Supervisor Total', data['totalAmount'] ?? 0),
        ],
      ),
    );
  }

  Widget _buildBillsSection(
    ThemeData theme,
    String title,
    List<DocumentSnapshot> entries,
  ) {
    num total = 0;
    final List<Map<String, dynamic>> allBills = [];
    for (var doc in entries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = List<Map<String, dynamic>>.from(data['bills'] ?? []);
      for (var bill in bills) {
        allBills.add(bill);
        total += _parseAmount(bill['billAmount']);
      }
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...allBills.map(
            (b) => _buildDetailRow(
              b['billVendor'],
              'Bill: ${b['billNo']}',
              '₹${b['billAmount']}',
            ),
          ),
          const Divider(height: 24),
          _buildTotalRow(theme, '$title Total', total),
        ],
      ),
    );
  }

  Widget _buildContractorSection(
    ThemeData theme,
    List<DocumentSnapshot> entries,
  ) {
    num total = 0;
    for (var doc in entries)
      total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTRACTOR EXPENSES',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${entries.length} contractor entries recorded for this site.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildTotalRow(theme, 'Contractor Total', total),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String subtitle, String amount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(ThemeData theme, String label, num total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '₹ ${total.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }

  num _calculateTotal(Map<String, dynamic> data) {
    num total = 0;
    final supervisorDoc = data['supervisor'] as DocumentSnapshot?;
    if (supervisorDoc != null)
      total +=
          (supervisorDoc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;

    for (var doc in data['managerEntries'] as List<DocumentSnapshot>) {
      final bills =
          (doc.data() as Map<String, dynamic>)['bills'] as List? ?? [];
      for (var b in bills) total += _parseAmount(b['billAmount']);
    }

    for (var doc in data['organizationEntries'] as List<DocumentSnapshot>) {
      final bills =
          (doc.data() as Map<String, dynamic>)['bills'] as List? ?? [];
      for (var b in bills) total += _parseAmount(b['billAmount']);
    }

    for (var doc in data['contractorEntries'] as List<DocumentSnapshot>) {
      total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;
    }

    if (data['incentiveDoc'] != null) {
      total +=
          (data['incentiveDoc'] as DocumentSnapshot).data()
              as Map<String, dynamic>? ??
          {}['totalIncentiveExpenses'] ??
          0;
    }

    return total;
  }

  num _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  Future<void> _handlePdfExport(BuildContext context) async {
    // Basic implementation for now, mirroring the logic in other report pages
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) =>
            pw.Center(child: pw.Text('Daily Site Report - Export')),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
