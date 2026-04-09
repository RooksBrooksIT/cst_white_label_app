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
      final query = await FirestoreService
          .getCollection('toolsInventory')
          .where('toolCode', isEqualTo: widget.toolCode)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final sites = doc.data()['sites'] as List<dynamic>? ?? [];

        // 1. Fetch site names for lookup
        final sitesSnapshot = await FirestoreService.sites.get();
        final names = {
          for (var s in sitesSnapshot.docs)
            s.id: s.data()['siteName']?.toString() ?? 'Unnamed Site'
        };

        // 2. Aggregate counts by siteId to avoid duplicates
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
          siteNameMap = names;
          // ✅ Filter out entries where count == 0
          inventoryData = siteCounts.entries
              .where((entry) => entry.value > 0)
              .map((entry) {
                return {'siteId': entry.key, 'toolsCount': entry.value};
              })
              .toList();
        });
      } else {
        setState(() {
          inventoryData = [];
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
    setState(() {
      isLoading = false;
    });
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
              pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF0B3470)),
              pw.SizedBox(height: 8),
              pw.Text(
                "Tool Details",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              // pw.Bullet(
              //   text: "Name: $toolName",
              //   style: pw.TextStyle(fontSize: 14),
              // ),
              // pw.Bullet(
              //   text: "Category: $toolCategory",
              //   style: pw.TextStyle(fontSize: 14),
              // ),
              pw.Bullet(
                text: "Tool Code: ${widget.toolCode}",
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Distribution by Site",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Site ID', 'Tools Count'],
                data: inventoryData
                    .map(
                      (item) => [
                        '${item['siteId']} - ${siteNameMap[item['siteId']] ?? "Unnamed Site"}',
                        item['toolsCount'].toString()
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  // backgroundColor: PdfColor.fromInt(0xFF0B3470),
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
                border: pw.TableBorder.all(
                  color: pdfPrimaryColor,
                  width: 1,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: pdfPrimaryColor,
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF0B3470)),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Tools: ${inventoryData.fold<int>(0, (sum, item) => sum + (item['toolsCount'] as int))}",
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toolName.isNotEmpty ? toolName : "Tool Details",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        /// ✅ Show chips one below the other
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoChip(
                              icon: Icons.code,
                              label: widget.toolCode,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoChip(
                              icon: Icons.category,
                              label: toolCategory.isNotEmpty
                                  ? toolCategory
                                  : "Uncategorized",
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Text(
                          "Distributed across ${inventoryData.length} sites",
                          style: TextStyle(
                            fontSize: 15,
                            
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Data Table Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Distribution by Site",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  colorScheme.primary,
                                ),
                                headingTextStyle: const TextStyle(
                                  
                                  fontWeight: FontWeight.bold,
                                ),
                                columnSpacing: 30,
                                horizontalMargin: 20,
                                columns: const [
                                  DataColumn(label: Text('SITE (ID - Name)')),
                                  DataColumn(
                                    label: Text('COUNT'),
                                    numeric: true,
                                  ),
                                ],
                                rows: inventoryData
                                    .map(
                                      (data) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '${data['siteId']} - ${siteNameMap[data['siteId']] ?? "Unnamed Site"}',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                data['toolsCount'].toString(),
                                                style: TextStyle(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          onPressed: () => _generatePdf(context),
                          label: "GENERATE REPORT",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassButton(
                          onPressed: () => Navigator.pop(context),
                          label: "BACK",
                          isSecondary: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 20, color: colorScheme.primary),
      label: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: colorScheme.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    );
  }
}
