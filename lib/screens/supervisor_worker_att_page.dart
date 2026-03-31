import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  _AttendanceManagementPageState createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
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
          const SnackBar(content: Text('No workers found for this site')),
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
        const SnackBar(content: Text('Please select a site with workers')),
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
        const SnackBar(content: Text('Please mark attendance for all workers')),
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
      final doc = await FirestoreService
          .getCollection('workersSummary')
          .doc(docId)
          .get();

      if (doc.exists) {
        final existingData = doc.data() as Map<String, dynamic>;
        final existingWorkers =
            existingData['workers'] as Map<String, dynamic>? ?? {};

        final updatedWorkers = Map<String, dynamic>.from(existingWorkers);

        dailyAttendance.forEach((workerName, dailyData) {
          final attendanceStatus = dailyData['attendance'] as String;
          final designation = dailyData['designation'] as String;
          final salary = dailyData['salary'] as String;

          if (updatedWorkers.containsKey(workerName)) {
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

        await FirestoreService.getCollection('workersSummary').doc(docId).set({
          'updatedAt': FieldValue.serverTimestamp(),
          'month': _currentMonth,
          'site': _selectedSite,
          'workers': updatedWorkers,
        }, SetOptions(merge: true));
      } else {
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
      rethrow;
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
    return GlassScaffold(
      title: 'Attendance Management',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Selection
            _buildSectionHeader('Select Site'),
            _buildSiteSelectionSection(),

            const SizedBox(height: 24),

            // Workers Attendance Table
            if (_selectedSite != null) _buildAttendanceSection(),

            if (_workers.isNotEmpty) const SizedBox(height: 24),

            // Submit Button
            if (_workers.isNotEmpty) _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildSiteSelectionSection() {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSite,
              dropdownColor: cs.surfaceContainerHighest,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Site *',
                labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary),
                ),
                prefixIcon: Icon(Icons.construction, color: cs.primary),
                filled: true,
                fillColor: cs.surface.withOpacity(0.1),
              ),
              items: _isLoadingSites
                  ? [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Loading sites...', style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                      ),
                    ]
                  : _sites.map<DropdownMenuItem<String>>((site) {
                      return DropdownMenuItem<String>(
                        value: site['site'] as String?,
                        child: Text(
                          site['site'] ?? '',
                          style: TextStyle(color: cs.onSurface),
                        ),
                      );
                    }).toList(),
              onChanged: _onSiteSelected,
            ),

            if (_selectedSite != null) const SizedBox(height: 12),

            if (_selectedSite != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Date: $_currentDate',
                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection() {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GlassCard(
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
                      color: cs.primary,
                    ),
                  ),
                  if (_workers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_attendanceStatus.values.where((status) => status.isNotEmpty).length}/${_workers.length} marked',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoadingWorkers)
                Center(child: CircularProgressIndicator(color: cs.primary))
              else if (_workers.isEmpty)
                Center(
                  child: Text(
                    'No workers found for this site',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          cs.primary.withOpacity(0.1),
                        ),
                        dataRowColor: WidgetStateProperty.all(Colors.transparent),
                        columns: [
                          DataColumn(label: Text('No.', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Worker Name', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Designation', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Attendance Status', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
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
                              DataCell(Text('${index + 1}', style: TextStyle(color: cs.onSurface))),
                              DataCell(
                                Text(
                                  workerName,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                                ),
                              ),
                              DataCell(Text(worker['workerDesignation'] ?? '', style: TextStyle(color: cs.onSurface))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
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
                                    const SizedBox(width: 4),
                                    _buildAttendanceButton(
                                      'Absent',
                                      workerName,
                                      currentStatus,
                                    ),
                                    const SizedBox(width: 4),
                                    _buildAttendanceButton(
                                      'Overtime',
                                      workerName,
                                      currentStatus,
                                    ),
                                    const SizedBox(width: 4),
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
    final cs = Theme.of(context).colorScheme;
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
          backgroundColor: allMarked ? Colors.green : cs.onSurface.withOpacity(0.3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Submitting...'),
                ],
              )
            : Text(
                allMarked
                    ? 'Submit Attendance for $_currentDate'
                    : 'Mark All Attendance to Submit ($markedCount/${_workers.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
