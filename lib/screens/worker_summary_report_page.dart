import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class WorkerAttendanceSalaryPage extends StatefulWidget {
  const WorkerAttendanceSalaryPage({super.key});

  @override
  _WorkerAttendanceSalaryPageState createState() => _WorkerAttendanceSalaryPageState();
}

class _WorkerAttendanceSalaryPageState extends State<WorkerAttendanceSalaryPage> {
  List<Map<String, dynamic>> _filteredWorkers = [];
  String? _selectedSite;
  String? _selectedMonth;
  List<String> _sites = [];
  List<String> _months = [];
  bool _isLoading = true;
  final Set<String> _selectedWorkerIds = <String>{};
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final querySnapshot = await FirestoreService.getCollection('workersSummary').get();
      final Set<String> uniqueSites = {};
      final Set<String> uniqueMonths = {};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['site'] != null) uniqueSites.add(data['site']);
        if (data['month'] != null) uniqueMonths.add(data['month']);
      }

      setState(() {
        _sites = uniqueSites.toList()..sort();
        _months = uniqueMonths.toList()..sort((a,b) => b.compareTo(a));
        _selectedMonth = _months.isNotEmpty ? _months.first : _currentMonth;
        _isLoading = false;
      });
      _loadWorkersData();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkersData() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirestoreService.getCollection('workersSummary');
      if (_selectedSite != null) query = query.where('site', isEqualTo: _selectedSite);
      if (_selectedMonth != null) query = query.where('month', isEqualTo: _selectedMonth);
      
      final snapshot = await query.get();
      final List<Map<String, dynamic>> workers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final workersMap = data['workers'] as Map<String, dynamic>? ?? {};
        workersMap.forEach((name, wData) {
          final wd = wData as Map<String, dynamic>;
          workers.add({
            'id': '${name}_${data['site']}',
            'name': name,
            'designation': wd['designation'] ?? 'Worker',
            'baseSalary': wd['salary']?.toString() ?? '0',
            'site': data['site'] ?? 'N/A',
            'month': data['month'] ?? 'N/A',
            'attendance': wd['attendance'] ?? {},
            'calculatedSalary': _calculateSalary(wd['salary']?.toString() ?? '0', wd['attendance'] ?? {}),
          });
        });
      }
      setState(() {
        _filteredWorkers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double _calculateSalary(String base, Map<String, dynamic> att) {
    final b = double.tryParse(base) ?? 0;
    final p = int.tryParse(att['presentDays']?.toString() ?? '0') ?? 0;
    final o = int.tryParse(att['overtimeDays']?.toString() ?? '0') ?? 0;
    final h = int.tryParse(att['halfDays']?.toString() ?? '0') ?? 0;
    return (p * b) + (o * b) + (h * (b / 2));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Worker Summary',
      actions: [
        if (_selectedWorkerIds.isNotEmpty)
          IconButton(icon: const Icon(Icons.send_outlined), onPressed: _submitReports),
      ],
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildFilterBar(theme, isMobile),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredWorkers.length,
                  itemBuilder: (ctx, i) => _buildWorkerCard(_filteredWorkers[i], theme),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSite,
                  hint: const Text('All Sites'),
                  isExpanded: true,
                  items: [null, ..._sites].map((s) => DropdownMenuItem(value: s, child: Text(s ?? 'All Sites'))).toList(),
                  onChanged: (v) { setState(() => _selectedSite = v); _loadWorkersData(); },
                ),
              ),
            ),
            const VerticalDivider(),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) { setState(() => _selectedMonth = v); _loadWorkersData(); },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, ThemeData theme) {
    final isSelected = _selectedWorkerIds.contains(worker['id']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _toggleSelection(worker['id']),
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : null,
        child: Row(
          children: [
            Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(worker['id'])),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(worker['designation'], style: theme.textTheme.bodySmall),
                  Text(worker['site'], style: theme.textTheme.bodySmall?.copyWith(color: theme.primaryColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹ ${worker['calculatedSalary'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Present: ${worker['attendance']['presentDays'] ?? 0}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedWorkerIds.contains(id)) _selectedWorkerIds.remove(id);
      else _selectedWorkerIds.add(id);
    });
  }

  void _submitReports() async {
    // Logic to batch submit reports to WorkerAllDetails
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submitting ${_selectedWorkerIds.length} reports...')));
    // Implementation omitted for brevity
  }
}
