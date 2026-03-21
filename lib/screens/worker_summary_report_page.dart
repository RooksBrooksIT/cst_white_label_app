import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class WorkerAttendanceSalaryPage extends StatefulWidget {
  const WorkerAttendanceSalaryPage({super.key});

  @override
  _WorkerAttendanceSalaryPageState createState() =>
      _WorkerAttendanceSalaryPageState();
}

class _WorkerAttendanceSalaryPageState
    extends State<WorkerAttendanceSalaryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data lists
  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];

  // Filter options
  String? _selectedSite;
  String? _selectedMonth;
  List<String> _sites = [];
  List<String> _months = [];

  // Loading states
  bool _isLoading = false;
  bool _isGeneratingReport = false;
  bool _isSubmitting = false;

  // Selected workers for report generation
  final Set<String> _selectedWorkerIds = <String>{};

  // Current month for default selection
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Don't set _selectedMonth here; let _loadMonths() set it properly
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadSites();
      await _loadMonths();
      await _loadWorkersData();
    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSites() async {
    try {
      final querySnapshot = await _firestore.collection('workersSummary').get();
      final sites = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['site'] as String?;
          })
          .where((site) => site != null)
          .cast<String>()
          .toSet()
          .toList();

      setState(() {
        _sites = sites;
      });
    } catch (e) {
      print('Error loading sites: $e');
    }
  }

  Future<void> _loadMonths() async {
    try {
      final querySnapshot = await _firestore.collection('workersSummary').get();

      // Use a Set to ensure uniqueness from the start
      final Set<String> uniqueMonths = <String>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final month = data['month'] as String?;
        if (month != null && month.isNotEmpty) {
          uniqueMonths.add(month);
        }
      }

      // Convert to list and sort
      final List<String> months = uniqueMonths.toList();
      months.sort((a, b) => b.compareTo(a)); // Sort descending (newest first)

      if (mounted) {
        setState(() {
          _months = months.isNotEmpty ? months : [_currentMonth];
          // Set _selectedMonth to the first available month or current month
          _selectedMonth = _months.contains(_currentMonth)
              ? _currentMonth
              : (_months.isNotEmpty ? _months.first : _currentMonth);
        });
      }
    } catch (e) {
      print('Error loading months: $e');
      // If no months found, set current month as default
      if (mounted) {
        setState(() {
          _months = [_currentMonth];
          _selectedMonth = _currentMonth;
        });
      }
    }
  }

  Future<void> _loadWorkersData() async {
    try {
      // Get workers from workersSummary collection
      QuerySnapshot summaryQuery;

      if (_selectedSite != null && _selectedMonth != null) {
        summaryQuery = await _firestore
            .collection('workersSummary')
            .where('site', isEqualTo: _selectedSite)
            .where('month', isEqualTo: _selectedMonth)
            .get();
      } else if (_selectedMonth != null) {
        summaryQuery = await _firestore
            .collection('workersSummary')
            .where('month', isEqualTo: _selectedMonth)
            .get();
      } else {
        summaryQuery = await _firestore.collection('workersSummary').get();
      }

      final List<Map<String, dynamic>> workers = [];
      final Set<String> uniqueWorkerKeys = <String>{};

      for (final doc in summaryQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final workersData = data['workers'] as Map<String, dynamic>? ?? {};
        final site = data['site'] as String? ?? 'Unknown Site';
        final month = data['month'] as String? ?? 'Unknown Month';
        final siteId = data['siteId'] as String? ?? 'N/A';

        workersData.forEach((workerName, workerData) {
          final workerDataMap = workerData as Map<String, dynamic>;
          final attendanceData =
              workerDataMap['attendance'] as Map<String, dynamic>? ?? {};
          final baseSalary = workerDataMap['salary']?.toString() ?? '0';

          // Create unique key to avoid duplicates
          final workerKey = '${workerName}_$site';

          if (!uniqueWorkerKeys.contains(workerKey)) {
            uniqueWorkerKeys.add(workerKey);

            workers.add({
              'id': '${workerName}_${site}_$month',
              'name': workerName,
              'designation': workerDataMap['designation'] ?? 'Unknown',
              'baseSalary': baseSalary,
              'site': site,
              'siteId': siteId,
              'month': month,
              'attendance': attendanceData,
              'calculatedSalary': _calculateSalary(baseSalary, attendanceData),
            });
          }
        });
      }

      setState(() {
        _allWorkers = workers;
        _filteredWorkers = _applyFilters(workers);
        _selectedWorkerIds.clear();
      });
    } catch (e) {
      print('Error loading workers data: $e');
    }
  }

  double _calculateSalary(
    String baseSalaryStr,
    Map<String, dynamic> attendance,
  ) {
    try {
      final baseSalary = double.tryParse(baseSalaryStr) ?? 0;

      // Parse attendance days
      final presentDays = _parseDays(
        attendance['presentDays']?.toString() ?? '0',
      );
      final overtimeDays = _parseDays(
        attendance['overtimeDays']?.toString() ?? '0',
      );
      final halfDays = _parseDays(attendance['halfDays']?.toString() ?? '0');

      // Calculate salary
      final presentSalary = presentDays * baseSalary;
      final overtimeSalary = overtimeDays * baseSalary;
      final halfDaySalary = halfDays * (baseSalary / 2);

      return presentSalary + overtimeSalary + halfDaySalary;
    } catch (e) {
      print('Error calculating salary: $e');
      return 0;
    }
  }

  int _parseDays(String daysString) {
    try {
      return int.tryParse(daysString.split(' ').first) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> workers) {
    List<Map<String, dynamic>> filtered = workers;

    if (_selectedSite != null) {
      filtered = filtered
          .where((worker) => worker['site'] == _selectedSite)
          .toList();
    }

    if (_selectedMonth != null) {
      filtered = filtered
          .where((worker) => worker['month'] == _selectedMonth)
          .toList();
    }

    return filtered;
  }

  void _onSiteChanged(String? site) {
    setState(() {
      _selectedSite = site;
      _filteredWorkers = _applyFilters(_allWorkers);
      _selectedWorkerIds.clear();
    });
  }

  void _onMonthChanged(String? month) {
    setState(() {
      _selectedMonth = month;
      _filteredWorkers = _applyFilters(_allWorkers);
      _selectedWorkerIds.clear();
    });
  }

  List<DropdownMenuItem<String>> _getMonthDropdownItems() {
    if (_months.isEmpty) {
      return [
        DropdownMenuItem(
          value: _currentMonth,
          child: Text(
            DateFormat('MMM yyyy').format(DateTime.parse('$_currentMonth-01')),
          ),
        ),
      ];
    }

    // Ensure no duplicates and that _selectedMonth value exists in items
    final uniqueMonths = _months.toSet().toList();
    return uniqueMonths.map((month) {
      return DropdownMenuItem(
        value: month,
        child: Text(DateFormat('MMM yyyy').format(DateTime.parse('$month-01'))),
      );
    }).toList();
  }

  void _toggleWorkerSelection(String workerId) {
    setState(() {
      if (_selectedWorkerIds.contains(workerId)) {
        _selectedWorkerIds.remove(workerId);
      } else {
        _selectedWorkerIds.add(workerId);
      }
    });
  }

  void _selectAllWorkers() {
    setState(() {
      if (_selectedWorkerIds.length == _filteredWorkers.length) {
        _selectedWorkerIds.clear();
      } else {
        _selectedWorkerIds.addAll(
          _filteredWorkers.map((worker) => worker['id'] as String),
        );
      }
    });
  }

  Future<Uint8List> _generatePdfReport(Map<String, dynamic> worker) async {
    final pdf = pw.Document();

    // Load custom font that supports Indian Rupee symbol
    final font = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();

    final attendance = worker['attendance'] as Map<String, dynamic>;

    // Get detailed daily attendance for the selected month
    final dailyAttendance = await _getDailyAttendanceForMonth(worker);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'WORKER ATTENDANCE & SALARY REPORT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Worker Details
              pw.Text(
                'Worker Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Text(
                    'Name: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(worker['name'], style: pw.TextStyle(font: font)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Designation: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(
                    worker['designation'],
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Site: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(worker['site'], style: pw.TextStyle(font: font)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Site ID: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(
                    worker['siteId'] ?? 'N/A',
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Month: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(
                    DateFormat(
                      'MMMM yyyy',
                    ).format(DateTime.parse('${worker['month']}-01')),
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Attendance Summary
              pw.Text(
                'Attendance Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Present Days: ${attendance['presentDays'] ?? '0'}',
                    style: pw.TextStyle(font: font),
                  ),
                  pw.Text(
                    'Absent Days: ${attendance['absentDays'] ?? '0'}',
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Overtime Days: ${attendance['overtimeDays'] ?? '0'}',
                    style: pw.TextStyle(font: font),
                  ),
                  pw.Text(
                    'Half Days: ${attendance['halfDays'] ?? '0'}',
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.Text(
                'Total Working Days: ${attendance['totalWorkingDays'] ?? '0'}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 20),

              // Salary Calculation
              pw.Text(
                'Salary Calculation',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Text(
                    'Base Salary: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(
                    '₹ ${worker['baseSalary']}/day',
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Calculated Salary: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Text(
                    '₹ ${worker['calculatedSalary'].toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Daily Attendance for the Month
              pw.Text(
                'Daily Attendance Records - ${DateFormat('MMMM yyyy').format(DateTime.parse('${worker['month']}-01'))}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 10),

              if (dailyAttendance.isNotEmpty) ...[
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Date',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              font: fontBold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Status',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              font: fontBold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...dailyAttendance.map(
                      (record) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(
                              record['date'],
                              style: pw.TextStyle(font: font, fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(
                              record['attendance'],
                              style: pw.TextStyle(font: font, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                pw.Text(
                  'No daily attendance records found for this month.',
                  style: pw.TextStyle(
                    font: font,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],

              pw.SizedBox(height: 30),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey,
                  font: font,
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  Future<List<Map<String, dynamic>>> _getDailyAttendanceForMonth(
    Map<String, dynamic> worker,
  ) async {
    try {
      final month = worker['month'] as String;
      final site = worker['site'] as String;
      final workerName = worker['name'] as String;

      // Get all attendance records for the specific site and month
      final attendanceQuery = await _firestore
          .collection('workersAttendance')
          .where('site', isEqualTo: site)
          .where('month', isEqualTo: month)
          .orderBy('Day')
          .get();

      final List<Map<String, dynamic>> dailyAttendance = [];

      for (final doc in attendanceQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final workersData = data['workers'] as Map<String, dynamic>? ?? {};
        final day = data['Day'] as String? ?? 'Unknown Date';

        if (workersData.containsKey(workerName)) {
          final workerData = workersData[workerName] as Map<String, dynamic>;
          dailyAttendance.add({
            'date': _formatDate(day),
            'attendance':
                workerData['attendance']?.toString().toUpperCase() ?? 'UNKNOWN',
          });
        } else {
          // If no record for this worker on this day, mark as absent
          dailyAttendance.add({
            'date': _formatDate(day),
            'attendance': 'ABSENT',
          });
        }
      }

      // If no records found in workersAttendance, generate default days for the month
      if (dailyAttendance.isEmpty) {
        dailyAttendance.addAll(_generateDefaultDaysForMonth(month, workerName));
      }

      return dailyAttendance;
    } catch (e) {
      print('Error getting daily attendance: $e');
      // Return default days if there's an error
      return _generateDefaultDaysForMonth(
        worker['month'] as String,
        worker['name'] as String,
      );
    }
  }

  List<Map<String, dynamic>> _generateDefaultDaysForMonth(
    String month,
    String workerName,
  ) {
    final List<Map<String, dynamic>> days = [];
    try {
      final monthDate = DateTime.parse('$month-01');
      final firstDay = DateTime(monthDate.year, monthDate.month, 1);
      final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);

      for (
        var day = firstDay;
        day.isBefore(lastDay.add(Duration(days: 1)));
        day = day.add(Duration(days: 1))
      ) {
        days.add({
          'date': DateFormat('dd/MM/yyyy').format(day),
          'attendance': 'NO RECORD',
        });
      }
    } catch (e) {
      print('Error generating default days: $e');
    }

    return days;
  }

  String _formatDate(String dateString) {
    try {
      // Try different date formats
      final formats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('yyyy/MM/dd'),
      ];

      for (final format in formats) {
        try {
          final date = format.parse(dateString);
          return DateFormat('dd/MM/yyyy').format(date);
        } catch (e) {
          continue;
        }
      }

      // If no format works, return the original string
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _generateAndSavePdf(Map<String, dynamic> worker) async {
    setState(() {
      _isGeneratingReport = true;
    });

    try {
      final pdfBytes = await _generatePdfReport(worker);

      // Use printing dialog instead of saving to file
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report generated for ${worker['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Future<void> _submitSelectedReports() async {
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one worker to submit')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;

      for (final workerId in _selectedWorkerIds) {
        final worker = _filteredWorkers.firstWhere((w) => w['id'] == workerId);

        try {
          // Get detailed attendance records
          final dailyAttendance = await _getDailyAttendanceForMonth(worker);

          // Prepare report data for Firestore
          final reportData = {
            'workerName': worker['name'],
            'designation': worker['designation'],
            'site': worker['site'],
            'siteId': worker['siteId'],
            'month': worker['month'],
            'baseSalary': worker['baseSalary'],
            'calculatedSalary': worker['calculatedSalary'],
            'attendanceSummary': worker['attendance'],
            'dailyAttendance': dailyAttendance,
            'reportGeneratedAt': FieldValue.serverTimestamp(),
            'reportId':
                '${worker['name']}_${worker['site']}_${worker['month']}_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'submitted',
            'submittedAt': FieldValue.serverTimestamp(),
          };

          // Save to WorkerAllDetails collection
          await _firestore
              .collection('WorkerAllDetails')
              .doc(reportData['reportId'])
              .set(reportData);

          successCount++;

          // Small delay to avoid overwhelming Firestore
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          errorCount++;
          print('Error submitting report for ${worker['name']}: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reports submitted: $successCount successful, $errorCount failed',
          ),
          backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // Clear selection after successful submission
      if (errorCount == 0) {
        setState(() {
          _selectedWorkerIds.clear();
        });
      }
    } catch (e) {
      print('Error submitting reports: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting reports: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSite,
                          decoration: InputDecoration(
                            labelText: 'Site',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.construction),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('All Sites'),
                            ),
                            ..._sites.map(
                              (site) => DropdownMenuItem(
                                value: site,
                                child: Text(site),
                              ),
                            ),
                          ],
                          onChanged: _onSiteChanged,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          isExpanded: true,
                          items: _getMonthDropdownItems(),
                          onChanged: _onMonthChanged,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedSite,
                        decoration: InputDecoration(
                          labelText: 'Site',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.construction),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Sites'),
                          ),
                          ..._sites.map(
                            (site) => DropdownMenuItem(
                              value: site,
                              child: Text(site),
                            ),
                          ),
                        ],
                        onChanged: _onSiteChanged,
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        isExpanded: true,
                        items: _getMonthDropdownItems(),
                        onChanged: _onMonthChanged,
                      ),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: 8),
            Text(
              'Current Month: ${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: TextStyle(
                fontSize: 12,
                
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, int index) {
    final attendance = worker['attendance'] as Map<String, dynamic>;
    final isSelected = _selectedWorkerIds.contains(worker['id']);

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? Colors.blue[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleWorkerSelection(worker['id']),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        '${worker['designation']} • ${worker['site']}',
                        style: TextStyle( fontSize: 12),
                      ),
                      Text(
                        'Site ID: ${worker['siteId'] ?? 'N/A'}',
                        style: TextStyle( fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: _isGeneratingReport
                      ? null
                      : () => _generateAndSavePdf(worker),
                  tooltip: 'Generate PDF Report',
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildAttendanceChip(
                  'Present',
                  attendance['presentDays']?.toString() ?? '0',
                  Colors.green,
                ),
                _buildAttendanceChip(
                  'Absent',
                  attendance['absentDays']?.toString() ?? '0',
                  Colors.red,
                ),
                _buildAttendanceChip(
                  'Overtime',
                  attendance['overtimeDays']?.toString() ?? '0',
                  Colors.orange,
                ),
                _buildAttendanceChip(
                  'Half Day',
                  attendance['halfDays']?.toString() ?? '0',
                  Colors.blue,
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Salary',
                      style: TextStyle( fontSize: 10),
                    ),
                    Text(
                      '₹${worker['baseSalary']}/day',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Salary',
                      style: TextStyle( fontSize: 10),
                    ),
                    Text(
                      '₹${worker['calculatedSalary'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Month: ${DateFormat('MMM yyyy').format(DateTime.parse('${worker['month']}-01'))}',
              style: TextStyle( fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    if (_selectedWorkerIds.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedWorkerIds.length} worker(s) selected',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitSelectedReports,
            icon: _isSubmitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.cloud_upload),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Reports'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker Attendance & Salary'),
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
        actions: [
          if (_filteredWorkers.isNotEmpty)
            IconButton(
              icon: Icon(Icons.select_all),
              onPressed: _selectAllWorkers,
              tooltip: 'Select/Deselect All',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildFilterSection(),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Workers (${_filteredWorkers.length})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_filteredWorkers.isNotEmpty)
                              Text(
                                '${_selectedWorkerIds.length} selected',
                                style: TextStyle(
                                  color: Color(0xFF003768),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: _filteredWorkers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No workers found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your filters',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredWorkers.length,
                                  itemBuilder: (context, index) {
                                    return _buildWorkerCard(
                                      _filteredWorkers[index],
                                      index,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }
}
