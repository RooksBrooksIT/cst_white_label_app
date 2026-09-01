import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/firestore_service.dart';
import '/widgets/glass_scaffold.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import '/utils/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show TableHelper;
import 'package:printing/printing.dart';
import '/utils/pdf_templates.dart';

class MaterialReportPage extends StatefulWidget {
  const MaterialReportPage({super.key});

  @override
  State<MaterialReportPage> createState() => _MaterialReportPageState();
}

class _MaterialReportPageState extends State<MaterialReportPage> {
  List<String> materialNames = [];
  String? selectedMaterial;
  bool isLoadingNames = true;
  bool isReportLoading = false;
  List<SiteMaterialRow> reportRows = [];

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await FirestoreService.initialize();
    await _fetchMaterialNames();
  }

  Future<void> _fetchMaterialNames() async {
    try {
      final snapshot = await FirestoreService.materialCategories.get();
      final names = snapshot.docs
          .map(
            (doc) =>
                (doc.data()['matCategory'] ?? doc.data()['materialName'] ?? '')
                    .toString()
                    .trim(),
          )
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        materialNames = names;
        isLoadingNames = false;
      });
    } catch (e) {
      setState(() => isLoadingNames = false);
    }
  }

  Future<void> _fetchMaterialReport(String materialName) async {
    setState(() {
      isReportLoading = true;
      reportRows = [];
    });

    try {
      final q = await FirestoreService.getCollection(
        'materialsInventory',
      ).where('materialName', isEqualTo: materialName).get();
      final Map<String, double> qtyBySite = {};
      for (final doc in q.docs) {
        final data = doc.data();
        final sites = data['sites'];
        if (sites is List) {
          for (final s in sites) {
            if (s is Map<String, dynamic>) {
              final siteId = (s['siteId'] ?? s['siteid'] ?? '')
                  .toString()
                  .trim();
              if (siteId.isEmpty) continue;
              final qty = _parseNumber(s['materialQty']);
              qtyBySite.update(
                siteId,
                (prev) => prev + qty,
                ifAbsent: () => qty,
              );
            }
          }
        }
      }

      final rows = qtyBySite.entries
          .map((e) => SiteMaterialRow(siteId: e.key, qty: e.value))
          .toList();
      rows.sort(
        (a, b) => a.siteId.toLowerCase().compareTo(b.siteId.toLowerCase()),
      );

      setState(() {
        reportRows = rows;
        isReportLoading = false;
      });
    } catch (e) {
      setState(() => isReportLoading = false);
    }
  }

  double _parseNumber(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.+-]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final cardAccent = AppTheme.getCardAccent(primaryColor);

        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Materials Inventory Report',
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
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                onPressed: reportRows.isNotEmpty ? _generatePdf : null,
                tooltip: 'Export PDF Report',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                onPressed: selectedMaterial != null
                    ? () => _fetchMaterialReport(selectedMaterial!)
                    : null,
                tooltip: 'Refresh',
              ),
            ],
          ),
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
                    _buildSelectionCard(theme, cardAccent),
                    const SizedBox(height: 24),
                    if (selectedMaterial != null) ...[
                      _buildReportHeader(theme, cardAccent),
                      const SizedBox(height: 16),
                      if (isReportLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (reportRows.isEmpty)
                        _buildEmptyState(theme)
                      else
                        _buildReportTable(theme, cardAccent),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionCard(ThemeData theme, Color cardAccent) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVENTORY INSIGHTS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: cardAccent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a material to view its distribution across sites.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          if (isLoadingNames)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              initialValue: selectedMaterial,
              dropdownColor: Colors.white,
              iconEnabledColor: cardAccent,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Material Name',
                labelStyle: const TextStyle(
                  color: Color(0xFF5A759E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(Icons.inventory_2_outlined, color: cardAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: materialNames
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => selectedMaterial = val);
                if (val != null) _fetchMaterialReport(val);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(ThemeData theme, Color cardAccent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: cardAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'DISTRIBUTION REPORT',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cardAccent,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return GlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: const [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Colors.white70,
              ),
              SizedBox(height: 16),
              Text(
                'No site data found for this material.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTable(ThemeData theme, Color cardAccent) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1942).withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Across active sites',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${reportRows.length} sites',
                  style: TextStyle(
                    color: cardAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reportRows.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            itemBuilder: (ctx, i) {
              final row = reportRows[i];
              return ListTile(
                title: Text(
                  row.siteId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                trailing: Text(
                  row.qty.toStringAsFixed(row.qty % 1 == 0 ? 0 : 2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.toARGB32(),
    );
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Material Distribution Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Material Name',
                selectedMaterial ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Total Sites',
                '${reportRows.length}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          TableHelper.fromTextArray(
            headers: ['Site ID', 'Quantity'],
            data: reportRows
                .map(
                  (r) => [
                    r.siteId,
                    r.qty.toStringAsFixed(r.qty % 1 == 0 ? 0 : 2),
                  ],
                )
                .toList(),
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

class SiteMaterialRow {
  final String siteId;
  final double qty;
  SiteMaterialRow({required this.siteId, required this.qty});
}
