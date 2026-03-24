import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:ideal_cst/screens/vehichle_inventory_pdf.dart';
import 'package:demo_cst/screens/vehicle_inventory_pdf.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';

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
      final snap = await FirebaseFirestore.instance
          .collection('projects')
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
    return SegmentedButton<ReportFilterMode>(
      segments: const [
        ButtonSegment(
          value: ReportFilterMode.date,
          label: Text('By Date'),
          icon: Icon(Icons.today),
        ),
        ButtonSegment(
          value: ReportFilterMode.month,
          label: Text('By Month'),
          icon: Icon(Icons.calendar_month),
        ),
        ButtonSegment(
          value: ReportFilterMode.site,
          label: Text('By Site'),
          icon: Icon(Icons.place),
        ),
      ],
      selected: <ReportFilterMode>{_mode},
      onSelectionChanged: (s) {
        setState(() {
          _mode = s.first;
          _selectedDate = null;
          _selectedMonth = null;
          _selectedSite = null;
          _rows = [];
          _submitted = false;
        });
      },
    );
  }

  Widget _buildFilters() {
    switch (_mode) {
      case ReportFilterMode.date:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date'),
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
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: const Text('Pick'),
            ),
          ],
        );
      case ReportFilterMode.month:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Month'),
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
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Pick'),
            ),
          ],
        );
      case ReportFilterMode.site:
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Site'),
          isExpanded: true,
          items: _sites
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          value: _selectedSite,
          onChanged: (v) => setState(() => _selectedSite = v),
          validator: (v) => v == null || v.isEmpty ? 'Select a site' : null,
        );
    }
  }

  DataTable _buildTable() {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return DataTable(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Inventory Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeSelector(),
                  const SizedBox(height: 16),
                  if (_isLoadingSites && _mode == ReportFilterMode.site)
                    const LinearProgressIndicator(),
                  _buildFilters(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit'),
                      ),
                      const SizedBox(width: 12),
                      if (_submitted && _rows.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _generatePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate PDF'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('No data'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width,
                        ),
                        child: SingleChildScrollView(child: _buildTable()),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
