import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  /// ✅ Professional Primary Color
  final Color primaryColor = const Color(0xFF0B3470);

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

        // Aggregate counts by siteId to avoid duplicates
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

        // ✅ Filter out entries where count == 0
        inventoryData = siteCounts.entries
            .where((entry) => entry.value > 0) // only keep non-zero counts
            .map((entry) {
              return {'siteId': entry.key, 'toolsCount': entry.value};
            })
            .toList();

        // toolName = doc.data()['name'] ?? 'Unknown Tool';
        // toolCategory = doc.data()['category'] ?? 'Uncategorized';
      } else {
        inventoryData = [];
      }
    } catch (e) {
      errorMessage = 'Failed to load data: ${e.toString()}';
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _generatePdf(BuildContext context) async {
    final pdf = pw.Document();
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
                  color: PdfColor.fromInt(0xFF0B3470),
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
                  color: PdfColor.fromInt(0xFF0B3470),
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
                  color: PdfColor.fromInt(0xFF0B3470),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Site ID', 'Tools Count'],
                data: inventoryData
                    .map(
                      (item) => [item['siteId'], item['toolsCount'].toString()],
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
                  color: PdfColor.fromInt(0xFF0B3470),
                  width: 1,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0B3470),
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
                    color: PdfColor.fromInt(0xFF0B3470),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Tool Distribution Details",
          style: TextStyle(
            
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 3,
        centerTitle: true,
        iconTheme: const IconThemeData(),
      ),
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
                // Header Card
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 6,
                  shadowColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toolName.isNotEmpty ? toolName : "Tool Details",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
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
                    child: Card(
                      elevation: 3,
                      shadowColor: primaryColor.withOpacity(0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Distribution by Site",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  primaryColor,
                                ),
                                headingTextStyle: const TextStyle(
                                  
                                  fontWeight: FontWeight.bold,
                                ),
                                columnSpacing: 30,
                                horizontalMargin: 20,
                                columns: const [
                                  DataColumn(label: Text('SITE')),
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
                                              data['siteId'],
                                              style: TextStyle(
                                                color: primaryColor,
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
                                                color: primaryColor.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                data['toolsCount'].toString(),
                                                style: TextStyle(
                                                  color: primaryColor,
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
                        child: ElevatedButton.icon(
                          onPressed: () => _generatePdf(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Generate Report"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          child: const Text(
                            "Back",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
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
    return Chip(
      avatar: Icon(icon, size: 20, color: primaryColor),
      label: Text(
        label,
        style: TextStyle(
          color: primaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    );
  }
}
