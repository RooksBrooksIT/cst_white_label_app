import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class MaterialInventoryDetailsPage extends StatefulWidget {
  final String materialName;
  final String category;
  final String unit;
  final String code;

  const MaterialInventoryDetailsPage({
    super.key,
    required this.materialName,
    this.category = 'General Material',
    this.unit = 'Units',
    this.code = '',
  });

  @override
  State<MaterialInventoryDetailsPage> createState() =>
      _MaterialInventoryDetailsPageState();
}

class _MaterialInventoryDetailsPageState
    extends State<MaterialInventoryDetailsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  double _companyQty = 0.0;
  List<Map<String, dynamic>> _siteBreakdown = [];

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchMaterialDetails();
  }

  Future<void> _fetchMaterialDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch sites and projects metadata for human-friendly names
      final sitesSnap = await FirestoreService.getCollection('Site').get();
      final projectsSnap = await FirestoreService.projects.get();

      final sNameMap = <String, String>{};
      final sProjMap = <String, String>{};

      for (var d in sitesSnap.docs) {
        final data = d.data();
        final sId = (data['siteId'] ?? d.id).toString();
        final sName = (data['siteName'] ?? data['projectName'] ?? sId).toString();
        final pName = (data['projectName'] ?? '').toString();
        sNameMap[sId] = sName;
        if (pName.isNotEmpty) sProjMap[sId] = pName;
      }

      for (var d in projectsSnap.docs) {
        final data = d.data();
        final sId = (data['siteId'] ?? d.id).toString();
        final pName = (data['projectName'] ?? '').toString();
        if (sNameMap[sId] == null || sNameMap[sId] == sId) {
          sNameMap[sId] = pName.isNotEmpty ? pName : sId;
        }
        if (pName.isNotEmpty) sProjMap[sId] = pName;
      }

      // 2. Fetch Company / Central storage stock
      double compQty = 0.0;
      try {
        final compDoc = await FirestoreService.getCollection('materialsAtCompany')
            .doc(widget.materialName)
            .get();
        if (compDoc.exists) {
          compQty = _parseNum(compDoc.data()?['quantity'] ?? compDoc.data()?['availableCount']);
        }
      } catch (_) {}

      // 3. Fetch materialsInventory
      final Map<String, double> siteQtyMap = {};
      final Map<String, String> siteLastUpdated = {};

      try {
        final invSnap = await FirestoreService.getCollection('materialsInventory')
            .where('materialName', isEqualTo: widget.materialName)
            .get();

        for (var doc in invSnap.docs) {
          final data = doc.data();
          final sites = data['sites'];
          if (sites is List) {
            for (var s in sites) {
              if (s is Map<String, dynamic>) {
                final sId = (s['siteId'] ?? s['siteid'] ?? '').toString().trim();
                if (sId.isEmpty) continue;
                final qty = _parseNum(s['materialQty'] ?? s['quantity']);
                siteQtyMap.update(sId, (prev) => prev + qty, ifAbsent: () => qty);
                if (s['updatedAt'] != null || s['date'] != null) {
                  siteLastUpdated[sId] = (s['updatedAt'] ?? s['date']).toString();
                }
              }
            }
          }
        }
      } catch (_) {}

      // 4. Also fetch materialsAtSite collection for any direct logs
      try {
        final atSiteSnap = await FirestoreService.getCollection('materialsAtSite')
            .where('materialName', isEqualTo: widget.materialName)
            .get();

        for (var doc in atSiteSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['site'] ?? '').toString().trim();
          if (sId.isNotEmpty) {
            final qty = _parseNum(data['quantity'] ?? data['availableCount'] ?? data['materialQty']);
            siteQtyMap.update(sId, (prev) => prev + qty, ifAbsent: () => qty);
          }
        }
      } catch (_) {}

      final List<Map<String, dynamic>> breakdown = [];
      siteQtyMap.forEach((sId, qty) {
        if (qty > 0) {
          breakdown.add({
            'siteId': sId,
            'siteName': sNameMap[sId] ?? sId,
            'projectName': sProjMap[sId] ?? sNameMap[sId] ?? 'Site Project',
            'quantity': qty,
            'lastUpdated': siteLastUpdated[sId] ?? 'Active Stock',
          });
        }
      });

      breakdown.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));

      if (mounted) {
        setState(() {
          _companyQty = compQty;
          _siteBreakdown = breakdown;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load details: $e';
        });
      }
    }
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.+-]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  String _formatQty(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  Future<void> _exportPdfReport() async {
    try {
      final pdf = pw.Document();
      final totalSiteStock = _siteBreakdown.fold<double>(
        0.0,
        (acc, item) => acc + (item['quantity'] as double),
      );
      final totalStock = _companyQty + totalSiteStock;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MATERIAL INVENTORY REPORT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        widget.materialName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Category: ${widget.category}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            // Metric Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Stock', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${_formatQty(totalStock)} ${widget.unit}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('At Company', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${_formatQty(_companyQty)} ${widget.unit}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('At Sites', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${_formatQty(totalSiteStock)} ${widget.unit}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Site-by-Site Distribution Breakdown',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Site ID', 'Site Name', 'Project', 'Quantity (${widget.unit})'],
              data: _siteBreakdown.map((s) => [
                s['siteId'],
                s['siteName'],
                s['projectName'],
                _formatQty(s['quantity'] as double),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Material_Report_${widget.materialName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to export PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final totalSiteStock = _siteBreakdown.fold<double>(
      0.0,
      (acc, item) => acc + (item['quantity'] as double),
    );
    final totalStock = _companyQty + totalSiteStock;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.materialName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
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
            tooltip: 'Export PDF Report',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            onPressed: _siteBreakdown.isNotEmpty || _companyQty > 0 ? _exportPdfReport : null,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _fetchMaterialDetails,
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 700,
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchMaterialDetails,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMaterialDetails,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                          children: [
                            // ── Header Card ───────────────────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_rounded,
                                          color: Color(0xFF7C3AED),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.materialName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    widget.category,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '•  Unit: ${widget.unit}',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 14),

                                  // KPI Metric Grid
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildKPI(
                                          title: 'Total Stock',
                                          value: '${_formatQty(totalStock)} ${widget.unit}',
                                          color: primaryColor,
                                          icon: Icons.all_inbox_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildKPI(
                                          title: 'At Company',
                                          value: '${_formatQty(_companyQty)} ${widget.unit}',
                                          color: const Color(0xFF0EA5E9),
                                          icon: Icons.warehouse_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildKPI(
                                          title: 'At Sites',
                                          value: '${_formatQty(totalSiteStock)} ${widget.unit}',
                                          color: const Color(0xFF10B981),
                                          icon: Icons.location_city_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Section Title ───────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'SITE-WISE STOCK DISTRIBUTION',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_siteBreakdown.length} Sites',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Sites List ──────────────────────────────
                            if (_siteBreakdown.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: const [
                                    Icon(Icons.location_off_rounded, size: 38, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 10),
                                    Text(
                                      'No site stock deployed yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Material allocations to construction sites will appear here.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _siteBreakdown.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final site = _siteBreakdown[index];
                                  final qty = site['quantity'] as double;
                                  final pct = totalStock > 0 ? (qty / totalStock) * 100 : 0.0;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0A183D).withValues(alpha: 0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFDCFCE7)),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.location_on_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                site['siteName'].toString(),
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Site ID: ${site['siteId']}  •  ${pct.toStringAsFixed(1)}% of total',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatQty(qty),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              Text(
                                                widget.unit,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPI({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
