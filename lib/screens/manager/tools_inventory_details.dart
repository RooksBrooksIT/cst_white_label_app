import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:demo_cst/utils/pdf_templates.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ToolsInventoryDetailsPage extends StatefulWidget {
  final String toolCode;
  const ToolsInventoryDetailsPage({super.key, required this.toolCode});

  @override
  State<ToolsInventoryDetailsPage> createState() =>
      _ToolsInventoryDetailsPageState();
}

class _ToolsInventoryDetailsPageState extends State<ToolsInventoryDetailsPage> {
  List<Map<String, dynamic>> inventoryData = [];
  bool isLoading = true;
  String? errorMessage;
  String toolName = "";
  String toolCategory = "";
  String toolDescription = "";
  String toolOwner = "";
  int toolMasterTotal = 0;
  int companyAvailable = 0;
  Map<String, String> siteNameMap = {};
  Map<String, String> siteProjectMap = {};

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // 1. Fetch tool master data
      final toolMasterDoc = await FirestoreService.getCollection('tools')
          .where('toolCode', isEqualTo: widget.toolCode)
          .limit(1)
          .get();

      String name = "";
      String category = "";
      String description = "";
      String owner = "Org";
      int masterCount = 0;

      if (toolMasterDoc.docs.isNotEmpty) {
        final data = toolMasterDoc.docs.first.data();
        name = data['toolName']?.toString() ?? "";
        category = data['toolCategory']?.toString() ?? "";
        description = data['description']?.toString() ?? "";
        owner = data['toolOwner']?.toString() ?? "Org";
        masterCount = (data['toolCount'] as num?)?.toInt() ?? 0;
      }

      // Fetch company available stock
      int compCount = 0;
      try {
        final compDoc = await FirestoreService.getCollection('toolsAtCompany')
            .where('toolCode', isEqualTo: widget.toolCode)
            .limit(1)
            .get();
        if (compDoc.docs.isNotEmpty) {
          compCount = (compDoc.docs.first.data()['availableCount'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      // 2. Fetch tool distribution data from toolsInventory collection
      final query = await FirestoreService.getCollection('toolsInventory')
          .doc(widget.toolCode)
          .get();

      Map<String, int> siteCounts = {};

      if (query.exists) {
        final data = query.data() as Map<String, dynamic>;

        // Check map format: availableCountAtSites: { siteId: count }
        if (data['availableCountAtSites'] is Map) {
          final map = Map<String, dynamic>.from(data['availableCountAtSites']);
          map.forEach((k, v) {
            final c = (v as num?)?.toInt() ?? 0;
            if (c > 0) siteCounts[k] = c;
          });
        }

        // Check list format: sites: [{ siteId, count }]
        if (data['sites'] is List) {
          final list = data['sites'] as List<dynamic>;
          for (var s in list) {
            final sId = s['siteId']?.toString() ?? '';
            final c = (s['count'] as num?)?.toInt() ?? 0;
            if (sId.isNotEmpty && c > 0) {
              siteCounts[sId] = (siteCounts[sId] ?? 0) + c;
            }
          }
        }
      } else {
        // Fallback: query where toolCode == widget.toolCode
        final searchByField = await FirestoreService.getCollection('toolsInventory')
            .where('toolCode', isEqualTo: widget.toolCode)
            .limit(1)
            .get();
        if (searchByField.docs.isNotEmpty) {
          final data = searchByField.docs.first.data();
          if (data['availableCountAtSites'] is Map) {
            final map = Map<String, dynamic>.from(data['availableCountAtSites']);
            map.forEach((k, v) {
              final c = (v as num?)?.toInt() ?? 0;
              if (c > 0) siteCounts[k] = c;
            });
          }
          if (data['sites'] is List) {
            final list = data['sites'] as List<dynamic>;
            for (var s in list) {
              final sId = s['siteId']?.toString() ?? '';
              final c = (s['count'] as num?)?.toInt() ?? 0;
              if (sId.isNotEmpty && c > 0) {
                siteCounts[sId] = (siteCounts[sId] ?? 0) + c;
              }
            }
          }
        }
      }

      // 3. Fetch site details for display
      final Map<String, String> names = {};
      final Map<String, String> projects = {};

      try {
        final sitesSnapshot = await FirestoreService.sites.get();
        for (var s in sitesSnapshot.docs) {
          final d = s.data();
          names[s.id] = d['siteName']?.toString() ?? s.id;
          projects[s.id] = d['projectName']?.toString() ?? '';
        }
      } catch (_) {}

      try {
        final mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap').get();
        for (var s in mapSnapshot.docs) {
          final d = s.data();
          final siteId = (d['site'] ?? s.id).toString();
          if (!names.containsKey(siteId) || names[siteId] == siteId) {
            names[siteId] = d['projectName']?.toString() ?? siteId;
          }
          projects[siteId] = d['projectName']?.toString() ?? '';
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          toolName = name;
          toolCategory = category;
          toolDescription = description;
          toolOwner = owner;
          toolMasterTotal = masterCount;
          companyAvailable = compCount;
          siteNameMap = names;
          siteProjectMap = projects;
          inventoryData = siteCounts.entries
              .where((entry) => entry.value > 0)
              .map((entry) => {'siteId': entry.key, 'toolsCount': entry.value})
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load distribution data: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _generatePdf(BuildContext context) async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.toARGB32());
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final totalSiteDistributed = inventoryData.fold<int>(0, (acc, item) => acc + (item['toolsCount'] as int));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Tools Distribution Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          // Tool Details Meta Grid
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    PdfTemplates.buildMetaBox('Tool Name', toolName.isNotEmpty ? toolName : widget.toolCode, pdfPrimaryColor),
                    PdfTemplates.buildMetaBox('Tool Code', widget.toolCode, pdfPrimaryColor),
                    PdfTemplates.buildMetaBox('Ownership', toolOwner, pdfPrimaryColor),
                  ],
                ),
                if (toolDescription.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  PdfTemplates.buildMetaBox('Description', toolDescription, pdfPrimaryColor),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Total Stock Overview Row
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('AT COMPANY STORAGE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('$companyAvailable Units', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DEPLOYED AT SITES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.SizedBox(height: 4),
                      pw.Text('$totalSiteDistributed Units', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          pw.Text(
            'Site Distribution Breakdown',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: pdfPrimaryColor,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Site ID', 'Site / Project Name', 'Allocated Units', 'Share %'],
            data: inventoryData.map((item) {
              final siteId = item['siteId'].toString();
              final siteName = siteNameMap[siteId] ?? siteProjectMap[siteId] ?? "Unnamed Site";
              final count = item['toolsCount'] as int;
              final percent = totalSiteDistributed > 0
                  ? '${((count / totalSiteDistributed) * 100).toStringAsFixed(1)}%'
                  : '0%';

              return [
                siteId,
                siteName,
                '$count Units',
                percent,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: pw.BoxDecoration(
              color: pdfPrimaryColor,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 20),

          pw.Divider(thickness: 1, color: pdfPrimaryColor),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Active Deployments Across Sites: ${inventoryData.length} Locations',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
              ),
              pw.Text(
                'Total Units: $totalSiteDistributed',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
            ],
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tool Distribution Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _fetchInventoryData,
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? _buildErrorView(errorMessage!)
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildToolHeaderCard(darkAccent),
                            const SizedBox(height: 16),
                            _buildDistributionSection(darkAccent),
                            const SizedBox(height: 20),
                            _buildActionButtons(context),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchInventoryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolHeaderCard(Color darkAccent) {
    final isRental = toolOwner.toLowerCase() == 'rental';
    final totalSiteDistributed = inventoryData.fold<int>(0, (acc, item) => acc + (item['toolsCount'] as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isRental ? Colors.amber.shade50 : primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRental ? Colors.amber.shade300 : primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.handyman_rounded,
                  color: isRental ? Colors.amber.shade800 : primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRental
                                ? Colors.amber.withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRental ? 'RENTAL TOOL' : 'ORGANIZATION TOOL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isRental ? Colors.amber.shade900 : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      toolName.isNotEmpty ? toolName : widget.toolCode,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    Text(
                      'Tool Code: ${widget.toolCode}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (toolDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                toolDescription,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),

          // Stock metrics summary
          Row(
            children: [
              Expanded(
                child: _buildMiniStockCard(
                  label: 'Company Storage',
                  count: companyAvailable,
                  color: const Color(0xFF0EA5E9),
                  icon: Icons.warehouse_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStockCard(
                  label: 'Sites Deployed',
                  count: totalSiteDistributed,
                  color: const Color(0xFF10B981),
                  icon: Icons.location_city_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStockCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  '$count Units',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionSection(Color darkAccent) {
    final totalDistributed = inventoryData.fold<int>(0, (acc, item) => acc + (item['toolsCount'] as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allocated Sites (${inventoryData.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TOTAL: $totalDistributed UNITS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (inventoryData.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No active site allocations for this tool',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inventoryData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = inventoryData[index];
                final siteId = item['siteId'].toString();
                final siteName = siteNameMap[siteId] ?? siteProjectMap[siteId] ?? "Site $siteId";
                final count = item['toolsCount'] as int;
                final share = totalDistributed > 0 ? (count / totalDistributed) : 0.0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              siteId,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              siteName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: darkAccent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '$count Units',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: darkAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: share,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(share * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: const Text(
                'EXPORT DISTRIBUTION PDF',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              onPressed: () => _generatePdf(context),
            ),
          ),
        ),
      ],
    );
  }
}
