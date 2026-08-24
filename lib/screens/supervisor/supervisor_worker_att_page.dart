import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class AttendanceManagementPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const AttendanceManagementPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
  // Selected values
  String? _selectedSiteId;
  String? _selectedSiteName;
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _workers = [];
  List<String> _assignedSiteNames = [];

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
    _fetchAssignedSitesAndLoad();
  }

  Future<void> _fetchAssignedSitesAndLoad() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSites = true;
      _sites = [];
    });

    try {
      if (!FirestoreService.isReady) {
        debugPrint('FirestoreService is not ready.');
        setState(() => _isLoadingSites = false);
        return;
      }

      // 1. Get assigned site IDs from siteSupervisorMap
      final mapCollection = FirestoreService.getCollection('siteSupervisorMap');

      // Query by ID
      final idSnapshot = await mapCollection
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      // Query by Name as fallback
      final nameSnapshot = await mapCollection
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();

      final Set<String> assignedSiteIds = {};
      for (var doc in idSnapshot.docs) {
        final siteId = doc.data()['site']?.toString();
        if (siteId != null && siteId.isNotEmpty) assignedSiteIds.add(siteId);
      }
      for (var doc in nameSnapshot.docs) {
        final siteId = doc.data()['site']?.toString();
        if (siteId != null && siteId.isNotEmpty) assignedSiteIds.add(siteId);
      }

      debugPrint('Assigned Site IDs for supervisor: $assignedSiteIds');

      // 2. Load worker sites
      final workerSiteMapColl = FirestoreService.getCollection('workerSiteMap');
      List<Map<String, dynamic>> finalSites = [];

      if (assignedSiteIds.isNotEmpty) {
        // Fetch only specific sites assigned to this supervisor
        // Using chunks of 30 due to Firestore 'whereIn' limits
        final idList = assignedSiteIds.toList();
        for (var i = 0; i < idList.length; i += 30) {
          final end = (i + 30 < idList.length) ? i + 30 : idList.length;
          final chunk = idList.sublist(i, end);

          final workerSnapshot = await workerSiteMapColl
              .where(FieldPath.documentId, whereIn: chunk)
              .get();

          for (var doc in workerSnapshot.docs) {
            final data = doc.data();
            finalSites.add({
              'id': doc.id,
              'site': data['site'] ?? doc.id,
              'supervisor': data['supervisor'] ?? '',
              'projectName': data['projectName'] ?? '',
              'totalWorkers': data['totalWorkers'] ?? 0,
            });
          }
        }
      }

      // 3. Fallback: If no sites found by mapping, try a general query
      // but only if finalSites is still empty (maybe mapping doc is missing but workerSiteMap has supervisor field)
      if (finalSites.isEmpty) {
        final searchName = widget.supervisorName.trim().toLowerCase();
        final searchId = widget.supervisorId.trim().toLowerCase();

        final allWorkerSites = await workerSiteMapColl.get();
        finalSites = allWorkerSites.docs
            .where((doc) {
              final data = doc.data();
              final docSupName =
                  (data['supervisor'] ?? data['supervisorName'] ?? '')
                      .toString()
                      .toLowerCase();
              final docSupId = (data['supervisorId'] ?? '')
                  .toString()
                  .toLowerCase();

              return (docSupId.isNotEmpty && docSupId == searchId) ||
                  (docSupName.isNotEmpty &&
                      (docSupName == searchName ||
                          docSupName.contains(searchName)));
            })
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'site': data['site'] ?? doc.id,
                'supervisor': data['supervisor'] ?? '',
                'projectName': data['projectName'] ?? '',
                'totalWorkers': data['totalWorkers'] ?? 0,
              };
            })
            .toList();
      }

      if (mounted) {
        setState(() {
          _sites = finalSites;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchAssignedSitesAndLoad: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sites. Please check connection.'),
          ),
        );
      }
    }
  }

  Future<void> _loadSites() async {
    // This method is now handled by _fetchAssignedSitesAndLoad
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
        if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            workersData.forEach((workerName, workerData) {
              // Ensure we check for 'attendance' field in the worker data map
              _attendanceStatus[workerName] =
                  workerData['attendance']?.toString() ?? '';
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
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
          'day': DateFormat('dd').format(DateTime.now()), // dd
          'month': DateFormat(
            'MM-yyyy',
          ).format(DateTime.now()), // MM-yyyy as per user spec
          'site': _selectedSiteName,
          'updatedAt': FieldValue.serverTimestamp(),
          'workers': workersDataLog,
          'Day':
              _currentDate, // Keep for backward compatibility if needed, but 'day' is primary now
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
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'overtime':
        return const Color(0xFF8B5CF6);
      case 'half day':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Attendance Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site Selection Card
                _buildSiteSelectionSection(primaryColor),

                const SizedBox(height: 16),

                // Workers Attendance Table / Section
                if (_selectedSiteId != null)
                  Expanded(child: _buildAttendanceSection(primaryColor, darkAccent))
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.apartment_rounded,
                              size: 48,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select a Site to Begin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Assigned to supervisor: ${widget.supervisorName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_workers.isNotEmpty) const SizedBox(height: 14),

                // Submit Button
                if (_workers.isNotEmpty) _buildSubmitButton(primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteSelectionSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSiteId,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Select Assigned Site *',
              labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              prefixIcon: Icon(Icons.construction_rounded,
                  color: primaryColor, size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 1.8),
              ),
            ),
            items: _isLoadingSites
                ? [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Loading sites...',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ]
                : _sites.map<DropdownMenuItem<String>>((site) {
                    return DropdownMenuItem<String>(
                      value: site['id'] as String?,
                      child: Text(
                        site['site'] ?? 'Unnamed Site',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    );
                  }).toList(),
            onChanged: _onSiteSelected,
          ),
          if (_selectedSiteId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 15, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Date: $_currentDate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Supervisor: ${widget.supervisorName}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(Color primaryColor, Color darkAccent) {
    final markedCount = _attendanceStatus.values
        .where((status) => status.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people_alt_rounded,
                        color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Workers (${_workers.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (_workers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: markedCount == _workers.length
                        ? const Color(0xFFECFDF5)
                        : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: markedCount == _workers.length
                          ? const Color(0xFF6EE7B7)
                          : primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '$markedCount/${_workers.length} marked',
                    style: TextStyle(
                      color: markedCount == _workers.length
                          ? const Color(0xFF059669)
                          : primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),

          if (_isLoadingWorkers)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            )
          else if (_workers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No workers found for this site',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
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
                padding: const EdgeInsets.only(top: 4),
                itemBuilder: (context, index) {
                  final worker = _workers[index];
                  final workerName = worker['workerName']?.toString() ?? '';
                  final designation =
                      worker['workerDesignation']?.toString() ?? '';
                  final currentStatus = _attendanceStatus[workerName] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor:
                                primaryColor.withValues(alpha: 0.12),
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            workerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            designation,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          trailing: currentStatus.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(currentStatus)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getStatusColor(currentStatus)
                                          .withValues(alpha: 0.3),
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
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    final markedCount = _attendanceStatus.values
        .where((status) => status.isNotEmpty)
        .length;
    final allMarked = markedCount == _workers.length;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: allMarked && !_isSubmitting ? _submitAttendance : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: allMarked ? 3 : 0,
          shadowColor: primaryColor.withValues(alpha: 0.35),
        ),
        child: _isSubmitting
            ? const Row(
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
                  Text('Submitting Attendance...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(allMarked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(
                    allMarked
                        ? 'Submit Attendance for $_currentDate'
                        : 'Mark All Workers to Submit ($markedCount/${_workers.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
