import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:demo_cst/screens/reports/vehicle_inventory_pdf.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

enum ReportFilterMode { date, month, site }

class VehicleInventoryReportPage extends StatefulWidget {
  const VehicleInventoryReportPage({super.key});

  @override
  State<VehicleInventoryReportPage> createState() =>
      _VehicleInventoryReportPageState();
}

class _VehicleInventoryReportPageState
    extends State<VehicleInventoryReportPage> {
  final _formKey = GlobalKey<FormState>();

  ReportFilterMode _mode = ReportFilterMode.date;

  DateTime? _selectedDate;
  DateTime? _selectedMonth;
  String? _selectedSite;

  bool _isSubmitting = false;
  bool _submitted = false;
  bool _isLoadingSites = false;

  List<String> _sites = [];
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final snap = await FirestoreService.getCollection('projects').get();
      final names = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final siteName = data['siteName'];
        if (siteName is String && siteName.trim().isNotEmpty) {
          names.add(siteName.trim());
        }
      }
      final list = names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _sites = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sites: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _selectedMonth ?? now;
    final pickedYear = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 250,
            height: 250,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 2),
              selectedDate: initial,
              onChanged: (DateTime dt) => Navigator.pop(ctx, dt.year),
            ),
          ),
        );
      },
    );

    if (pickedYear == null) return;

    if (!mounted) return;
    final pickedMonthInt = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final months = List.generate(12, (i) => i + 1);
        return AlertDialog(
          title: Text('Select Month ($pickedYear)'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: months.map((m) {
                final date = DateTime(pickedYear, m, 1);
                final label = DateFormat('MMM').format(date);
                return SizedBox(
                  width: 75,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, m),
                    child: Text(label),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (pickedMonthInt == null) return;
    setState(() {
      _selectedMonth = DateTime(pickedYear, pickedMonthInt, 1);
    });
  }

  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _fetchReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _submitted = false;
      _rows = [];
    });

    try {
      final col = FirestoreService.getCollection('vehicleMovements');
      QuerySnapshot<Map<String, dynamic>> snap;

      switch (_mode) {
        case ReportFilterMode.date:
          final dateStr = _formatDate(_selectedDate!);
          snap = await col.where('date', isEqualTo: dateStr).get();
          break;
        case ReportFilterMode.month:
          final start = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
          final end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);
          snap = await col
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('createdAt', isLessThan: Timestamp.fromDate(end))
              .orderBy('createdAt', descending: true)
              .get();
          break;
        case ReportFilterMode.site:
          snap = await col.where('toLocation', isEqualTo: _selectedSite).get();
          break;
      }

      final items = snap.docs.map((d) => d.data()).toList();

      if (_mode != ReportFilterMode.month) {
        items.sort((a, b) {
          final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return tb.compareTo(ta);
        });
      }

      setState(() {
        _rows = items;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _generatePdf() async {
    if (_rows.isEmpty) return;
    try {
      final String filterTitle;
      switch (_mode) {
        case ReportFilterMode.date:
          filterTitle = 'Date: ${_formatDate(_selectedDate!)}';
          break;
        case ReportFilterMode.month:
          filterTitle = 'Month: ${DateFormat('MMMM yyyy').format(_selectedMonth!)}';
          break;
        case ReportFilterMode.site:
          filterTitle = 'Site: $_selectedSite';
          break;
      }

      await InventoryReportPdf.generateAndShare(
        context: context,
        title: filterTitle,
        rows: _rows,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vehicle Inventory',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterCard(primaryColor),
                  const SizedBox(height: 20),
                  if (_submitted) ...[
                    _buildReportSummary(primaryColor),
                    const SizedBox(height: 16),
                    _buildMovementList(primaryColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded, size: 18, color: primaryColor),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Inventory Filter Mode',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildModeSegmentedControl(primaryColor),
            const SizedBox(height: 16),
            _buildFilterInput(primaryColor),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _fetchReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.analytics_rounded, size: 18),
                label: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'FETCH INVENTORY REPORT',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSegmentedControl(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          _buildSegmentButton('By Date', ReportFilterMode.date, Icons.calendar_today_rounded, primaryColor),
          _buildSegmentButton('By Month', ReportFilterMode.month, Icons.calendar_month_rounded, primaryColor),
          _buildSegmentButton('By Site', ReportFilterMode.site, Icons.location_on_rounded, primaryColor),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, ReportFilterMode mode, IconData icon, Color primaryColor) {
    final bool isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            _submitted = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterInput(Color primaryColor) {
    switch (_mode) {
      case ReportFilterMode.date:
        return _buildCustomTextField(
          label: 'Select Date *',
          child: TextFormField(
            readOnly: true,
            onTap: _pickDate,
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            controller: TextEditingController(
              text: _selectedDate == null ? '' : _formatDate(_selectedDate!),
            ),
            decoration: InputDecoration(
              hintText: 'Choose date for report',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.calendar_today_rounded, color: primaryColor, size: 20),
            ),
            validator: (_) => _selectedDate == null ? 'Please select a date' : null,
          ),
        );

      case ReportFilterMode.month:
        return _buildCustomTextField(
          label: 'Select Month *',
          child: TextFormField(
            readOnly: true,
            onTap: _pickMonth,
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            controller: TextEditingController(
              text: _selectedMonth == null ? '' : DateFormat('MMMM yyyy').format(_selectedMonth!),
            ),
            decoration: InputDecoration(
              hintText: 'Choose month for report',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 20),
            ),
            validator: (_) => _selectedMonth == null ? 'Please select a month' : null,
          ),
        );

      case ReportFilterMode.site:
        return _buildCustomTextField(
          label: 'Select Site *',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedSite,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(Icons.location_on_rounded, color: primaryColor, size: 20),
              hintText: _isLoadingSites ? 'Loading sites...' : 'Choose destination site',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            ),
            items: _sites.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedSite = v),
            validator: (v) => v == null || v.isEmpty ? 'Please select a site' : null,
          ),
        );
    }
  }

  Widget _buildCustomTextField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildReportSummary(Color primaryColor) {
    final double totalDistance = _rows.fold(
      0.0,
      (accum, item) => accum + ((item['distanceValue'] as num?)?.toDouble() ?? 0.0),
    );
    final double totalQty = _rows.fold(
      0.0,
      (accum, item) => accum + ((item['quantityValue'] as num?)?.toDouble() ?? 0.0),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryTile('Movements', '${_rows.length}', Icons.local_shipping_rounded, primaryColor),
              Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
              _buildSummaryTile('Distance', '${totalDistance.toStringAsFixed(1)} km', Icons.route_rounded, primaryColor),
              Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
              _buildSummaryTile('Material Qty', totalQty.toStringAsFixed(0), Icons.inventory_2_rounded, primaryColor),
            ],
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Download PDF Inventory Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon, Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0A183D))),
      ],
    );
  }

  Widget _buildMovementList(Color primaryColor) {
    if (_rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Center(
          child: Text(
            'No vehicle movement logs found for this query.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Movements Found (${_rows.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows.length,
          itemBuilder: (context, index) {
            final row = _rows[index];
            final vehicleModel = row['vehicleModel'] ?? 'Vehicle';
            final plate = row['vehicleNumberPlate'] ?? '';
            final driver = row['driverName'] ?? 'Unknown Driver';
            final fromLoc = row['fromLocation'] ?? '';
            final toLoc = row['toLocation'] ?? '';
            final material = row['materialType'] ?? '';
            final qty = row['quantity'] ?? '0';
            final unit = row['materialUnit'] ?? '';
            final distance = row['distanceKm'] ?? '0';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.local_shipping_rounded, color: primaryColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleModel,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0A183D)),
                            ),
                            Text(
                              '$plate • $driver',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${distance}km',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            '$fromLoc → $toLoc',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                          ),
                        ],
                      ),
                      if (material.toString().isNotEmpty)
                        Text(
                          '$material ($qty $unit)',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
