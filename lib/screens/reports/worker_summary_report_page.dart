import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
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
  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];
  String? _selectedSite;
  String? _selectedMonth;
  List<String> _sites = [];
  List<String> _months = [];
  bool _isLoading = true;
  String? _expandedWorkerId;
  double _overallAttendancePercentage = 0.0;
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
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

      Query<Map<String, dynamic>> attQuery = FirestoreService.getCollection(
        'workersAttendance',
      ).where('month', isEqualTo: month);

      if (_selectedSite != null) {
        attQuery = attQuery.where('site', isEqualTo: _selectedSite);
      }

      final snapshot = await attQuery.get();

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
          'id': v['name'],
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
          _allWorkers = results;
          _applySearchFilter();
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

  void _applySearchFilter() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredWorkers = List.from(_allWorkers);
    } else {
      _filteredWorkers = _allWorkers.where((w) {
        final name = (w['name'] ?? '').toString().toLowerCase();
        final designation = (w['designation'] ?? '').toString().toLowerCase();
        final site = (w['site'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            designation.contains(query) ||
            site.contains(query);
      }).toList();
    }
  }

  double _calculateTotalPayroll() {
    return _filteredWorkers.fold(
      0.0,
      (acc, item) => acc + ((item['calculatedSalary'] as num?)?.toDouble() ?? 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Worker Attendance & Summary',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildFilterAndMetricsCard(primaryColor),
                      _buildSearchBar(primaryColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  'Workers List (${_filteredWorkers.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A183D),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total: ₹${_calculateTotalPayroll().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
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
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.people_outline_rounded,
                                        size: 48,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No workers found',
                                      style: TextStyle(
                                        color: Color(0xFF0A183D),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Try adjusting your search query or filters',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                itemCount: _filteredWorkers.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (ctx, i) {
                                  return _buildWorkerCard(
                                    _filteredWorkers[i],
                                    primaryColor,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndMetricsCard(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                child: Icon(Icons.tune_rounded, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filter & Report Controls',
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
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Site',
                  icon: Icons.location_on_rounded,
                  value: _selectedSite,
                  items: [null, ..._sites],
                  hint: 'All Sites',
                  primaryColor: primaryColor,
                  onChanged: (v) {
                    setState(() => _selectedSite = v);
                    _loadWorkersData();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdownField(
                  label: 'Month',
                  icon: Icons.calendar_month_rounded,
                  value: _selectedMonth,
                  items: _months,
                  hint: 'Select Month',
                  primaryColor: primaryColor,
                  onChanged: (v) {
                    setState(() => _selectedMonth = v);
                    _loadWorkersData();
                  },
                ),
              ),
            ],
          ),
          if (_selectedMonth != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overall Attendance',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        '${_overallAttendancePercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _overallAttendancePercentage > 80
                              ? const Color(0xFF059669)
                              : _overallAttendancePercentage > 50
                              ? const Color(0xFFD97706)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _overallAttendancePercentage / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _overallAttendancePercentage > 80
                            ? const Color(0xFF059669)
                            : _overallAttendancePercentage > 50
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _onGenerateOverallReport,
                      icon: const Icon(Icons.summarize_rounded, size: 18),
                      label: const Text(
                        'Download Overall Report (PDF)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A183D).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              _applySearchFilter();
            });
          },
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search worker by name, role, or site...',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _applySearchFilter();
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
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
    required Color primaryColor,
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
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: value,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              prefixIcon: Icon(icon, color: primaryColor, size: 18),
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w400),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item ?? hint,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, Color primaryColor) {
    final isExpanded = _expandedWorkerId == worker['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedWorkerId = isExpanded ? null : worker['id'];
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                worker['designation'],
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.location_on_rounded, size: 12, color: primaryColor),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                worker['site'],
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${((worker['calculatedSalary'] as num?) ?? 0).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: primaryColor,
                        ),
                      ),
                      const Text(
                        'Estimated Pay',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('Present', worker['present'] ?? 0, const Color(0xFF059669), const Color(0xFFDCFCE7)),
                  _buildStatBadge('Absent', worker['absent'] ?? 0, const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                  _buildStatBadge('Overtime', worker['overtime'] ?? 0, const Color(0xFFD97706), const Color(0xFFFFEDD5)),
                  _buildStatBadge('Half Day', worker['halfDay'] ?? 0, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                  _buildStatBadge('Not Marked', worker['notMarked'] ?? 0, const Color(0xFF64748B), const Color(0xFFF1F5F9)),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _onGenerateReport(worker),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text(
                      'Generate Individual Report (PDF)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onGenerateReport(Map<String, dynamic> worker) async {
    setState(() => _isLoading = true);
    try {
      final primaryColor = Theme.of(context).primaryColor;
      final pdfPrimaryColor = PdfColor.fromInt(primaryColor.toARGB32());
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
      final pdfPrimaryColor = PdfColor.fromInt(primaryColor.toARGB32());
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
                'OverallReport_${_selectedSite ?? 'All'}_$_selectedMonth.pdf',
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
}
