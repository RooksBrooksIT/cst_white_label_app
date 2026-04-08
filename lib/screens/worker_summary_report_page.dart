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
  _WorkerAttendanceSalaryPageState createState() =>
      _WorkerAttendanceSalaryPageState();
}

class _WorkerAttendanceSalaryPageState
    extends State<WorkerAttendanceSalaryPage> {
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
      // Load sites from workerSiteMap as the source of truth for populated sites
      final siteSnapshot = await FirestoreService.getCollection(
        'workerSiteMap',
      ).get();
      final Set<String> uniqueSites = {};

      for (var doc in siteSnapshot.docs) {
        final data = doc.data();
        final site = data['site']?.toString() ?? doc.id;
        if (site.isNotEmpty) uniqueSites.add(site);
      }

      // We still query workersSummary to know which months have data
      final summarySnapshot = await FirestoreService.getCollection(
        'workersSummary',
      ).limit(100).get();
      final Set<String> uniqueMonths = {
        _currentMonth,
      }; // Always include current month
      for (var doc in summarySnapshot.docs) {
        final data = doc.data();
        final month = data['month']?.toString();
        if (month != null && month.isNotEmpty) uniqueMonths.add(month);
      }

      if (!mounted) return;
      setState(() {
        _sites = uniqueSites.toList()..sort();
        _months = uniqueMonths.toList()..sort((a, b) => b.compareTo(a));
        _selectedMonth = _currentMonth;
        _isLoading = false;
      });

      _loadWorkersData();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load summary data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWorkersData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String month = _selectedMonth ?? _currentMonth;
      
      // 1. Fetch all workers currently mapped to the selected site(s)
      Query siteQuery = FirestoreService.getCollection('workerSiteMap');
      if (_selectedSite != null) {
        siteQuery = siteQuery.where('site', isEqualTo: _selectedSite);
      }

      final siteSnapshot = await siteQuery.get();
      final List<Map<String, dynamic>> allWorkers = [];

      for (var doc in siteSnapshot.docs) {
        final siteData = doc.data();
        if (siteData is! Map<String, dynamic>) continue;

        final rawWorkers = siteData['workers'];
        final siteName = siteData['site']?.toString() ?? doc.id;

        if (rawWorkers is! List) continue;

        for (var rawW in rawWorkers) {
          if (rawW == null || rawW is! Map) continue;

          final w = Map<String, dynamic>.from(rawW);
          String workerName = w['workerName']?.toString().trim() ?? '';
          if (workerName.isEmpty) workerName = 'Unknown Worker ($siteName)';

          // We try to use the workerId if it was stored in the mapping, else fallback
          final String workerId = w['workerId']?.toString() ?? '${workerName}_$siteName';

          allWorkers.add({
            'id': workerId,
            'name': workerName,
            'designation': w['workerDesignation']?.toString() ?? 'Worker',
            'baseSalary': w['workerSalary']?.toString() ?? '0',
            'site': siteName,
            'month': month,
            'attendance': <String, dynamic>{}, // Map of date -> status details
            'calculatedSalary': 0.0,
            'presentDays': 0,
          });
        }
      }

      // 2. Fetch attendance from the NEW WorkerMonthlyAttendance collection
      Query<Map<String, dynamic>> monthlyQuery =
          FirestoreService.getCollection('WorkerMonthlyAttendance');
      monthlyQuery = monthlyQuery.where('month', isEqualTo: month);
      if (_selectedSite != null) {
        monthlyQuery = monthlyQuery.where('site', isEqualTo: _selectedSite);
      }

      final monthlySnapshot = await monthlyQuery.get();

      // Map workerId to the monthly attendance document data
      final Map<String, Map<String, dynamic>> attendanceRecords = {};

      for (var doc in monthlySnapshot.docs) {
        final data = doc.data();
        final wId = data['workerId']?.toString() ?? doc.id.split('_').first;
        if (wId.isNotEmpty) attendanceRecords[wId] = data;
      }

      // 3. Merge attendance with existing workers
      for (var i = 0; i < allWorkers.length; i++) {
        final worker = allWorkers[i];
        final wId = worker['id'];

        if (attendanceRecords.containsKey(wId)) {
          final record = attendanceRecords[wId]!;
          
          final attendanceMap = record['attendanceData'] as Map<String, dynamic>? ?? {};
          worker['attendance'] = attendanceMap;
          
          // Use pre-calculated salary if available, otherwise calculate client-side
          if (record.containsKey('calculatedSalary')) {
            worker['calculatedSalary'] = (record['calculatedSalary'] as num).toDouble();
            worker['presentDays'] = record['totalPresentDays'] ?? 0;
          } else {
            final results = _calculateSalaryFromMap(
              worker['baseSalary'].toString(),
              attendanceMap,
            );
            worker['calculatedSalary'] = results['salary'];
            worker['presentDays'] = results['presentDays'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _filteredWorkers = allWorkers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading workers data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _calculateSalaryFromMap(String base, Map<String, dynamic> attMap) {
    final double b = double.tryParse(base) ?? 0.0;
    double totalSalary = 0.0;
    int presentDays = 0;

    attMap.forEach((date, details) {
      if (details is Map) {
        final String status = details['status']?.toString().toLowerCase() ?? '';
        final double salaryPerDay = double.tryParse(details['salaryPerDay']?.toString() ?? base) ?? b;

        if (status == 'present' || status == 'overtime') {
          totalSalary += salaryPerDay;
          presentDays += 1;
        } else if (status == 'half day') {
          totalSalary += (salaryPerDay / 2.0);
          presentDays += 1;
        }
      }
    });

    return {
      'salary': totalSalary,
      'presentDays': presentDays,
    };
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Worker Attendance & Summary',
      actions: [
        if (_selectedWorkerIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: _submitReports,
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterBar(theme, isMobile),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Workers (${_filteredWorkers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredWorkers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No workers found',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredWorkers.length,
                          itemBuilder: (ctx, i) =>
                              _buildWorkerCard(_filteredWorkers[i], theme),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Filters',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Site',
              icon: Icons.handyman_outlined,
              value: _selectedSite,
              items: [null, ..._sites],
              hint: 'All Sites',
              onChanged: (v) {
                setState(() => _selectedSite = v);
                _loadWorkersData();
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField(
              label: 'Month',
              icon: Icons.calendar_today_outlined,
              value: _selectedMonth,
              items: _months,
              hint: 'Select Month',
              onChanged: (v) {
                setState(() => _selectedMonth = v);
                _loadWorkersData();
              },
            ),
            if (_selectedMonth != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Current Month: $_selectedMonth',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String?> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item ?? hint),
            );
          }).toList(),
          onChanged: onChanged,
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
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(worker['id']),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(worker['designation'], style: theme.textTheme.bodySmall),
                  Text(
                    worker['site'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹ ${worker['calculatedSalary'].toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Present: ${worker['presentDays'] ?? 0} days',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedWorkerIds.contains(id))
        _selectedWorkerIds.remove(id);
      else
        _selectedWorkerIds.add(id);
    });
  }

  void _submitReports() async {
    if (_selectedWorkerIds.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final workerId in _selectedWorkerIds) {
        // Find the worker's comprehensive summary
        final workerData = _filteredWorkers.firstWhere(
          (w) => w['id'] == workerId,
          orElse: () => <String, dynamic>{},
        );

        if (workerData.isEmpty) {
          debugPrint('Worker data not found for id: $workerId');
          continue;
        }

        // 1. Save to WorkerAllDetails (the submitted snapshot)
        final allDetailsRef = FirestoreService.getCollection(
          'WorkerAllDetails',
        ).doc('${workerId}_${workerData['month']}');

        batch.set(allDetailsRef, {
          'workerId': workerId,
          'workerName': workerData['name'],
          'designation': workerData['designation'],
          'site': workerData['site'],
          'month': workerData['month'],
          'baseSalary': workerData['baseSalary'],
          'calculatedSalary': workerData['calculatedSalary'],
          'totalPresentDays': workerData['presentDays'] ?? 0,
          'attendanceData': workerData['attendance'],
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Mark the source monthly document as submitted
        final monthlyDocRef = FirestoreService.getCollection(
          'WorkerMonthlyAttendance',
        ).doc('${workerId}_${workerData['month']}');

        batch.update(monthlyDocRef, {
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully submitted ${_selectedWorkerIds.length} worker reports!',
            ),
          ),
        );
        setState(() {
          _selectedWorkerIds.clear();
        });
      }
    } catch (e) {
      debugPrint('Error saving reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to Firebase: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
