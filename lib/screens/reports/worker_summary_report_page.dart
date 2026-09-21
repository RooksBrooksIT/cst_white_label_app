import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import '/utils/responsive.dart';
import 'package:ebricks/screens/reports/pdf_preview_page.dart';
import 'package:ebricks/screens/reports/worker_report_pdf_helper.dart';
import 'package:ebricks/screens/reports/overall_report_pdf_helper.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class WorkerAttendanceSalaryPage extends StatefulWidget {
  const WorkerAttendanceSalaryPage({super.key});

  @override
  State<WorkerAttendanceSalaryPage> createState() =>
      _WorkerAttendanceSalaryPageState();
}

class _WorkerAttendanceSalaryPageState
    extends State<WorkerAttendanceSalaryPage> {
  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];
  String? _selectedSite;
  String? _selectedMonth;
  List<String> _sites = [];
  bool _isLoading = true;
  String? _expandedWorkerId;
  double _overallAttendancePercentage = 0.0;
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _extraWorkersSummary = {};
  int _totalExtraWorkersInMonth = 0;

  DateTime _selectedDate = DateTime.now();

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
      final Map<String, String> siteMap = {};

      // 1. Preload from projects
      try {
        final projSnap = await FirestoreService.projects.get();
        for (final doc in projSnap.docs) {
          final d = doc.data();
          final sId = (d['siteId'] ?? d['id'] ?? doc.id).toString();
          final sName = (d['siteName'] ?? d['projectName'] ?? '').toString();
          final display = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          if (display.isNotEmpty) siteMap[display] = display;
        }
      } catch (e) {
        debugPrint('Error loading projects for sites in summary: $e');
      }

      // 2. Preload from Site collection
      try {
        final siteSnap = await FirestoreService.sites.get();
        for (final doc in siteSnap.docs) {
          final d = doc.data();
          final sId = (d['siteId'] ?? d['siteCode'] ?? doc.id).toString();
          final sName = (d['siteName'] ?? d['name'] ?? '').toString();
          final display = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          if (display.isNotEmpty) siteMap[display] = display;
        }
      } catch (e) {
        debugPrint('Error loading Site collection for sites in summary: $e');
      }

      // 3. Preload from workerSiteMapping
      try {
        final mappingSnap = await FirestoreService.getCollection('workerSiteMapping').get();
        for (final doc in mappingSnap.docs) {
          final d = doc.data();
          final sId = (d['siteId'] ?? d['site'] ?? doc.id).toString();
          final sName = (d['siteName'] ?? d['projectName'] ?? '').toString();
          final display = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          if (display.isNotEmpty) siteMap[display] = display;
        }
      } catch (e) {
        debugPrint('Error loading workerSiteMapping for sites in summary: $e');
      }

      // 4. Preload from workersAttendance
      try {
        final attendanceSnapshot = await FirestoreService.getCollection(
          'workersAttendance',
        ).get();
        for (var doc in attendanceSnapshot.docs) {
          final d = doc.data();
          final sId = (d['siteId'] ?? d['site'] ?? doc.id).toString();
          final sName = (d['siteName'] ?? d['projectName'] ?? '').toString();
          final display = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          if (display.isNotEmpty) siteMap[display] = display;
        }
      } catch (e) {
        debugPrint('Error loading workersAttendance for sites in summary: $e');
      }

      final sortedSites = siteMap.values.toList()..sort();

      if (!mounted) return;
      setState(() {
        _sites = sortedSites;
        _selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
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

  Future<void> _pickMonthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Month & Year',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final newMonth = DateFormat('yyyy-MM').format(picked);
      setState(() {
        _selectedDate = picked;
        _selectedMonth = newMonth;
      });
      _loadWorkersData();
    }
  }

  Future<void> _loadWorkersData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final targetYear = _selectedDate.year;
      final targetMonth = _selectedDate.month;
      final monthStrMonthYear = DateFormat('MM-yyyy').format(_selectedDate);
      final monthStrYearMonth = DateFormat('yyyy-MM').format(_selectedDate);
      final monthStrShortMonthYear = '$targetMonth-$targetYear';
      final monthStrYearShortMonth = '$targetYear-$targetMonth';

      final targetMonthKeys = {
        monthStrMonthYear.toLowerCase(),
        monthStrYearMonth.toLowerCase(),
        monthStrShortMonthYear.toLowerCase(),
        monthStrYearShortMonth.toLowerCase(),
      };

      final selectedSiteCleanId = _selectedSite != null ? SiteDisplayHelper.extractSiteId(_selectedSite!).toLowerCase() : '';
      final selectedSiteCleanName = _selectedSite != null ? SiteDisplayHelper.extractSiteName(_selectedSite!).toLowerCase() : '';
      final selectedSiteRaw = _selectedSite?.toLowerCase() ?? '';

      bool matchesSelectedSite(String? siteId, String? siteName, String? siteCombined, String? docId) {
        if (_selectedSite == null || _selectedSite!.isEmpty) return true;
        final sId = (siteId ?? '').trim().toLowerCase();
        final sName = (siteName ?? '').trim().toLowerCase();
        final sComb = (siteCombined ?? '').trim().toLowerCase();
        final dId = (docId ?? '').trim().toLowerCase();

        if (selectedSiteCleanId.isNotEmpty && (sId == selectedSiteCleanId || dId.contains(selectedSiteCleanId) || sComb.contains(selectedSiteCleanId))) {
          return true;
        }
        if (selectedSiteCleanName.isNotEmpty && (sName == selectedSiteCleanName || dId.contains(selectedSiteCleanName) || sComb.contains(selectedSiteCleanName))) {
          return true;
        }
        if (selectedSiteRaw.isNotEmpty && (sId == selectedSiteRaw || sName == selectedSiteRaw || sComb == selectedSiteRaw || dId == selectedSiteRaw)) {
          return true;
        }
        return false;
      }

      bool matchesTargetMonth(dynamic monthVal, dynamic dateVal, dynamic dayVal, dynamic updatedAtVal, String docId) {
        if (monthVal != null) {
          final mStr = monthVal.toString().trim().toLowerCase();
          if (targetMonthKeys.contains(mStr)) return true;
          if (mStr.contains('$targetYear') && (mStr.contains(targetMonth.toString().padLeft(2, '0')) || mStr.contains('$targetMonth'))) {
            return true;
          }
        }

        final dateStr = (dateVal ?? dayVal ?? '').toString().trim();
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final dMonth = int.tryParse(parts[1]);
            final dYear = int.tryParse(parts[2]);
            if (dMonth == targetMonth && dYear == targetYear) return true;
          }
        } else if (dateStr.contains('-')) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final dYear = int.tryParse(parts[0]);
            final dMonth = int.tryParse(parts[1]);
            if (dMonth == targetMonth && dYear == targetYear) return true;
          }
        }

        if (docId.contains('${targetMonth.toString().padLeft(2, '0')}_$targetYear') ||
            docId.contains('${targetMonth.toString().padLeft(2, '0')}-$targetYear') ||
            docId.contains('$targetYear-${targetMonth.toString().padLeft(2, '0')}') ||
            docId.contains('${targetYear}_${targetMonth.toString().padLeft(2, '0')}')) {
          return true;
        }

        if (updatedAtVal is Timestamp) {
          final dt = updatedAtVal.toDate();
          if (dt.month == targetMonth && dt.year == targetYear) return true;
        }

        return false;
      }

      final Map<String, Map<String, dynamic>> workerAggregates = {};
      double totalPoints = 0;
      int totalDaysDetected = 0;
      final Map<String, int> extraMap = {};
      int totalExtraCount = 0;
      final Set<String> seenExtraKeys = {};

      String normalizeAttendanceDate(dynamic rawDate, dynamic updatedAt, String docId, String fallbackMonth) {
        String dateStr = (rawDate ?? '').toString().trim();
        if (dateStr.isEmpty && updatedAt is Timestamp) {
          dateStr = DateFormat('yyyy-MM-dd').format(updatedAt.toDate());
        }

        if (dateStr.isNotEmpty) {
          // 1. Check yyyy-MM-dd
          if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
            return dateStr;
          }
          // 2. Check dd/MM/yyyy or dd-MM-yyyy or dd_MM_yyyy
          final parts = dateStr.split(RegExp(r'[/_-]'));
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
            } else if (parts[2].length == 4) {
              return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
            }
          }
          // 3. Check single/double digit day number
          if (RegExp(r'^\d{1,2}$').hasMatch(dateStr) && fallbackMonth.isNotEmpty) {
            final day = dateStr.padLeft(2, '0');
            final mParts = fallbackMonth.split(RegExp(r'[-_]'));
            if (mParts.length == 2) {
              if (mParts[0].length == 4) {
                return '${mParts[0]}-${mParts[1].padLeft(2, '0')}-$day';
              } else if (mParts[1].length == 4) {
                return '${mParts[1]}-${mParts[0].padLeft(2, '0')}-$day';
              }
            }
          }
          try {
            final parsed = DateTime.tryParse(dateStr);
            if (parsed != null) {
              return DateFormat('yyyy-MM-dd').format(parsed);
            }
          } catch (_) {}
        }

        // 4. Try extracting date from docId (e.g. ST001_21_09_2026)
        final dmyMatch = RegExp(r'(\d{2})_(\d{2})_(\d{4})').firstMatch(docId);
        if (dmyMatch != null) {
          return '${dmyMatch.group(3)}-${dmyMatch.group(2)}-${dmyMatch.group(1)}';
        }
        final ymdMatch = RegExp(r'(\d{4})[-_](\d{2})[-_](\d{2})').firstMatch(docId);
        if (ymdMatch != null) {
          return '${ymdMatch.group(1)}-${ymdMatch.group(2)}-${ymdMatch.group(3)}';
        }

        if (updatedAt is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(updatedAt.toDate());
        }

        return dateStr.isNotEmpty ? dateStr : docId;
      }

      // 1. Load active worker mappings for baseline worker information
      try {
        final mappingSnap = await FirestoreService.getCollection('workerSiteMapping').get();
        for (final doc in mappingSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['site'] ?? doc.id).toString();
          final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
          final sDisplay = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);

          if (!matchesSelectedSite(sId, sName, sDisplay, doc.id)) continue;

          final rawWorkers = (data['workers'] ?? data['mappedWorkers']) as List<dynamic>? ?? [];
          for (final item in rawWorkers) {
            if (item is Map) {
              final wName = (item['workerName'] ?? item['name'] ?? '').toString().trim();
              final wId = (item['workerId'] ?? item['id'] ?? wName).toString().trim();
              if (wName.isNotEmpty) {
                final key = wName.toLowerCase();
                if (!workerAggregates.containsKey(key)) {
                  workerAggregates[key] = {
                    'id': wId,
                    'name': wName,
                    'designation': (item['workerDesignation'] ?? item['designation'] ?? 'Worker').toString(),
                    'site': sDisplay.isNotEmpty ? sDisplay : sId,
                    'presentCount': 0,
                    'absentCount': 0,
                    'overtimeCount': 0,
                    'halfDayCount': 0,
                    'notMarkedCount': 0,
                    'totalSalary': 0.0,
                    'attendanceData': <String, dynamic>{},
                    'month': monthStrYearMonth,
                    'baseSalary': (item['workerSalary'] ?? item['salary'] ?? '0').toString(),
                  };
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading workerSiteMapping baseline in summary: $e');
      }

      // 2. Fetch and aggregate attendance from workersAttendance
      try {
        final attSnap = await FirestoreService.getCollection('workersAttendance').get();
        for (final doc in attSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['site'] ?? doc.id).toString();
          final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
          final sDisplay = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          final docId = doc.id.trim();

          if (!matchesSelectedSite(sId, sName, sDisplay, docId)) continue;
          if (!matchesTargetMonth(data['month'], data['Day'] ?? data['date'], data['day'], data['updatedAt'], docId)) {
            continue;
          }

          final rawDate = data['Day'] ?? data['date'] ?? data['day'];
          final fallbackMonth = (data['month'] ?? monthStrMonthYear).toString();
          final canonicalDate = normalizeAttendanceDate(rawDate, data['updatedAt'], docId, fallbackMonth);

          // Deduplicate extra workers per site and canonical date
          final extraKey = '${sId}_${sName}_$canonicalDate';
          if (seenExtraKeys.add(extraKey)) {
            final extraList = (data['extraWorkers'] ?? data['extra_workers']) as List<dynamic>? ?? [];
            for (final e in extraList) {
              if (e is Map) {
                final type = (e['workerType'] ?? e['type'] ?? 'General Labour').toString();
                final count = (e['count'] as num?)?.toInt() ?? int.tryParse(e['count']?.toString() ?? '0') ?? 0;
                if (count > 0) {
                  extraMap[type] = (extraMap[type] ?? 0) + count;
                  totalExtraCount += count;
                }
              }
            }
          }

          final workersMap = data['workers'] as Map<String, dynamic>? ?? {};
          workersMap.forEach((nameOrId, details) {
            if (details is! Map) return;

            final wName = (details['workerName'] ?? details['name'] ?? nameOrId).toString().trim();
            if (wName.isEmpty) return;
            final key = wName.toLowerCase();
            final wId = (details['workerId'] ?? details['id'] ?? wName).toString().trim();
            final designation = (details['designation'] ?? details['workerDesignation'] ?? 'Worker').toString();
            final salaryStr = (details['salary'] ?? details['workerSalary'] ?? details['salaryPerDay'] ?? '0').toString();
            final daySalary = double.tryParse(salaryStr) ?? 0.0;
            final status = (details['attendance'] ?? details['status'] ?? '').toString().trim().toLowerCase();

            if (!workerAggregates.containsKey(key)) {
              workerAggregates[key] = {
                'id': wId,
                'name': wName,
                'designation': designation,
                'site': sDisplay.isNotEmpty ? sDisplay : (data['site'] ?? 'Unknown'),
                'presentCount': 0,
                'absentCount': 0,
                'overtimeCount': 0,
                'halfDayCount': 0,
                'notMarkedCount': 0,
                'totalSalary': 0.0,
                'attendanceData': <String, dynamic>{},
                'month': monthStrYearMonth,
                'baseSalary': salaryStr,
              };
            }

            final stats = workerAggregates[key]!;
            final existingEntry = stats['attendanceData'][canonicalDate];
            if (existingEntry == null) {
              stats['attendanceData'][canonicalDate] = details;
              totalDaysDetected++;

              if (status == 'present' || status == 'p') {
                stats['presentCount']++;
                totalPoints += 1.0;
                stats['totalSalary'] += daySalary;
              } else if (status == 'absent' || status == 'a') {
                stats['absentCount']++;
              } else if (status == 'overtime' || status == 'ot') {
                stats['overtimeCount']++;
                totalPoints += 1.0;
                stats['totalSalary'] += daySalary;
              } else if (status == 'half day' || status == 'half-day' || status == 'halfday' || status == 'h') {
                stats['halfDayCount']++;
                totalPoints += 0.5;
                stats['totalSalary'] += (daySalary / 2.0);
              } else {
                stats['notMarkedCount']++;
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading workersAttendance in summary: $e');
      }

      // 3. Aggregate from WorkerMonthlyAttendance
      try {
        final monthlySnap = await FirestoreService.getCollection('WorkerMonthlyAttendance').get();
        for (final doc in monthlySnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? data['site'] ?? '').toString();
          final sName = (data['siteName'] ?? '').toString();
          final sDisplay = SiteDisplayHelper.formatSiteDisplay(siteId: sId, siteName: sName);
          final docMonth = (data['month'] ?? '').toString().trim().toLowerCase();

          if (!matchesSelectedSite(sId, sName, sDisplay, doc.id)) continue;
          if (!targetMonthKeys.contains(docMonth) &&
              !doc.id.contains(monthStrMonthYear) &&
              !doc.id.contains(monthStrYearMonth)) {
            continue;
          }

          final wName = (data['workerName'] ?? data['name'] ?? '').toString().trim();
          if (wName.isEmpty) continue;
          final key = wName.toLowerCase();
          final wId = (data['workerId'] ?? doc.id).toString().trim();
          final designation = (data['designation'] ?? 'Worker').toString();
          final salaryStr = (data['baseSalary'] ?? data['salary'] ?? '0').toString();
          final attendanceData = data['attendanceData'] as Map<String, dynamic>? ?? {};

          if (!workerAggregates.containsKey(key)) {
            workerAggregates[key] = {
              'id': wId,
              'name': wName,
              'designation': designation,
              'site': sDisplay.isNotEmpty ? sDisplay : (data['site'] ?? 'Unknown'),
              'presentCount': 0,
              'absentCount': 0,
              'overtimeCount': 0,
              'halfDayCount': 0,
              'notMarkedCount': 0,
              'totalSalary': 0.0,
              'attendanceData': <String, dynamic>{},
              'month': monthStrYearMonth,
              'baseSalary': salaryStr,
            };
          }

          final stats = workerAggregates[key]!;
          attendanceData.forEach((dateKey, entry) {
            if (entry is! Map) return;
            final canonicalDate = normalizeAttendanceDate(dateKey, null, '', monthStrYearMonth);
            if (!stats['attendanceData'].containsKey(canonicalDate)) {
              stats['attendanceData'][canonicalDate] = entry;
              totalDaysDetected++;
              final status = (entry['status'] ?? entry['attendance'] ?? '').toString().toLowerCase();
              final daySalary = (entry['salaryPerDay'] as num?)?.toDouble() ??
                  double.tryParse(entry['salaryPerDay']?.toString() ?? salaryStr) ??
                  0.0;

              if (status == 'present' || status == 'p') {
                stats['presentCount']++;
                totalPoints += 1.0;
                stats['totalSalary'] += daySalary;
              } else if (status == 'absent' || status == 'a') {
                stats['absentCount']++;
              } else if (status == 'overtime' || status == 'ot') {
                stats['overtimeCount']++;
                totalPoints += 1.0;
                stats['totalSalary'] += daySalary;
              } else if (status == 'half day' || status == 'half-day' || status == 'halfday' || status == 'h') {
                stats['halfDayCount']++;
                totalPoints += 0.5;
                stats['totalSalary'] += (daySalary / 2.0);
              } else {
                stats['notMarkedCount']++;
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading WorkerMonthlyAttendance in summary: $e');
      }

      final double overallPercent = totalDaysDetected > 0
          ? (totalPoints / totalDaysDetected) * 100
          : 0.0;

      final List<Map<String, dynamic>> results = workerAggregates.values.map((v) {
        return {
          'id': v['id'] ?? v['name'],
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

      results.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          _allWorkers = results;
          _extraWorkersSummary = extraMap;
          _totalExtraWorkersInMonth = totalExtraCount;
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final siteField = _buildSiteField(primaryColor);
              final dateField = _buildDateField(primaryColor);

              if (isNarrow) {
                return Column(
                  children: [
                    siteField,
                    const SizedBox(height: 10),
                    dateField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: siteField),
                  const SizedBox(width: 10),
                  Expanded(child: dateField),
                ],
              );
            },
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
                  if (_extraWorkersSummary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.handyman_rounded, color: Color(0xFFD97706), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Extra / Unknown Labour Logged',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              Text(
                                '$_totalExtraWorkersInMonth Total',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _extraWorkersSummary.entries.map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: Text(
                                  '${entry.key}: ${entry.value}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF78350F)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 46),
                    child: ElevatedButton.icon(
                      onPressed: _onGenerateOverallReport,
                      icon: const Icon(Icons.download_rounded, size: 20, color: Colors.white),
                      label: const Text(
                        'Download Overall Report',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildSiteField(Color primaryColor) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedSite,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0F172A), size: 24),
      decoration: InputDecoration(
        labelText: 'Site',
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: Icon(Icons.location_on_rounded, color: primaryColor, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      selectedItemBuilder: (BuildContext context) {
        return [null, ..._sites].map<Widget>((item) {
          final displayText = item == null
              ? 'All Sites'
              : SiteDisplayHelper.formatSiteDisplay(rawCombined: item);
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          );
        }).toList();
      },
      items: [null, ..._sites].map((item) {
        final displayText = item == null
            ? 'All Sites'
            : SiteDisplayHelper.formatSiteDisplay(rawCombined: item);
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            displayText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
        );
      }).toList(),
      onChanged: (v) {
        setState(() => _selectedSite = v);
        _loadWorkersData();
      },
    );
  }

  Widget _buildDateField(Color primaryColor) {
    return InkWell(
      onTap: _pickMonthDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Month / Date',
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0F172A), size: 24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.8),
          ),
        ),
        child: Text(
          DateFormat('MMMM yyyy').format(_selectedDate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
            _applySearchFilter();
          });
        },
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search worker by name, role, or site...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applySearchFilter();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.8),
          ),
        ),
      ),
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
                                SiteDisplayHelper.formatSiteDisplay(siteId: worker['site']),
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
