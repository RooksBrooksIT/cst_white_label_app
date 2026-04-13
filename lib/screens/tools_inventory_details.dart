import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

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
  Map<String, String> siteNameMap = {};

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
      String owner = "";

      if (toolMasterDoc.docs.isNotEmpty) {
        final data = toolMasterDoc.docs.first.data();
        name = data['toolName']?.toString() ?? "";
        category = data['toolCategory']?.toString() ?? "";
        description = data['description']?.toString() ?? "";
        owner = data['toolOwner']?.toString() ?? "";
      }

      // 2. Fetch tool distribution data from toolsInventory collection
      // Document ID should be the toolCode
      final query = await FirestoreService.getCollection('toolsInventory')
          .doc(widget.toolCode)
          .get();

      List<dynamic> sites = [];
      if (query.exists) {
        sites = query.data()?['sites'] as List<dynamic>? ?? [];
      } else {
        // Fallback: search by toolCode field if doc ID is different
        final searchByField = await FirestoreService.getCollection('toolsInventory')
            .where('toolCode', isEqualTo: widget.toolCode)
            .limit(1)
            .get();
        if (searchByField.docs.isNotEmpty) {
          sites = searchByField.docs.first.data()['sites'] as List<dynamic>? ?? [];
        }
      }

      // 3. Fetch all site names for lookup
      final sitesSnapshot = await FirestoreService.sites.get();
      final names = {
        for (var s in sitesSnapshot.docs)
          s.id: s.data()['siteName']?.toString() ?? 'Unnamed Site'
      };

      // 4. Aggregate counts by siteId to avoid duplicates and handle zero counts
      Map<String, int> siteCounts = {};

      for (var site in sites) {
        final siteId = site['siteId'] ?? '';
        final count = (site['count'] ?? 0) as int;
        if (siteCounts.containsKey(siteId)) {
          siteCounts[siteId] = siteCounts[siteId]! + count;
        } else {
          siteCounts[siteId] = count;
        }
      }

      setState(() {
        toolName = name;
        toolCategory = category;
        toolDescription = description;
        toolOwner = owner;
        siteNameMap = names;
        // Only keep active site distributions (count > 0)
        inventoryData = siteCounts.entries
            .where((entry) => entry.value > 0)
            .map((entry) {
              return {'siteId': entry.key, 'toolsCount': entry.value};
            })
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load data: ${e.toString()}';
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
    final primaryColor = Theme.of(context).primaryColor;
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Tools Distribution Report",
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: pdfPrimaryColor),
              pw.SizedBox(height: 16),
              pw.Text(
                "Tool Details",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Bullet(
                text: "Name: ${toolName.isNotEmpty ? toolName : "N/A"}",
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.Bullet(
                text: "Category: ${toolCategory.isNotEmpty ? toolCategory : "Uncategorized"}",
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.Bullet(
                text: "Tool Code: ${widget.toolCode}",
                style: pw.TextStyle(fontSize: 14),
              ),
              if (toolOwner.isNotEmpty)
                pw.Bullet(
                  text: "Owner: $toolOwner",
                  style: pw.TextStyle(fontSize: 14),
                ),
              pw.SizedBox(height: 24),
              pw.Text(
                "Distribution by Site",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: ['Site ID', 'Site Name', 'Tools Count'],
                data: inventoryData
                    .map(
                      (item) => [
                        item['siteId'].toString(),
                        siteNameMap[item['siteId']] ?? "Unnamed Site",
                        item['toolsCount'].toString()
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: pdfPrimaryColor,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
                border: pw.TableBorder.all(
                  color: pdfPrimaryColor,
                  width: 1,
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 1, color: pdfPrimaryColor),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Distribution: ${inventoryData.fold<int>(0, (sum, item) => sum + (item['toolsCount'] as int))}",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfPrimaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GlassScaffold(
      title: "Tool Distribution Details",
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: colorScheme.onPrimary,
      onBack: () => Navigator.pop(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView(errorMessage!)
              : SizedBox.expand(
                  child: Column(
                    children: [
                      _buildToolHeaderCard(colorScheme),
                      const SizedBox(height: 16),
                      // Expanded table container with proper constraints
                      Expanded(
                        child: _buildDistributionTableCard(colorScheme),
                      ),
                      const SizedBox(height: 16),
                      _buildActionButtons(context),
                    ],
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
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GlassButton(
              onPressed: _fetchInventoryData,
              label: "RETRY",
              isSecondary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolHeaderCard(ColorScheme colorScheme) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              toolName.isNotEmpty ? toolName : "Master ${widget.toolCode}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.code, widget.toolCode, colorScheme),
                _buildInfoChip(Icons.category, toolCategory.isNotEmpty ? toolCategory : "Uncategorized", colorScheme),
                if (toolOwner.isNotEmpty)
                  _buildInfoChip(Icons.person_pin, toolOwner, colorScheme),
              ],
            ),
            if (toolDescription.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                toolDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              "Distributed across ${inventoryData.length} sites",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.primary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionTableCard(ColorScheme colorScheme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min, // Ensure it doesn't try to take infinite space
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              "Site Distribution Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          if (inventoryData.isEmpty)
             const Padding(
               padding: EdgeInsets.all(32.0),
               child: Center(
                 child: Text("No active distributions found for this tool."),
               ),
             )
          else
            // Removed Expanded here to avoid conflict with GlassCard's internal structure
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(colorScheme.primary.withOpacity(0.05)),
                columnSpacing: 24,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('Site ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Site Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Count', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: inventoryData.map((data) {
                  final siteId = data['siteId'];
                  final siteName = siteNameMap[siteId] ?? "Unnamed Site";
                  return DataRow(
                    cells: [
                      DataCell(Text(siteId, style: const TextStyle(fontSize: 13))),
                      DataCell(Text(siteName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            data['toolsCount'].toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            onPressed: () => _generatePdf(context),
            label: "GENERATE REPORT",
            icon: Icons.picture_as_pdf,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlassButton(
            onPressed: () => Navigator.pop(context),
            label: "CLOSE",
            isSecondary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Chip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(
        label,
        style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: colorScheme.primary.withOpacity(0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }
}
