import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import '/widgets/glass_scaffold.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import 'package:demo_cst/screens/reports/pdf_preview_page.dart';
import 'package:demo_cst/screens/reports/worker_report_pdf_helper.dart';
import 'package:demo_cst/screens/reports/overall_report_pdf_helper.dart';

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
  String? _expandedWorkerId;
  double _overallAttendancePercentage = 0.0;
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Fetch unique sites and months from workersAttendance documents (The collection structure as requested)
      final attendanceSnapshot = await FirestoreService.getCollection(
        'workersAttendance',
      ).get();

      final Set<String> uniqueSites = {};
      final Set<String> uniqueMonths = {_currentMonth};

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final site = data['site']?.toString();
        final month = data['month']?.toString();

        if (site != null && site.isNotEmpty) uniqueSites.add(site);
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

      // 1. Query workersAttendance documents for the selected month (and site if selected)
      Query<Map<String, dynamic>> attQuery = FirestoreService.getCollection(
        'workersAttendance',
      ).where('month', isEqualTo: month);

      if (_selectedSite != null) {
        attQuery = attQuery.where('site', isEqualTo: _selectedSite);
      }

      final snapshot = await attQuery.get();

      // 2. Aggregate counts for each worker
      // Map<workerName, Map<statName, count>>
      final Map<String, Map<String, dynamic>> workerAggregates = {};
      double totalPoints = 0;
      int totalDaysDetected = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final workersMap = data['workers'] as Map<String, dynamic>? ?? {};

        workersMap.forEach((name, details) {
          if (details is! Map) return;

          if (!workerAggregates.containsKey(name)) {
            workerAggregates[name] = {
              'name': name,
              'designation': details['designation'] ?? 'Worker',
              'site': data['site'] ?? 'Unknown',
              'presentCount': 0,
              'absentCount': 0,
              'overtimeCount': 0,
              'halfDayCount': 0,
              'notMarkedCount': 0,
              'totalSalary': 0.0,
              'attendanceData': <String, dynamic>{},
              'month': month,
              'baseSalary': details['salary'] ?? '0',
            };
          }

          final stats = workerAggregates[name]!;
          final String status =
              details['attendance']?.toString().toLowerCase() ?? '';
          final String dateStr = data['Day'] ?? 'Unknown Date';

          stats['attendanceData'][dateStr] = details;
          totalDaysDetected++;

          if (status == 'present') {
            stats['presentCount']++;
            totalPoints += 1.0;
          } else if (status == 'absent') {
            stats['absentCount']++;
          } else if (status == 'overtime') {
            stats['overtimeCount']++;
            totalPoints += 1.0;
          } else if (status == 'half day') {
            stats['halfDayCount']++;
            totalPoints += 0.5;
          } else if (status == '' || status == 'not marked') {
            stats['notMarkedCount']++;
          }

          // salary calculation
          final double daySalary =
              double.tryParse(details['salary']?.toString() ?? '0') ?? 0.0;
          if (status == 'present' || status == 'overtime') {
            stats['totalSalary'] += daySalary;
          } else if (status == 'half day') {
            stats['totalSalary'] += (daySalary / 2.0);
          }
        });
      }

      final double overallPercent = totalDaysDetected > 0
          ? (totalPoints / totalDaysDetected) * 100
          : 0.0;

      final List<Map<String, dynamic>> results = workerAggregates.values.map((
        v,
      ) {
        return {
          'id':
              v['name'], // Using name as ID for this specific report structure
          'name': v['name'],
          'designation': v['designation'],
          'site': v['site'],
          'month': v['month'],
          'baseSalary': v['baseSalary'],
          'present': v['presentCount'],
          'absent': v['absentCount'],
          'overtime': v['overtimeCount'],
          'halfDay': v['halfDayCount'],
          'notMarked': v['notMarkedCount'],
          'calculatedSalary': v['totalSalary'],
          'attendanceData': v['attendanceData'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _filteredWorkers = results;
          _overallAttendancePercentage = overallPercent;
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

  Map<String, dynamic> _calculateSalaryFromMap(
    String base,
    Map<String, dynamic> attMap,
  ) {
    final double b = double.tryParse(base) ?? 0.0;
    double totalSalary = 0.0;
    int presentDays = 0;

    attMap.forEach((date, details) {
      if (details is Map) {
        final String status = details['status']?.toString().toLowerCase() ?? '';
        final double salaryPerDay =
            double.tryParse(details['salaryPerDay']?.toString() ?? base) ?? b;

        if (status == 'present' || status == 'overtime') {
          totalSalary += salaryPerDay;
          presentDays += 1;
        } else if (status == 'half day') {
          totalSalary += (salaryPerDay / 2.0);
          presentDays += 1;
        }
      }
    });

    return {'salary': totalSalary, 'presentDays': presentDays};
  }

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Worker Attendance & Summary',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterBar(theme, isMobile),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A183D),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Workers (${_filteredWorkers.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredWorkers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                size: 72,
                                color: Color(0xFF0A183D),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No workers found',
                                style: TextStyle(
                                  color: Color(0xFF0A183D),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredWorkers.length,
                          itemBuilder: (ctx, i) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 400 + (i * 100)),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: _buildWorkerCard(
                                      _filteredWorkers[i],
                                      theme,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isMobile) {
    final darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Site',
              icon: Icons.handyman_rounded,
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
              icon: Icons.calendar_today_rounded,
              value: _selectedMonth,
              items: _months,
              hint: 'Select Month',
              onChanged: (v) {
                setState(() => _selectedMonth = v);
                _loadWorkersData();
              },
            ),
            if (_selectedMonth != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Attendance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        Text(
                          '${_overallAttendancePercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _overallAttendancePercentage / 100,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _overallAttendancePercentage > 80
                              ? const Color(0xFF22C55E)
                              : _overallAttendancePercentage > 50
                              ? Colors.orangeAccent
                              : const Color(0xFFF87171),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _onGenerateOverallReport,
                        icon: const Icon(Icons.summarize_rounded, size: 20),
                        label: const Text(
                          'Download Overall Report',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: const Color(0xFF0A183D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Month: $_selectedMonth',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFF0A183D),
                ),
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item ?? hint,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, ThemeData theme) {
    final cs = theme.colorScheme;

    final isExpanded = _expandedWorkerId == worker['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () {
          setState(() {
            _expandedWorkerId = isExpanded ? null : worker['id'];
          });
        },
        child: Column(
          children: [
            Row(
              children: [
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
                      Text(
                        worker['designation'],
                        style: theme.textTheme.bodySmall,
                      ),
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
                      'Estimated',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Present', worker['present'] ?? 0, Colors.green),
                _buildStatItem('Absent', worker['absent'] ?? 0, Colors.red),
                _buildStatItem(
                  'Overtime',
                  worker['overtime'] ?? 0,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Not Marked',
                  worker['notMarked'] ?? 0,
                  Colors.grey,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          opacity: isExpanded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: SizedBox(
                            width: double.infinity,
                            child: GlassButton(
                              onPressed: () => _onGenerateReport(worker),
                              label: 'Generate Report',
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onGenerateReport(Map<String, dynamic> worker) async {
    setState(() => _isLoading = true);
    try {
      final primaryColor = Theme.of(context).primaryColor;
      final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
      final pdfBytes = await WorkerReportPdf.build(
        worker: worker,
        primaryColor: pdfPrimaryColor,
      );
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName: 'WorkerReport_${worker['name']}_${worker['month']}.pdf',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGenerateOverallReport() async {
    if (_filteredWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workers to report for this month.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final primaryColor = Theme.of(context).primaryColor;
      final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
      final pdfBytes = await OverallReportPdf.build(
        workers: _filteredWorkers,
        site: _selectedSite ?? 'All Sites',
        month: _selectedMonth ?? _currentMonth,
        overallPercentage: _overallAttendancePercentage,
        primaryColor: pdfPrimaryColor,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName:
                'OverallReport_${_selectedSite ?? 'All'}_${_selectedMonth}.pdf',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating Overall PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
