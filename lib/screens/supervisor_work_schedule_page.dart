import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';

class SupervisorWorkSchedulePage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const SupervisorWorkSchedulePage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _SupervisorWorkSchedulePageState createState() =>
      _SupervisorWorkSchedulePageState();
}

class _SupervisorWorkSchedulePageState
    extends State<SupervisorWorkSchedulePage> {
  // Site dropdown data
  List<Map<String, dynamic>> _siteMaps = [];
  String? _selectedSiteId;

  // SiteSupervisorMap fields
  String? _siteLocation;
  String? _projectStage;
  String? _joinedOn;
  String? _siteComments;
  String? _supervisorName;

  // Loading state for supervisor site fetch
  bool _isLoadingSupervisorSite = true;
  String? _supervisorSiteError;

  // Controllers for text fields
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectPhaseController = TextEditingController();

  // Number of days field
  int? _numberOfDays;
  final TextEditingController _daysController = TextEditingController();

  // Labours dropdown and table state
  List<Map<String, dynamic>> _labours = [];
  Map<String, dynamic>? _selectedLabour;
  final List<Map<String, dynamic>> _addedLabours = [];
  int _selectedLabourCount = 1;

  // Calendar and Availability state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedStartDate;
  Map<String, List<String>> _busyWorkersByDate = {}; // dateStr -> [workerIds]
  bool _isLoadingAvailability = false;

  Color get mainColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchSitesForSupervisor();
    _fetchProjectPhases();
    _fetchLabours();
    _fetchAvailabilityForMonth(_focusedDay);
  }

  Future<void> _fetchAvailabilityForMonth(DateTime monthDate) async {
    setState(() => _isLoadingAvailability = true);
    final monthStr = DateFormat('MM-yyyy').format(monthDate);

    try {
      final snapshot = await FirestoreService.getCollection(
        'workersAttendance',
      ).where('month', isEqualTo: monthStr).get();

      Map<String, List<String>> newBusyMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final workersMap = data['workers'] as Map<String, dynamic>? ?? {};

        String? formattedDate;

        // Priority 1: Use 'day' and 'month' fields (e.g., day: "31", month: "03-2026")
        final dayField = data['day']?.toString();
        final monthField = data['month']?.toString();

        if (dayField != null && monthField != null) {
          final monthParts = monthField.split('-');
          if (monthParts.length == 2) {
            formattedDate =
                '${monthParts[1]}-${monthParts[0]}-${dayField.padLeft(2, '0')}';
          }
        }

        // Priority 2: Use legacy 'Day' field (dd/MM/yyyy)
        if (formattedDate == null) {
          final legacyDay = data['Day']?.toString() ?? data['day']?.toString();
          if (legacyDay != null && legacyDay.contains('/')) {
            final parts = legacyDay.split('/');
            if (parts.length == 3) {
              formattedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
            }
          }
        }

        if (formattedDate == null) continue;

        workersMap.forEach((workerIdOrName, details) {
          if (details is Map) {
            final status =
                details['attendance']?.toString().toLowerCase() ?? '';
            if (status == 'present' ||
                status == 'overtime' ||
                status == 'half day') {
              newBusyMap
                  .putIfAbsent(formattedDate!, () => [])
                  .add(workerIdOrName);
            }
          }
        });
      }

      if (!mounted) return;
      setState(() {
        _busyWorkersByDate = newBusyMap;
        _isLoadingAvailability = false;
      });
    } catch (e) {
      debugPrint('Error fetching availability: $e');
      if (mounted) setState(() => _isLoadingAvailability = false);
    }
  }


  Future<void> _fetchLabours() async {
    final snapshot = await FirestoreService.getCollection('labours').get();
    if (!mounted) return;
    setState(() {
      _labours = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Project phases from Firestore
  List<String> _projectPhases = [];
  String? _selectedProjectPhase;
  bool _loadingPhases = true;

  bool _isSubmitting = false;

  Future<void> _fetchProjectPhases() async {
    setState(() {
      _loadingPhases = true;
    });
    final snapshot = await FirestoreService.getCollection(
      'projectStages',
    ).get();
    final phases = snapshot.docs
        .map((doc) => doc['projectStage']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    print('Loaded project phases from Firestore: $phases');
    String? newSelectedPhase = _selectedProjectPhase;
    if (newSelectedPhase == null || !phases.contains(newSelectedPhase)) {
      newSelectedPhase = null;
    }
    if (!mounted) return;
    setState(() {
      _projectPhases = phases;
      _selectedProjectPhase = newSelectedPhase;
      _loadingPhases = false;
    });
  }

  Future<void> _fetchSitesForSupervisor() async {
    setState(() {
      _isLoadingSupervisorSite = true;
      _supervisorSiteError = null;
    });
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('Supervisor ID', isEqualTo: widget.supervisorId).get();

      if (querySnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> tempSiteMaps = [];
        for (var d in querySnapshot.docs) {
          final data = d.data();
          data['id'] = d['site'];
          final siteDoc = await FirestoreService.getCollection(
            'sites',
          ).doc(d['site']).get();
          final siteName = siteDoc.exists
              ? (siteDoc.data()?['siteName'] ?? '')
              : '';
          data['displayName'] = siteName.isNotEmpty
              ? '${d['site']}_$siteName'
              : d['site'];
          tempSiteMaps.add(data);
        }
        _siteMaps = tempSiteMaps;

        _selectedSiteId = _siteMaps[0]['id'] as String?;
        _updateSiteDetails(_selectedSiteId);

        if (!mounted) return;
        setState(() {
          _isLoadingSupervisorSite = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoadingSupervisorSite = false;
          _supervisorSiteError =
              'No site assignment found for this supervisor.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupervisorSite = false;
        _supervisorSiteError = 'Error loading site assignment: $e';
      });
    }
  }

  void _updateSiteDetails(String? siteId) {
    if (siteId == null) return;
    final site = _siteMaps.firstWhere(
      (s) => s['id'] == siteId,
      orElse: () => {},
    );
    setState(() {
      _siteLocation = site['location'] as String?;
      _projectStage = site['projectStage'] as String?;
      _joinedOn = site['joinedOn'] as String?;
      _siteComments = site['siteComments'] as String?;
      _supervisorName = site['supervisor'] as String?;

      _locationController.text = _siteLocation ?? '';
      _supervisorController.text = _supervisorName ?? '';
      _projectNameController.text = site['projectName'] ?? '';
      _projectPhaseController.text = site['projectStage'] ?? '';
      _selectedProjectPhase =
          (_projectStage != null && _projectPhases.contains(_projectStage))
          ? _projectStage
          : null;
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _supervisorController.dispose();
    _projectNameController.dispose();
    _projectPhaseController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      if (_siteMaps.isNotEmpty) {
        _selectedSiteId = _siteMaps[0]['id'];
        _updateSiteDetails(_selectedSiteId);
      } else {
        _selectedSiteId = null;
        _locationController.clear();
        _supervisorController.clear();
        _projectNameController.clear();
        _projectPhaseController.clear();
      }
      _numberOfDays = null;
      _daysController.clear();
      _selectedLabour = null;
      _selectedLabourCount = 1;
      _addedLabours.clear();
      _selectedProjectPhase = null;
    });
  }

  Future<void> _saveScheduleToFirestore() async {
    if (_selectedSiteId == null ||
        _locationController.text.trim().isEmpty ||
        _supervisorController.text.trim().isEmpty ||
        _projectNameController.text.trim().isEmpty ||
        _projectPhaseController.text.trim().isEmpty ||
        _selectedStartDate == null ||
        int.tryParse(_daysController.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a Start Date and fill all fields.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    _numberOfDays = int.tryParse(_daysController.text.trim());

    setState(() {
      _isSubmitting = true;
    });

    try {
      final grandTotal = _addedLabours.fold<int>(0, (sum, labour) {
        final countRaw = labour['count'];
        final count = (countRaw is int)
            ? countRaw
            : int.tryParse(countRaw?.toString() ?? '1') ?? 1;
        final salaryRaw = labour['salary'];
        final salary = (salaryRaw is int)
            ? salaryRaw
            : int.tryParse(salaryRaw?.toString() ?? '0') ?? 0;
        return sum + (salary * (count as int));
      });
      final numberOfDays = _numberOfDays ?? 1;
      final grandTotalWithDays = grandTotal * numberOfDays;
      final estimatedPayment = grandTotalWithDays;

      final List<Map<String, dynamic>> reqLabours = _addedLabours.map((labour) {
        return {
          'labourDesignation': labour['designation'] ?? '',
          'labourCount': (labour['count'] is int)
              ? labour['count'] as int
              : int.tryParse(labour['count']?.toString() ?? '1') ?? 1,
        };
      }).toList();

      String wsReqId = 'WSR001';
      try {
        final querySnapshot = await FirestoreService.getCollection(
          'siteSupervisorProjectStageSchedule',
        ).orderBy('wsReqId', descending: true).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
          final lastId = querySnapshot.docs.first['wsReqId'] as String?;
          if (lastId != null && lastId.startsWith('WSR')) {
            final numPart = int.tryParse(lastId.substring(3)) ?? 0;
            wsReqId = 'WSR${(numPart + 1).toString().padLeft(3, '0')}';
          }
        }
      } catch (e) {
        wsReqId = 'WSR001';
      }
      final siteId = _selectedSiteId ?? '';
      final projectName = _projectNameController.text.trim();
      final projectStage = _projectPhaseController.text.trim();
      final supervisorName = _supervisorController.text.trim();
      final approvalStatus = 'Pending';
      final reqDays = _numberOfDays ?? 0;

      final docId = '${siteId}_${supervisorName}_$projectStage';

      await FirestoreService.getCollection(
        'siteSupervisorProjectStageSchedule',
      ).doc(docId).set({
        'wsReqId': wsReqId,
        'siteId': siteId,
        'projectName': projectName,
        'projectStage': projectStage,
        'supervisorName': supervisorName,
        'approvalStatus': approvalStatus,
        'estimatedPayment': estimatedPayment,
        'reqDays': reqDays,
        'reqLabours': reqLabours,
        'startDate': _selectedStartDate != null
            ? Timestamp.fromDate(_selectedStartDate!)
            : null,
      });

      // Notify the organisation about the new work schedule request
      await NotificationService.notifyOrganisation(
        title: '📅 New Work Schedule Request',
        body: '$supervisorName (Site: $siteId) submitted $wsReqId for $projectStage.',
        data: {
          'type': 'work_schedule',
          'wsReqId': wsReqId,
          'siteId': siteId,
          'supervisorName': supervisorName,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule saved and submitted for approval!'),
          backgroundColor: mainColor,
        ),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedule: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _submitForApproval() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit for Approval', style: TextStyle(color: mainColor)),
        content: Text(
          'Are you sure you want to submit this schedule for approval?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveScheduleToFirestore();
            },
            child: Text('Submit', style: TextStyle(color: mainColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Work Schedule',
      onBack: () => Navigator.pop(context),
      body: _isLoadingSupervisorSite
          ? Center(child: CircularProgressIndicator(color: mainColor))
          : _supervisorSiteError != null
          ? Center(
              child: Text(
                _supervisorSiteError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 24.0,
                            horizontal: 20.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, color: mainColor, size: 36),
                              SizedBox(height: 10),
                              Text(
                                widget.supervisorName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: mainColor,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'ID: ${widget.supervisorId}',
                                style: TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedSiteId,
                            decoration: InputDecoration(
                              labelText: 'Site ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                              ),
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                color: mainColor,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                            ),
                            items: _siteMaps.map((site) {
                              final siteId = site['id']?.toString() ?? '';
                              final displayName =
                                  site['displayName']?.toString() ?? siteId;
                              return DropdownMenuItem(
                                value: siteId,
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSiteId = value;
                                _updateSiteDetails(value);
                              });
                            },
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Project Stage: ${_projectStage ?? "-"}',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Location: ${_siteLocation ?? "-"}',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            _locationController,
                            'Location',
                            Icons.map_outlined,
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            _supervisorController,
                            'Supervisor',
                            Icons.person_outline,
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            _projectNameController,
                            'Project Name',
                            Icons.work_outline,
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            _projectPhaseController,
                            'Project Stage',
                            Icons.work_outline,
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Number of Days',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                              ),
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: mainColor,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildCalendar(),
                  SizedBox(height: 20),
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: mainColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.group_add, size: 26),
                              SizedBox(width: 10),
                              Text(
                                'Add Labour',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _labours.isEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No labours found. Please add labours in Firestore.',
                                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                                        ),
                                        SizedBox(height: 10),
                                      ],
                                    )
                                  : DropdownButtonFormField<
                                      Map<String, dynamic>
                                    >(
                                      value: _selectedLabour,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Select Labour',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: mainColor,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: mainColor,
                                        ),
                                        filled: true,
                                      ),
                                      items: _labours.map((labour) {
                                        final designation =
                                            labour['designation'] ?? '';
                                        final labourId =
                                            labour['labourId'] ?? '';
                                        return DropdownMenuItem(
                                          value: labour,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.badge,
                                                color: mainColor,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '${labour['name'] ?? ''} ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (designation.isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    designation,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: mainColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (labourId.isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Text(
                                                  '($labourId)',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLabour = value;
                                        });
                                      },
                                    ),
                              SizedBox(height: 20),
                              if (_selectedLabour != null) ...[
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  child: Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.assignment_ind,
                                              color: mainColor,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Designation:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              _selectedLabour!['designation'] ??
                                                  '-',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.confirmation_num,
                                              color: mainColor,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Count:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: mainColor,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.remove,
                                                      size: 18,
                                                    ),
                                                    onPressed:
                                                        _selectedLabourCount > 1
                                                        ? () {
                                                            setState(() {
                                                              _selectedLabourCount--;
                                                            });
                                                          }
                                                        : null,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      '$_selectedLabourCount',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.add,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedLabourCount++;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _selectedLabour == null
                                        ? null
                                        : () {
                                            setState(() {
                                              final labourToAdd =
                                                  Map<String, dynamic>.from(
                                                    _selectedLabour!,
                                                  );
                                              labourToAdd['count'] =
                                                  _selectedLabourCount;
                                              _addedLabours.add(labourToAdd);
                                              _selectedLabourCount = 1;
                                            });
                                          },
                                    icon: Icon(Icons.add),
                                    label: Text(
                                      'Add Labours',
                                      style: TextStyle(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: mainColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30),
                              if (_addedLabours.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Added Labours:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DataTable(
                                            columns: [
                                              DataColumn(
                                                label: Text('Designation'),
                                              ),
                                              DataColumn(label: Text('Count')),
                                            ],
                                            rows: _addedLabours.map((labour) {
                                              final count =
                                                  labour['count'] ?? 1;
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      labour['designation'] ??
                                                          '',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(count.toString()),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _resetForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 15,
                          ),
                        ),
                        child: Text('Reset', style: TextStyle()),
                      ),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForApproval,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 15,
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Send for Approval', style: TextStyle()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: mainColor),
                SizedBox(width: 8),
                Text(
                  'Select Start Date',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
                if (_isLoadingAvailability) ...[
                  SizedBox(width: 12),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: mainColor,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 10),
            TableCalendar(
              firstDay: DateTime.now().subtract(Duration(days: 30)),
              lastDay: DateTime.now().add(Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedStartDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedStartDate = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchAvailabilityForMonth(focusedDay);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: mainColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: mainColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _buildDayWithAvailability(day);
                },
                outsideBuilder: (context, day, focusedDay) {
                  return Opacity(
                    opacity: 0.5,
                    child: _buildDayWithAvailability(day),
                  );
                },
              ),
            ),
            if (_selectedStartDate != null) ...[
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Selected: ${DateFormat('dd MMM yyyy').format(_selectedStartDate!)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            SizedBox(height: 10),
            Row(
              children: [
                _buildLegendItem(Colors.green, 'High Availability'),
                SizedBox(width: 15),
                _buildLegendItem(Theme.of(context).colorScheme.secondary, 'Limited'),
                SizedBox(width: 15),
                _buildLegendItem(Theme.of(context).colorScheme.error, 'Unavailable'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildDayWithAvailability(DateTime day) {
    if (day.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return Center(
        child: Text('${day.day}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final isSelected = isSameDay(_selectedStartDate, day);
    final isToday = isSameDay(DateTime.now(), day);

    // Calculate availability percentage
    double availabilityScore = 1.0;
    int busyCount = 0;
    
    final busyWorkersOnDate = _busyWorkersByDate[dateStr] ?? [];
    busyCount = busyWorkersOnDate.length;

    if (_addedLabours.isNotEmpty) {
      int totalRequired = 0;
      int totalAvailableForAdded = 0;

      for (var labour in _addedLabours) {
        final designation = labour['designation'] ?? '';
        final count = (labour['count'] is int)
            ? labour['count'] as int
            : int.tryParse(labour['count']?.toString() ?? '1') ?? 1;
        totalRequired += count;

        // Count workers of this designation who are NOT busy
        final totalWorkersOfDesignation = _labours
            .where((l) => l['designation'] == designation)
            .length;

        final busyWorkersOfDesignation = _labours.where((l) {
          final isSameDesignation = l['designation'] == designation;
          final workerId =
              l['labourId']?.toString() ?? l['id']?.toString() ?? '';
          return isSameDesignation && busyWorkersOnDate.contains(workerId);
        }).length;

        totalAvailableForAdded +=
            (totalWorkersOfDesignation - busyWorkersOfDesignation);
      }

      if (totalRequired > 0) {
        availabilityScore = totalAvailableForAdded / totalRequired;
      }
    }

    Color highlightColor = Colors.transparent;
    Color dotColor = Colors.transparent;
    
    if (_addedLabours.isEmpty) {
      highlightColor = Colors.transparent;
      if (busyCount > 0) dotColor = Colors.grey.withOpacity(0.5);
    } else if (availabilityScore >= 1.0) {
      highlightColor = Colors.green.withOpacity(0.12);
      dotColor = Colors.green;
    } else if (availabilityScore > 0.0) {
      highlightColor = Theme.of(context).colorScheme.secondary.withOpacity(0.12);
      dotColor = Theme.of(context).colorScheme.secondary;
    } else {
      highlightColor = Theme.of(context).colorScheme.error.withOpacity(0.12);
      dotColor = Theme.of(context).colorScheme.error;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected ? mainColor : highlightColor,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: mainColor, width: 2)
                  : isSelected
                      ? Border.all(color: Colors.white24, width: 1)
                      : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: mainColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : (isToday ? mainColor : Theme.of(context).colorScheme.onSurface),
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          if (busyCount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                busyCount > 3 ? 3 : busyCount,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected ? mainColor : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        prefixIcon: Icon(icon, color: mainColor),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: mainColor, width: 1.5),
        ),
      ),
    );
  }
}
