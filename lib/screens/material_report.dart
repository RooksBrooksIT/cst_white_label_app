import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialReportPage extends StatefulWidget {
  const MaterialReportPage({super.key});

  @override
  State<MaterialReportPage> createState() => _MaterialReportPageState();
}

class _MaterialReportPageState extends State<MaterialReportPage> {
  final Color primaryColor = const Color(0xFF0b3470); // Dark Blue
  final Color accentColor = const Color(0xFFc4b800); // Muted Gold Accent
  final Color backgroundColor = const Color(
    0xFFF9FAFB,
  ); // Soft Light Background

  List<String> materialNames = [];
  String? selectedMaterial;

  bool isLoadingNames = true;
  bool isReportLoading = false;
  List<_SiteMaterialRow> reportRows = [];

  @override
  void initState() {
    super.initState();
    _fetchMaterialNames();
  }

  Future<void> _fetchMaterialNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('materialsInventory')
          .get();

      final names = snapshot.docs
          .map((doc) => (doc.data()['materialName'] ?? '').toString().trim())
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load materials: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      });
    }
  }

  Future<void> _fetchMaterialReport(String materialName) async {
    setState(() {
      isReportLoading = true;
      reportRows = [];
    });

    try {
      final q = await FirebaseFirestore.instance
          .collection('materialsInventory')
          .where('materialName', isEqualTo: materialName)
          .get();

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
              final qtyRaw = s['materialQty'];
              final qty = _parseNumber(qtyRaw);
              qtyBySite.update(
                siteId,
                (prev) => prev + qty,
                ifAbsent: () => qty,
              );
            }
          }
        }
      }

      final rows =
          qtyBySite.entries
              .map((e) => _SiteMaterialRow(siteId: e.key, qty: e.value))
              .toList()
            ..sort(
              (a, b) =>
                  a.siteId.toLowerCase().compareTo(b.siteId.toLowerCase()),
            );

      setState(() {
        reportRows = rows;
        isReportLoading = false;
      });
    } catch (e) {
      setState(() => isReportLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      });
    }
  }

  double _parseNumber(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.+-]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Material Report',
          style: TextStyle(
            
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (selectedMaterial != null) {
                _fetchMaterialReport(selectedMaterial!);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT MATERIAL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoadingNames)
                      Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedMaterial,
                        iconEnabledColor: primaryColor,
                        decoration: InputDecoration(
                          labelText: 'Choose Material',
                          labelStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        isExpanded: true,
                        items: materialNames
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => selectedMaterial = val);
                          if (val != null) {
                            _fetchMaterialReport(val);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (selectedMaterial != null) ...[
              Row(
                children: [
                  Icon(Icons.assignment, color: primaryColor, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'MATERIAL REPORT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Showing results for: $selectedMaterial',
                style: TextStyle(fontSize: 15, ),
              ),
              const SizedBox(height: 18),
              if (isReportLoading)
                Center(child: CircularProgressIndicator(color: primaryColor))
              else
                _buildReportTable(context),
            ],
            if (selectedMaterial != null &&
                !isReportLoading &&
                reportRows.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 50),

                    Text(
                      'No data available',
                      style: TextStyle(
                        fontSize: 20,
                        
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No sites found for the selected material',
                      style: TextStyle(fontSize: 16, ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Sites:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      
                    ),
                  ),
                  Text(
                    reportRows.length.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: DataTable(
                  columnSpacing: 30,
                  horizontalMargin: 20,
                  headingRowColor: WidgetStateProperty.resolveWith(
                    (states) => primaryColor.withOpacity(0.1),
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'SITE ID',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'QUANTITY',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          
                        ),
                      ),
                    ),
                  ],
                  rows: reportRows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                r.siteId,
                                style: TextStyle(
                                  
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.qty.toStringAsFixed(r.qty % 1 == 0 ? 0 : 2),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
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
    );
  }
}

class _SiteMaterialRow {
  final String siteId;
  final double qty;
  _SiteMaterialRow({required this.siteId, required this.qty});
}
