import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_templates.dart';
import '../services/firestore_service.dart';

class ContractorReportPage extends StatefulWidget {
  const ContractorReportPage({super.key});

  @override
  _ContractorReportPageState createState() => _ContractorReportPageState();
}

class _ContractorReportPageState extends State<ContractorReportPage> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoadingExpenses = false;
  double totalAmount = 0.0;
  String? selectedContractor;
  List<String> contractorNames = [];
  String? selectedSiteId;
  List<String> siteIdOptions = [];
  bool isLoadingContractors = false;
  bool isLoadingSites = false;

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    await _fetchContractorNames();
  }

  Future<void> _fetchContractorNames() async {
    if (mounted) setState(() => isLoadingContractors = true);
    try {
      debugPrint(
        'ContractorReportPage: Fetching contractors from ${FirestoreService.contractors.path}',
      );

      // 1. Fetch from contractors collection
      final contractorsSnapshot = await FirestoreService.contractors
          .orderBy('contractorName')
          .limit(500)
          .get();

      final Set<String> allNames = {};

      for (var doc in contractorsSnapshot.docs) {
        final name = (doc.data()['contractorName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) allNames.add(name);
      }

      // 2. Also check contractorEntries to ensure we have everyone who has entries
      final entriesSnapshot = await FirestoreService.contractorEntries
          .limit(500) // Just a sample to find active contractors
          .get();

      for (var doc in entriesSnapshot.docs) {
        final name = (doc.data()['contractorName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) allNames.add(name);
      }

      final sortedNames = allNames.toList();
      sortedNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      debugPrint(
        'ContractorReportPage: Found ${sortedNames.length} contractors',
      );
      if (mounted) {
        setState(() {
          contractorNames = sortedNames;
          if (sortedNames.isNotEmpty) {
            selectedContractor = sortedNames.first;
          }
          isLoadingContractors = false;
        });
        if (selectedContractor != null) {
          await _fetchSiteIdsForContractor(selectedContractor!);
        }
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching contractors: $e');
      if (mounted) setState(() => isLoadingContractors = false);
    }
  }

  Future<void> _fetchSiteIdsForContractor(String contractorName) async {
    if (mounted) {
      setState(() {
        isLoadingSites = true;
        siteIdOptions = [];
        selectedSiteId = null;
      });
    }
    try {
      debugPrint('ContractorReportPage: Fetching site IDs for $contractorName');

      final Set<String> allSiteIds = {};

      // 1. Fetch from projects collection
      Query<Map<String, dynamic>> projectQuery = FirestoreService.projects
          .where('isContractWork', isEqualTo: true);

      projectQuery = projectQuery.where(
        'contractorName',
        isEqualTo: contractorName,
      );

      final projectSnapshot = await projectQuery.limit(500).get();
      for (var doc in projectSnapshot.docs) {
        final sid = doc.data()['siteId']?.toString().trim();
        if (sid != null && sid.isNotEmpty) allSiteIds.add(sid);
      }

      // 2. Fetch from contractorEntries to ensure we have all sites with data
      Query<Map<String, dynamic>> entriesQuery =
          FirestoreService.contractorEntries;
      entriesQuery = entriesQuery.where(
        'contractorName',
        isEqualTo: contractorName,
      );

      final entriesSnapshot = await entriesQuery.limit(500).get();
      for (var doc in entriesSnapshot.docs) {
        final sid = doc.data()['siteId']?.toString().trim();
        if (sid != null && sid.isNotEmpty) allSiteIds.add(sid);
      }

      final sortedIds = allSiteIds.toList();
      sortedIds.sort();

      debugPrint('ContractorReportPage: Found ${sortedIds.length} site IDs');
      if (mounted) {
        setState(() {
          siteIdOptions = sortedIds;
          if (sortedIds.isNotEmpty) {
            selectedSiteId = sortedIds.first;
          }
          isLoadingSites = false;
        });
        if (selectedSiteId != null) {
          _fetchExpenses();
        }
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching site IDs: $e');
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  Future<void> _fetchExpenses() async {
    if (selectedContractor == null || selectedSiteId == null) return;
    if (mounted) {
      setState(() {
        isLoadingExpenses = true;
        expenses = [];
        totalAmount = 0.0;
      });
    }
    try {
      debugPrint(
        'ContractorReportPage: Fetching expenses for $selectedContractor at $selectedSiteId',
      );

      final querySnapshot = await FirestoreService.contractorEntries
          .where('contractorName', isEqualTo: selectedContractor)
          .where('siteId', isEqualTo: selectedSiteId)
          .limit(1000)
          .get();

      if (!mounted) return;
      double sum = 0.0;
      final List<Map<String, dynamic>> fetched = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final amt = data['totalAmount'] ?? data['amount'] ?? 0;
        sum += (amt is num)
            ? amt.toDouble()
            : (double.tryParse(amt.toString()) ?? 0.0);
        fetched.add(data);
      }
      debugPrint(
        'ContractorReportPage: Found ${fetched.length} entries, total: $sum',
      );
      if (mounted) {
        setState(() {
          expenses = fetched;
          totalAmount = sum;
          isLoadingExpenses = false;
        });
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching expenses: $e');
      if (mounted) setState(() => isLoadingExpenses = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Contractor Report',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          onPressed: expenses.isNotEmpty ? _generatePdf : null,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterCard(theme),
                const SizedBox(height: 24),
                if (isLoadingExpenses)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (expenses.isNotEmpty)
                  _buildReportSection(theme)
                else if (selectedContractor != null && selectedSiteId != null)
                  _buildEmptyState(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Parameters',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            'Contractor Name',
            contractorNames,
            selectedContractor,
            (v) async {
              setState(() => selectedContractor = v);
              if (v != null) {
                await _fetchSiteIdsForContractor(v);
                _fetchExpenses(); // Auto-refresh report
              }
            },
            isLoadingContractors,
          ),
          const SizedBox(height: 16),
          _buildDropdown('Site ID', siteIdOptions, selectedSiteId, (v) {
            setState(() => selectedSiteId = v);
            _fetchExpenses(); // Auto-refresh report
          }, isLoadingSites),
          const SizedBox(height: 24),
          GlassButton(
            label: 'GENERATE REPORT',
            onPressed: selectedContractor != null && selectedSiteId != null
                ? _fetchExpenses
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
    bool loading,
  ) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.cardColor,
        suffixIcon: loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildReportSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          color: theme.primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL PAYABLE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '₹ ${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'ENTRY LOG',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final exp = expenses[i];
            final date = _formatDate(exp['date']);
            final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
            return GlassCard(
              onTap: () => _showEntryDetails(exp),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Site: ${exp['siteId']}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹ $amt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Text('No records found for this selection.'),
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    if (d is Timestamp) return DateFormat('dd MMM yyyy').format(d.toDate());
    if (d is String) return d;
    return '-';
  }

  void _showEntryDetails(Map<String, dynamic> exp) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Entry Breakdown',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _detailRow('Date', _formatDate(exp['date'])),
              _detailRow('Food', '₹ ${exp['food'] ?? 0}'),
              _detailRow('Fuel', '₹ ${exp['fuel'] ?? 0}'),
              _detailRow('Transport', '₹ ${exp['transport'] ?? 0}'),
              const Divider(height: 32),
              _detailRow(
                'Total Amount',
                '₹ ${exp['totalAmount'] ?? exp['amount'] ?? 0}',
                isBold: true,
              ),
              const SizedBox(height: 24),
              GlassButton(
                label: 'CLOSE',
                onPressed: () => Navigator.pop(context),
                isSecondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.value,
    );
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Contractor Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Contractor',
                selectedContractor ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Site ID',
                selectedSiteId ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Total Payable',
                '₹ ${totalAmount.toStringAsFixed(2)}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Table.fromTextArray(
            headers: ['Date', 'Details', 'Amount'],
            data: expenses.map((exp) {
              final date = _formatDate(exp['date']);
              final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
              final details =
                  'Food: ${exp['food'] ?? 0}, Fuel: ${exp['fuel'] ?? 0}, Trans: ${exp['transport'] ?? 0}';
              return [date, details, '₹ $amt'];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
