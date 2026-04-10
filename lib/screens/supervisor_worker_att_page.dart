import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/list_extensions.dart';

class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  _AttendanceManagementPageState createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
  // Selected values
  String? _selectedSiteId;
  String? _selectedSiteName;
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
      final querySnapshot = await FirestoreService.getCollection(
        'workerSiteMap',
      ).get();
      if (!mounted) return;
      setState(() {
        _sites = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'site': data['site'] ?? 'Unnamed Site',
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

  Future<void> _loadWorkersForSite(String siteId, String siteName) async {
    setState(() {
      _isLoadingWorkers = true;
      _workers = [];
      _attendanceStatus.clear();
    });

    try {
      final doc = await FirestoreService.getCollection(
        'workerSiteMap',
      ).doc(siteId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final workersList = List<Map<String, dynamic>>.from(
          data['workers'] ?? [],
        );

        // Load existing attendance for today if any
        await _loadExistingAttendance(siteName);

        if (!mounted) return;
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
      if (!mounted) return;
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
      final doc = await FirestoreService.getCollection(
        'workersAttendance',
      ).doc(docId).get();

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

  void _onSiteSelected(String? siteId) {
    String? siteName;
    if (siteId != null) {
      final site = _sites.firstWhere(
        (s) => s['id'] == siteId,
        orElse: () => {},
      );
      siteName = site['site'];
    }

    setState(() {
      _selectedSiteId = siteId;
      _selectedSiteName = siteName;
      _workers.clear();
      _attendanceStatus.clear();
    });

    if (siteId != null && siteName != null) {
      _loadWorkersForSite(siteId, siteName);
    }
  }

  void _setAttendance(String workerName, String status) {
    setState(() {
      _attendanceStatus[workerName] = status;
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedSiteId == null ||
        _selectedSiteName == null ||
        _workers.isEmpty) {
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

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final String month = _currentMonth;
      final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final batch = FirebaseFirestore.instance.batch();

      for (final worker in _workers) {
        final workerName = worker['workerName']?.toString() ?? '';
        final attendanceStatus = _attendanceStatus[workerName] ?? '';
        if (attendanceStatus.isEmpty) continue;

        // Ensure we utilize workerId if available, fallback to a name-site combination
        final String workerId =
            worker['workerId']?.toString() ??
            '${workerName}_${_selectedSiteName}';
        final String workerDocId = '${workerId}_$month';
        final docRef = FirestoreService.getCollection(
          'WorkerMonthlyAttendance',
        ).doc(workerDocId);

        // Daily attendance data as per requirements
        final Map<String, dynamic> todayAttendance = {
          'status': attendanceStatus.toLowerCase(),
          'markedAt': FieldValue.serverTimestamp(),
          'salaryPerDay':
              double.tryParse(worker['workerSalary']?.toString() ?? '0') ?? 0,
        };

        // Update the monthly document with a nested map key update
        batch.set(docRef, {
          'workerId': workerId,
          'workerName': workerName,
          'designation': worker['workerDesignation'] ?? '',
          'site': _selectedSiteName,
          'month': month,
          'baseSalary': worker['workerSalary'] ?? '0',
          'status': 'draft',
          'attendanceData': {todayDate: todayAttendance},
        }, SetOptions(merge: true));
      }

      // Legacy daily log (optional, kept for audit trail)
      final dailyDocId =
          '${_selectedSiteName!}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}';
      final Map<String, dynamic> workersDataLog = {};
      for (final worker in _workers) {
        final name = worker['workerName']?.toString() ?? '';
        workersDataLog[name] = {
          'designation': worker['workerDesignation'] ?? '',
          'salary': worker['workerSalary'] ?? '',
          'attendance': _attendanceStatus[name] ?? '',
        };
      }

      batch.set(
        FirestoreService.getCollection('workersAttendance').doc(dailyDocId),
        {
          'Day': _currentDate,
          'updatedAt': FieldValue.serverTimestamp(),
          'month': month,
          'site': _selectedSiteName,
          'workers': workersDataLog,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Recalculate monthly totals for summaries
      await _recalculateMonthlySalaries();

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e')),
      );
    }
  }

  Future<void> _recalculateMonthlySalaries() async {
    try {
      final String month = _currentMonth;
      final querySnapshot =
          await FirestoreService.getCollection('WorkerMonthlyAttendance')
              .where('month', isEqualTo: month)
              .where('site', isEqualTo: _selectedSiteName)
              .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic> attendanceMap =
            data['attendanceData'] as Map<String, dynamic>? ?? {};

        double totalSalary = 0.0;
        int presentDays = 0;

        attendanceMap.forEach((date, details) {
          if (details is Map) {
            final String status =
                details['status']?.toString().toLowerCase() ?? '';
            final double salaryPerDay =
                double.tryParse(details['salaryPerDay']?.toString() ?? '0') ??
                0.0;

            if (status == 'present' || status == 'overtime') {
              totalSalary += salaryPerDay;
              presentDays += 1;
            } else if (status == 'half day') {
              totalSalary += (salaryPerDay / 2.0);
              presentDays += 1; // Or increment by 0.5 depending on policy
            }
          }
        });

        batch.update(doc.reference, {
          'calculatedSalary': totalSalary,
          'totalPresentDays': presentDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error in salary recalculation: $e');
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
            if (_selectedSiteId != null) _buildAttendanceSection(),

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
              value: _selectedSiteId,
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
                        child: Text(
                          'Loading sites...',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ]
                  : _sites.map<DropdownMenuItem<String>>((site) {
                      return DropdownMenuItem<String>(
                        value: site['id'] as String?,
                        child: Text(
                          site['site'] ?? 'Unnamed Site',
                          style: TextStyle(color: cs.onSurface),
                        ),
                      );
                    }).toList(),
              onChanged: _onSiteSelected,
            ),

            if (_selectedSiteId != null) const SizedBox(height: 12),

            if (_selectedSiteId != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Date: $_currentDate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
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
        mainAxisSize: MainAxisSize.max,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_workers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 48,
                          color: cs.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No workers found for this site',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _workers.length,
                    padding: const EdgeInsets.only(top: 8),
                    itemBuilder: (context, index) {
                      final worker = _workers[index];
                      final workerName = worker['workerName']?.toString() ?? '';
                      final designation =
                          worker['workerDesignation']?.toString() ?? '';
                      final currentStatus = _attendanceStatus[workerName] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary.withOpacity(0.1),
                                child: Text(
                                  (index + 1).toString(),
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                workerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                designation,
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                              trailing: currentStatus.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          currentStatus,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(
                                            currentStatus,
                                          ).withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        _getStatusText(currentStatus),
                                        style: TextStyle(
                                          color: _getStatusColor(currentStatus),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: _buildAttendanceButton(
                                      'Present',
                                      workerName,
                                      currentStatus,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _buildAttendanceButton(
                                      'Absent',
                                      workerName,
                                      currentStatus,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _buildAttendanceButton(
                                      'Overtime',
                                      workerName,
                                      currentStatus,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _buildAttendanceButton(
                                      'Half Day',
                                      workerName,
                                      currentStatus,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildAttendanceButton(
    String status,
    String workerName,
    String currentStatus,
  ) {
    final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
    final color = _getStatusColor(status);

    return InkWell(
      onTap: () => _setAttendance(workerName, status),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status,
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
          backgroundColor: allMarked
              ? Colors.green
              : cs.onSurface.withOpacity(0.3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
