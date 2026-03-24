import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';

class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  _AttendanceManagementPageState createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected values
  String? _selectedSite;
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _workers = [];

  // Loading states
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;
  bool _isSubmitting = false;

  // Attendance state
  final Map<String, String> _attendanceStatus = {};
  final String _currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
  final String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoadingSites = true;
    });

    try {
      final querySnapshot = await FirestoreService.getCollection('workerSiteMap').get();
      setState(() {
        _sites = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'site': data['site'] ?? '',
            'supervisor': data['supervisor'] ?? '',
            'projectName': data['projectName'] ?? '',
            'totalWorkers': data['totalWorkers'] ?? 0,
          };
        }).toList();
        _isLoadingSites = false;
      });
    } catch (e) {
      print('Error loading sites: $e');
      setState(() {
        _isLoadingSites = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
    }
  }

  Future<void> _loadWorkersForSite(String site) async {
    setState(() {
      _isLoadingWorkers = true;
      _workers = [];
      _attendanceStatus.clear();
    });

    try {
      final doc = await FirestoreService.getCollection('workerSiteMap').doc(site).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final workersList = List<Map<String, dynamic>>.from(
          data['workers'] ?? [],
        );

        // Load existing attendance for today if any
        await _loadExistingAttendance(site);

        setState(() {
          _workers = workersList;
          _isLoadingWorkers = false;
        });
      } else {
        setState(() {
          _isLoadingWorkers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No workers found for this site')),
        );
      }
    } catch (e) {
      print('Error loading workers: $e');
      setState(() {
        _isLoadingWorkers = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
    }
  }

  Future<void> _loadExistingAttendance(String site) async {
    try {
      final docId =
          '${site}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}';
      final doc = await FirestoreService.getCollection('WorkerSummary').doc(docId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final workersData = data['workers'] as Map<String, dynamic>?;

        if (workersData != null) {
          setState(() {
            workersData.forEach((workerName, workerData) {
              _attendanceStatus[workerName] = workerData['attendance'] ?? '';
            });
          });
        }
      }
    } catch (e) {
      print('Error loading existing attendance: $e');
    }
  }

  void _onSiteSelected(String? site) {
    setState(() {
      _selectedSite = site;
      _workers.clear();
      _attendanceStatus.clear();
    });

    if (site != null) {
      _loadWorkersForSite(site);
    }
  }

  void _setAttendance(String workerName, String status) {
    setState(() {
      _attendanceStatus[workerName] = status;
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedSite == null || _workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a site with workers')),
      );
      return;
    }

    // Check if all workers have attendance marked
    final workersWithoutAttendance = _workers.where((worker) {
      final workerName = worker['workerName']?.toString() ?? '';
      return _attendanceStatus[workerName]?.isEmpty ?? true;
    }).toList();

    if (workersWithoutAttendance.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please mark attendance for all workers')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final docId =
          '${_selectedSite!}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}';
      final summaryDocId = '${_selectedSite!}_$_currentMonth';

      // Prepare workers data for daily attendance
      final Map<String, dynamic> workersData = {};

      for (final worker in _workers) {
        final workerName = worker['workerName']?.toString() ?? '';
        final attendanceStatus = _attendanceStatus[workerName] ?? '';

        workersData[workerName] = {
          'designation': worker['workerDesignation'] ?? '',
          'salary': worker['workerSalary'] ?? '',
          'attendance': attendanceStatus,
        };
      }

      // Submit to workersAttendance collection
      await FirestoreService.getCollection('workersAttendance').doc(docId).set({
        'Day': _currentDate,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'month': _currentMonth,
        'site': _selectedSite,
        'workers': workersData,
      }, SetOptions(merge: true));

      // Update workersSummary collection
      await _updateWorkersSummary(summaryDocId, workersData);

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance submitted successfully for ${_workers.length} workers',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e')),
      );
    }
  }

  Future<void> _updateWorkersSummary(
    String docId,
    Map<String, dynamic> dailyAttendance,
  ) async {
    try {
      final doc = await _firestore
          .collection('workersSummary')
          .doc(docId)
          .get();

      if (doc.exists) {
        // Document exists - update existing data
        final existingData = doc.data() as Map<String, dynamic>;
        final existingWorkers =
            existingData['workers'] as Map<String, dynamic>? ?? {};

        // Create a copy of existing workers data to modify
        final updatedWorkers = Map<String, dynamic>.from(existingWorkers);

        // Update attendance for each worker
        dailyAttendance.forEach((workerName, dailyData) {
          final attendanceStatus = dailyData['attendance'] as String;
          final designation = dailyData['designation'] as String;
          final salary = dailyData['salary'] as String;

          if (updatedWorkers.containsKey(workerName)) {
            // Worker exists - update attendance counts
            final existingWorker =
                updatedWorkers[workerName] as Map<String, dynamic>;
            final existingAttendance =
                existingWorker['attendance'] as Map<String, dynamic>? ?? {};

            final presentDays =
                int.tryParse(
                  existingAttendance['presentDays']
                          ?.toString()
                          .split(' ')
                          .first ??
                      '0',
                ) ??
                0;
            final absentDays =
                int.tryParse(
                  existingAttendance['absentDays']
                          ?.toString()
                          .split(' ')
                          .first ??
                      '0',
                ) ??
                0;
            final overtimeDays =
                int.tryParse(
                  existingAttendance['overtimeDays']
                          ?.toString()
                          .split(' ')
                          .first ??
                      '0',
                ) ??
                0;
            final halfDays =
                int.tryParse(
                  existingAttendance['halfDays']?.toString().split(' ').first ??
                      '0',
                ) ??
                0;

            // Increment the appropriate counter
            switch (attendanceStatus.toLowerCase()) {
              case 'present':
                updatedWorkers[workerName] = {
                  ...existingWorker,
                  'attendance': {
                    'presentDays': '${presentDays + 1} days',
                    'absentDays': '$absentDays days',
                    'overtimeDays': '$overtimeDays days',
                    'halfDays': '$halfDays days',
                    'totalWorkingDays':
                        '${presentDays + 1 + overtimeDays + (halfDays * 0.5).round()} days',
                  },
                };
                break;
              case 'absent':
                updatedWorkers[workerName] = {
                  ...existingWorker,
                  'attendance': {
                    'presentDays': '$presentDays days',
                    'absentDays': '${absentDays + 1} days',
                    'overtimeDays': '$overtimeDays days',
                    'halfDays': '$halfDays days',
                    'totalWorkingDays':
                        '${presentDays + overtimeDays + (halfDays * 0.5).round()} days',
                  },
                };
                break;
              case 'overtime':
                updatedWorkers[workerName] = {
                  ...existingWorker,
                  'attendance': {
                    'presentDays': '$presentDays days',
                    'absentDays': '$absentDays days',
                    'overtimeDays': '${overtimeDays + 1} days',
                    'halfDays': '$halfDays days',
                    'totalWorkingDays':
                        '${presentDays + (overtimeDays + 1) + (halfDays * 0.5).round()} days',
                  },
                };
                break;
              case 'half day':
                updatedWorkers[workerName] = {
                  ...existingWorker,
                  'attendance': {
                    'presentDays': '$presentDays days',
                    'absentDays': '$absentDays days',
                    'overtimeDays': '$overtimeDays days',
                    'halfDays': '${halfDays + 1} days',
                    'totalWorkingDays':
                        '${presentDays + overtimeDays + ((halfDays + 1) * 0.5).round()} days',
                  },
                };
                break;
            }
          } else {
            // New worker - initialize with first attendance
            switch (attendanceStatus.toLowerCase()) {
              case 'present':
                updatedWorkers[workerName] = {
                  'designation': designation,
                  'salary': salary,
                  'attendance': {
                    'presentDays': '1 day',
                    'absentDays': '0 days',
                    'overtimeDays': '0 days',
                    'halfDays': '0 days',
                    'totalWorkingDays': '1 day',
                  },
                };
                break;
              case 'absent':
                updatedWorkers[workerName] = {
                  'designation': designation,
                  'salary': salary,
                  'attendance': {
                    'presentDays': '0 days',
                    'absentDays': '1 day',
                    'overtimeDays': '0 days',
                    'halfDays': '0 days',
                    'totalWorkingDays': '0 days',
                  },
                };
                break;
              case 'overtime':
                updatedWorkers[workerName] = {
                  'designation': designation,
                  'salary': salary,
                  'attendance': {
                    'presentDays': '0 days',
                    'absentDays': '0 days',
                    'overtimeDays': '1 day',
                    'halfDays': '0 days',
                    'totalWorkingDays': '1 day',
                  },
                };
                break;
              case 'half day':
                updatedWorkers[workerName] = {
                  'designation': designation,
                  'salary': salary,
                  'attendance': {
                    'presentDays': '0 days',
                    'absentDays': '0 days',
                    'overtimeDays': '0 days',
                    'halfDays': '1 day',
                    'totalWorkingDays': '0.5 day',
                  },
                };
                break;
            }
          }
        });

        // Update the document with modified data
        await FirestoreService.getCollection('workersSummary').doc(docId).set({
          'updatedAt': FieldValue.serverTimestamp(),
          'month': _currentMonth,
          'site': _selectedSite,
          'workers': updatedWorkers,
        }, SetOptions(merge: true));
      } else {
        // Document doesn't exist - create new with initial data
        final Map<String, dynamic> summaryWorkersData = {};

        dailyAttendance.forEach((workerName, dailyData) {
          final attendanceStatus = dailyData['attendance'] as String;
          final designation = dailyData['designation'] as String;
          final salary = dailyData['salary'] as String;

          switch (attendanceStatus.toLowerCase()) {
            case 'present':
              summaryWorkersData[workerName] = {
                'designation': designation,
                'salary': salary,
                'attendance': {
                  'presentDays': '1 day',
                  'absentDays': '0 days',
                  'overtimeDays': '0 days',
                  'halfDays': '0 days',
                  'totalWorkingDays': '1 day',
                },
              };
              break;
            case 'absent':
              summaryWorkersData[workerName] = {
                'designation': designation,
                'salary': salary,
                'attendance': {
                  'presentDays': '0 days',
                  'absentDays': '1 day',
                  'overtimeDays': '0 days',
                  'halfDays': '0 days',
                  'totalWorkingDays': '0 days',
                },
              };
              break;
            case 'overtime':
              summaryWorkersData[workerName] = {
                'designation': designation,
                'salary': salary,
                'attendance': {
                  'presentDays': '0 days',
                  'absentDays': '0 days',
                  'overtimeDays': '1 day',
                  'halfDays': '0 days',
                  'totalWorkingDays': '1 day',
                },
              };
              break;
            case 'half day':
              summaryWorkersData[workerName] = {
                'designation': designation,
                'salary': salary,
                'attendance': {
                  'presentDays': '0 days',
                  'absentDays': '0 days',
                  'overtimeDays': '0 days',
                  'halfDays': '1 day',
                  'totalWorkingDays': '0.5 day',
                },
              };
              break;
          }
        });

        await FirestoreService.getCollection('workersSummary').doc(docId).set({
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'month': _currentMonth,
          'site': _selectedSite,
          'workers': summaryWorkersData,
        });
      }
    } catch (e) {
      print('Error updating workers summary: $e');
      rethrow; // Re-throw to handle in the main submit method
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'overtime':
        return Colors.orange;
      case 'half day':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'overtime':
        return 'Overtime';
      case 'half day':
        return 'Half Day';
      default:
        return 'Not Marked';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Selection
            _buildSectionHeader('Select Site'),
            _buildSiteSelectionSection(),

            SizedBox(height: 24),

            // Workers Attendance Table
            if (_selectedSite != null) _buildAttendanceSection(),

            if (_workers.isNotEmpty) SizedBox(height: 24),

            // Submit Button
            if (_workers.isNotEmpty) _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildSiteSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSite,
              decoration: InputDecoration(
                labelText: 'Site *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.construction),
              ),
              items: _isLoadingSites
                  ? [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Loading sites...'),
                      ),
                    ]
                  : _sites.map<DropdownMenuItem<String>>((site) {
                      return DropdownMenuItem<String>(
                        value: site['site'] as String?,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(site['site'] ?? ''),
                            // Text(
                            //   '${site['totalWorkers']} workers • ${site['supervisor']}',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     color: Colors.grey,
                            //   ),
                            // ),
                          ],
                        ),
                      );
                    }).toList(),
              onChanged: _onSiteSelected,
            ),

            if (_selectedSite != null) SizedBox(height: 12),

            if (_selectedSite != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Date: $_currentDate',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Workers Attendance (${_workers.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  if (_workers.isNotEmpty)
                    Chip(
                      label: Text(
                        '${_attendanceStatus.values.where((status) => status.isNotEmpty).length}/${_workers.length} marked',
                        style: TextStyle(),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                ],
              ),
              SizedBox(height: 16),

              if (_isLoadingWorkers)
                Center(child: CircularProgressIndicator())
              else if (_workers.isEmpty)
                Center(
                  child: Text(
                    'No workers found for this site',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey[100],
                        ),
                        columns: [
                          DataColumn(label: Text('No.')),
                          DataColumn(label: Text('Worker Name')),
                          DataColumn(label: Text('Designation')),
                          // DataColumn(label: Text('Salary/Day')),
                          DataColumn(label: Text('Attendance Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _workers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final worker = entry.value;
                          final workerName =
                              worker['workerName']?.toString() ?? '';
                          final currentStatus =
                              _attendanceStatus[workerName] ?? '';

                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(
                                Text(
                                  workerName,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(Text(worker['workerDesignation'] ?? '')),
                              // DataCell(
                              //   Text('₹${worker['workerSalary'] ?? '0'}'),
                              // ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      currentStatus,
                                    ).withOpacity(0.1),
                                    border: Border.all(
                                      color: _getStatusColor(currentStatus),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusText(currentStatus),
                                    style: TextStyle(
                                      color: _getStatusColor(currentStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    _buildAttendanceButton(
                                      'Present',
                                      workerName,
                                      currentStatus,
                                    ),
                                    SizedBox(width: 4),
                                    _buildAttendanceButton(
                                      'Absent',
                                      workerName,
                                      currentStatus,
                                    ),
                                    SizedBox(width: 4),
                                    _buildAttendanceButton(
                                      'Overtime',
                                      workerName,
                                      currentStatus,
                                    ),
                                    SizedBox(width: 4),
                                    _buildAttendanceButton(
                                      'Half Day',
                                      workerName,
                                      currentStatus,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceButton(
    String status,
    String workerName,
    String currentStatus,
  ) {
    final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
    final color = _getStatusColor(status);

    return Tooltip(
      message: status,
      child: GestureDetector(
        onTap: () => _setAttendance(workerName, status),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              status[0].toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final markedCount = _attendanceStatus.values
        .where((status) => status.isNotEmpty)
        .length;
    final allMarked = markedCount == _workers.length;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: allMarked && !_isSubmitting ? _submitAttendance : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: allMarked ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Submitting...'),
                ],
              )
            : Text(
                allMarked
                    ? 'Submit Attendance for $_currentDate'
                    : 'Mark All Attendance to Submit ($markedCount/${_workers.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
