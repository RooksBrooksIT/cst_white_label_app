import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:demo_cst/screens/reports/vehicle_inventory_pdf.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

/// Vehicle Inventory Report
/// - Filter modes: by Date (string equality on 'date'), by Month (createdAt range), by Site (toLocation equality)
/// - Sites loaded from 'projects' collection via 'siteName'
/// - Results displayed in a DataTable with all listed fields
/// - Submit -> displays "Generate PDF", generating a PDF of currently displayed rows
///
/// Index strategy:
/// - Date mode: no orderBy used -> avoids composite (date + createdAt)
/// - Site mode: no orderBy used -> avoids composite (toLocation + createdAt)
/// - Month mode: createdAt range + orderBy(createdAt) -> uses single-field index on createdAt (automatic)
///
/// If you prefer chronological order for date/site, create composite indexes:
/// - vehicleMovements: date Asc, createdAt Asc
/// - vehicleMovements: toLocation Asc, createdAt Asc
/// Then add .orderBy('createdAt') back in respective modes.
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
  bool _isLoadingData = false;

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
      final snap = await FirestoreService
          .getCollection('projects')
          .get();
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
          backgroundColor: Colors.red,
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
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Select month (any day in month)',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitted = false;
      _rows = [];
    });

    try {
      await _fetchData();
      setState(() {
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoadingData = true);
    try {
      final col = FirestoreService.getCollection('vehicleMovements');

      Query<Map<String, dynamic>> q = col;

      switch (_mode) {
        case ReportFilterMode.date:
          final dateStr = _formatDate(_selectedDate!);
          // Avoid composite index by not ordering by createdAt.
          q = q.where('date', isEqualTo: dateStr);
          break;

        case ReportFilterMode.month:
          // Range on createdAt plus orderBy(createdAt) -> single-field index on createdAt.
          final start = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month,
            1,
          );
          final end = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month + 1,
            1,
          ).subtract(const Duration(milliseconds: 1));
          q = q
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .orderBy('createdAt', descending: false);
          break;

        case ReportFilterMode.site:
          // Avoid composite by not ordering by createdAt.
          q = q.where('toLocation', isEqualTo: _selectedSite);
          break;
      }

      final snap = await q.get();

      List<Map<String, dynamic>> items = snap.docs.map((d) {
        final data = d.data();
        return {
          'createdAt': data['createdAt'],
          'date': data['date'],
          'distanceKm': data['distanceKm'],
          'docId': data['docId'],
          'driverName': data['driverName'],
          'endTime': data['endTime'],
          'fromLocation': data['fromLocation'],
          'materialType': data['materialType'],
          'materialUnit': data['materialUnit'],
          'movementId': data['movementId'],
          'movementType': data['movementType'],
          'quantity': data['quantity'],
          'remarks': data['remarks'],
          'startTime': data['startTime'],
          'toLocation': data['toLocation'],
          'vehicleId': data['vehicleId'],
          'siteId': _selectedSite,
        };
      }).toList();

      // Month mode fallback: ensure "date" starts with yyyy-MM if needed.
      if (_mode == ReportFilterMode.month) {
        final monthPrefix = DateFormat('yyyy-MM').format(_selectedMonth!);
        items = items.where((r) {
          final ds = r['date'];
          if (ds is String && ds.length >= 7) {
            return ds.startsWith(monthPrefix);
          }
          return true;
        }).toList();
      }

      setState(() {
        _rows = items;
      });
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _generatePdf() async {
    try {
      final title = switch (_mode) {
        ReportFilterMode.date =>
          'Vehicle Inventory Report - ${_formatDate(_selectedDate!)}',
        ReportFilterMode.month =>
          'Vehicle Inventory Report - ${DateFormat('MMMM yyyy').format(_selectedMonth!)}',
        ReportFilterMode.site =>
          'Vehicle Inventory Report - Site: ${_selectedSite!}',
      };
      await InventoryReportPdf.generateAndShare(
        context: context,
        title: title,
        rows: _rows,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ReportFilterMode.values.map((mode) {
          final isSelected = _mode == mode;
          String label = 'By Date';
          IconData icon = Icons.today_rounded;

          if (mode == ReportFilterMode.month) {
            label = 'By Month';
            icon = Icons.calendar_month_rounded;
          } else if (mode == ReportFilterMode.site) {
            label = 'By Site';
            icon = Icons.place_rounded;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = mode;
                  _selectedDate = null;
                  _selectedMonth = null;
                  _selectedSite = null;
                  _rows = [];
                  _submitted = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0A183D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilters(Color primaryColor) {
    switch (_mode) {
      case ReportFilterMode.date:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date *',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      readOnly: true,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Select Date',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      controller: TextEditingController(
                        text: _selectedDate == null
                            ? ''
                            : _formatDate(_selectedDate!),
                      ),
                      validator: (_) =>
                          _selectedDate == null ? 'Select a date' : null,
                      onTap: _pickDate,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: const Text(
                      'Pick',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case ReportFilterMode.month:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Month *',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      readOnly: true,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Select Month',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      controller: TextEditingController(
                        text: _selectedMonth == null
                            ? ''
                            : DateFormat('MMMM yyyy').format(_selectedMonth!),
                      ),
                      validator: (_) =>
                          _selectedMonth == null ? 'Select a month' : null,
                      onTap: _pickMonth,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text(
                      'Pick',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case ReportFilterMode.site:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Site *',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                decoration: InputDecoration(
                  hintText: 'Select Site',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.place_rounded,
                    color: Color(0xFF0A183D),
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                isExpanded: true,
                items: _sites
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                value: _selectedSite,
                onChanged: (v) => setState(() => _selectedSite = v),
                validator: (v) => v == null || v.isEmpty ? 'Select a site' : null,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildTable() {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A183D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF05112E)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 13.5,
        ),
        dataTextStyle: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Created At')),
          DataColumn(label: Text('Movement ID')),
          DataColumn(label: Text('Doc ID')),
          DataColumn(label: Text('Vehicle ID')),
          DataColumn(label: Text('Driver')),
          DataColumn(label: Text('From')),
          DataColumn(label: Text('To')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Start')),
          DataColumn(label: Text('End')),
          DataColumn(label: Text('Distance Km')),
          DataColumn(label: Text('Material')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Remarks')),
        ],
        rows: _rows.map((r) {
          final ts = r['createdAt'];
          String created = '';
          if (ts is Timestamp) {
            created = dateFmt.format(ts.toDate());
          } else if (ts is DateTime) {
            created = dateFmt.format(ts);
          }
          return DataRow(
            cells: [
              DataCell(Text('${r['date'] ?? ''}')),
              DataCell(Text(created)),
              DataCell(Text('${r['movementId'] ?? ''}')),
              DataCell(Text('${r['docId'] ?? ''}')),
              DataCell(Text('${r['vehicleId'] ?? ''}')),
              DataCell(Text('${r['driverName'] ?? ''}')),
              DataCell(Text('${r['fromLocation'] ?? ''}')),
              DataCell(Text('${r['toLocation'] ?? ''}')),
              DataCell(Text('${r['movementType'] ?? ''}')),
              DataCell(Text('${r['startTime'] ?? ''}')),
              DataCell(Text('${r['endTime'] ?? ''}')),
              DataCell(Text('${r['distanceKm'] ?? ''}')),
              DataCell(Text('${r['materialType'] ?? ''}')),
              DataCell(Text('${r['materialUnit'] ?? ''}')),
              DataCell(Text('${r['quantity'] ?? ''}')),
              DataCell(Text('${r['remarks'] ?? ''}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      title: 'Vehicle Inventory Report',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Filter Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: darkCardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: darkCardBg.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeSelector(),
                        const SizedBox(height: 16),
                        if (_isLoadingSites && _mode == ReportFilterMode.site)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12.0),
                            child: LinearProgressIndicator(),
                          ),
                        _buildFilters(primaryColor),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: const Color(0xFF0A183D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Color(0xFF0A183D),
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Submit Report',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (_submitted && _rows.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _generatePdf,
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                  label: const Text(
                                    'Generate PDF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Results Table Container
                Expanded(
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A183D).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No vehicle movement records found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Select filter parameters and tap submit to view report.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: darkCardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: darkCardBg.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.of(context).size.width,
                                ),
                                child: SingleChildScrollView(child: _buildTable()),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
