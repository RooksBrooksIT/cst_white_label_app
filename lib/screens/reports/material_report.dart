import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:demo_cst/services/material_inventory_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/manager/material_inventory_details.dart';

enum DataState { loading, loaded, error }

class MaterialInventorySummary {
  final String materialName;
  final String category;
  final String subCategory;
  final String unit;
  final String code;
  final double price;
  final double atCompany;
  final double atSite;
  final Map<String, double> siteBreakdown;

  MaterialInventorySummary({
    required this.materialName,
    required this.category,
    this.subCategory = '',
    required this.unit,
    required this.code,
    this.price = 0.0,
    required this.atCompany,
    required this.atSite,
    required this.siteBreakdown,
  });

  double get totalStock => atCompany + atSite;
  double get totalValue => totalStock * price;

  MaterialInventorySummary copyWith({
    String? materialName,
    String? category,
    String? subCategory,
    String? unit,
    String? code,
    double? price,
    double? atCompany,
    double? atSite,
    Map<String, double>? siteBreakdown,
  }) {
    return MaterialInventorySummary(
      materialName: materialName ?? this.materialName,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      unit: unit ?? this.unit,
      code: code ?? this.code,
      price: price ?? this.price,
      atCompany: atCompany ?? this.atCompany,
      atSite: atSite ?? this.atSite,
      siteBreakdown: siteBreakdown ?? this.siteBreakdown,
    );
  }
}

class MaterialReportPage extends StatefulWidget {
  const MaterialReportPage({super.key});

  @override
  State<MaterialReportPage> createState() => _MaterialReportPageState();
}

class _MaterialReportPageState extends State<MaterialReportPage> {
  DataState _dataState = DataState.loading;
  List<MaterialInventorySummary> _materials = [];
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'At Company', 'At Sites'

  final TextEditingController _searchController = TextEditingController();

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    setState(() => _dataState = DataState.loading);
    try {
      final items = await MaterialInventoryService.fetchAllMaterialsInventory();

      final list = items.map((item) {
        return MaterialInventorySummary(
          materialName: item.displayName.isNotEmpty ? item.displayName : item.materialName,
          category: item.category,
          subCategory: item.subCategory,
          unit: item.unit,
          code: item.materialId.isNotEmpty ? item.materialId : item.docId,
          price: item.unitPrice,
          atCompany: item.companyAvailableCount.toDouble(),
          atSite: item.totalSiteStock.toDouble(),
          siteBreakdown: item.siteBreakdownMap,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _materials = list;
          _dataState = DataState.loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataState = DataState.error;
          _errorMessage = 'Failed to load materials inventory: $e';
        });
      }
    }
  }

  String _formatQty(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  List<MaterialInventorySummary> get _filteredMaterials {
    return _materials.where((item) {
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          item.materialName.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.subCategory.toLowerCase().contains(query) ||
          item.code.toLowerCase().contains(query) ||
          item.unit.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_selectedFilter == 'At Company') {
        matchesFilter = item.atCompany > 0;
      } else if (_selectedFilter == 'At Sites') {
        matchesFilter = item.atSite > 0;
      }

      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _navigateToDetails(MaterialInventorySummary item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialInventoryDetailsPage(
          materialName: item.materialName,
          category: item.category,
          subCategory: item.subCategory,
          unit: item.unit,
          code: item.code,
          price: item.price,
        ),
      ),
    ).then((_) => _loadInventoryData());
  }

  Future<void> _exportMasterPdf() async {
    try {
      final pdf = pw.Document();
      final filtered = _filteredMaterials;

      final totalCompany = filtered.fold<double>(0.0, (acc, m) => acc + m.atCompany);
      final totalSites = filtered.fold<double>(0.0, (acc, m) => acc + m.atSite);
      final totalStock = totalCompany + totalSites;

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
                        'MATERIALS INVENTORY MASTER REPORT',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Comprehensive Stock & Distribution Overview',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
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
                      pw.Text('Total Items', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${filtered.length}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Company Stock', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(_formatQty(totalCompany), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Site Stock', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(_formatQty(totalSites), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Units', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(_formatQty(totalStock), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: ['Material Name', 'Category', 'Unit', 'Company', 'Sites', 'Total'],
              data: filtered.map((m) => [
                m.materialName,
                m.category,
                m.unit,
                _formatQty(m.atCompany),
                _formatQty(m.atSite),
                _formatQty(m.totalStock),
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
        name: 'Materials_Inventory_Summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to export master PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Materials Inventory Overview',
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
            tooltip: 'Export Master PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            onPressed: _materials.isNotEmpty ? _exportMasterPdf : null,
          ),
          IconButton(
            tooltip: 'Refresh Inventory',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _loadInventoryData,
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
            child: _buildBody(darkAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color darkAccent) {
    switch (_dataState) {
      case DataState.loading:
        return const Center(child: CircularProgressIndicator());
      case DataState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load materials inventory',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadInventoryData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      case DataState.loaded:
        return _buildInventoryList(darkAccent);
    }
  }

  Widget _buildInventoryList(Color darkAccent) {
    final totalAtCompany = _materials.fold<double>(
      0.0,
      (acc, mat) => acc + mat.atCompany,
    );
    final totalAtSite = _materials.fold<double>(
      0.0,
      (acc, mat) => acc + mat.atSite,
    );
    final totalStock = totalAtCompany + totalAtSite;
    final filtered = _filteredMaterials;

    return RefreshIndicator(
      onRefresh: _loadInventoryData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI Summary Cards ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Stock',
                    value: _formatQty(totalStock),
                    subtitle: 'Units in org',
                    icon: Icons.inventory_2_rounded,
                    accentColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'At Company',
                    value: _formatQty(totalAtCompany),
                    subtitle: 'Storage stock',
                    icon: Icons.warehouse_rounded,
                    accentColor: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'At Sites',
                    value: _formatQty(totalAtSite),
                    subtitle: 'Deployed units',
                    icon: Icons.location_city_rounded,
                    accentColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Search & Filter Box ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search material name, category, unit...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip('All'),
                      const SizedBox(width: 6),
                      _buildFilterChip('At Company'),
                      const SizedBox(width: 6),
                      _buildFilterChip('At Sites'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Materials Inventory Cards List ──────────────────────────────
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isEmpty ? 'No Materials in Inventory' : 'No Matching Materials Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Register materials in Material Setup or log site entries to view inventory.'
                          : 'Try searching with a different name or clearing filter.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final total = item.totalStock;
                  final companyRatio = total > 0 ? (item.atCompany / total) : 0.0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _navigateToDetails(item),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Avatar + Title + Total Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Color(0xFF7C3AED),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.category.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ),
                                            if (item.subCategory.isNotEmpty) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.subCategory,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.unit,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.materialName,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: darkAccent,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (item.code.isNotEmpty)
                                              Text(
                                                item.code,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'monospace',
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            if (item.price > 0) ...[
                                              if (item.code.isNotEmpty)
                                                const Text('  •  ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                              Text(
                                                '₹${item.price.toStringAsFixed(item.price == item.price.roundToDouble() ? 0 : 2)}/${item.unit}',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0D9488),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _formatQty(total),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: darkAccent,
                                          ),
                                        ),
                                        Text(
                                          item.unit.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Progress bar representing Company vs Site allocation
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 6,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: (companyRatio * 100).round().clamp(0, 100),
                                        child: Container(color: const Color(0xFF0EA5E9)),
                                      ),
                                      Expanded(
                                        flex: ((1.0 - companyRatio) * 100).round().clamp(0, 100),
                                        child: Container(color: const Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Breakdown Badges Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildDistributionBadge(
                                        label: 'Company',
                                        count: _formatQty(item.atCompany),
                                        color: const Color(0xFF0EA5E9),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildDistributionBadge(
                                        label: 'Sites',
                                        count: _formatQty(item.atSite),
                                        color: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'View Sites',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded, size: 18, color: primaryColor),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBadge({
    required String label,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
