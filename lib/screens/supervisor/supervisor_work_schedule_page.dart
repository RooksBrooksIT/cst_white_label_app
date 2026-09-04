import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SupervisorWorkSchedulePage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const SupervisorWorkSchedulePage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorWorkSchedulePage> createState() =>
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
      final mapColl = FirestoreService.getCollection('siteSupervisorMap');
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

      // 1. Query by Supervisor ID variants
      if (widget.supervisorId.isNotEmpty) {
        var snap = await mapColl.where('Supervisor ID', isEqualTo: widget.supervisorId).get();
        docs = snap.docs;
        if (docs.isEmpty) {
          snap = await mapColl.where('supervisorId', isEqualTo: widget.supervisorId).get();
          docs = snap.docs;
        }
        if (docs.isEmpty) {
          snap = await mapColl.where('supervisor', isEqualTo: widget.supervisorId).get();
          docs = snap.docs;
        }
      }

      // 2. Query by Supervisor Name variants
      if (docs.isEmpty && widget.supervisorName.isNotEmpty) {
        var snap = await mapColl.where('supervisor', isEqualTo: widget.supervisorName).get();
        docs = snap.docs;
        if (docs.isEmpty) {
          snap = await mapColl.where('supervisorName', isEqualTo: widget.supervisorName).get();
          docs = snap.docs;
        }
      }

      // 3. Fallback: load all siteSupervisorMap docs
      if (docs.isEmpty) {
        final snap = await mapColl.get();
        docs = snap.docs;
      }

      // 4. Fetch site details from master Site collection
      final sitesSnap = await FirestoreService.sites.get();
      final Map<String, String> siteNameMap = {
        for (var doc in sitesSnap.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };

      List<Map<String, dynamic>> tempSiteMaps = [];

      if (docs.isNotEmpty) {
        for (var d in docs) {
          final data = Map<String, dynamic>.from(d.data());
          final siteId = data['site']?.toString() ?? d.id;
          data['id'] = siteId;
          final siteName = siteNameMap[siteId] ?? '';
          data['displayName'] = siteName.isNotEmpty
              ? '${siteId}_$siteName'
              : siteId;
          tempSiteMaps.add(data);
        }
      } else if (sitesSnap.docs.isNotEmpty) {
        // Fallback: master sites list if mapping collection is empty
        for (var sDoc in sitesSnap.docs) {
          final sId = sDoc.id;
          final sName = sDoc.data()['siteName']?.toString() ?? 'Unnamed Site';
          tempSiteMaps.add({
            'id': sId,
            'site': sId,
            'displayName': '${sId}_$sName',
            'location': sDoc.data()['location']?.toString() ?? 'N/A',
            'projectStage': sDoc.data()['projectStage']?.toString() ?? 'N/A',
            'supervisor': widget.supervisorName,
          });
        }
      }

      if (tempSiteMaps.isNotEmpty) {
        _siteMaps = tempSiteMaps;
        _selectedSiteId = _siteMaps[0]['id']?.toString();
        _updateSiteDetails(_selectedSiteId);

        if (!mounted) return;
        setState(() {
          _isLoadingSupervisorSite = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoadingSupervisorSite = false;
          _supervisorSiteError = 'No active sites found in system.';
        });
      }
    } catch (e) {
      debugPrint('Error loading site assignment: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingSupervisorSite = false;
        _supervisorSiteError = 'Error loading site assignment: $e';
      });
    }
  }

  String? _parseStringOrTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is Timestamp) {
      return DateFormat('dd MMM yyyy').format(val.toDate());
    }
    return val.toString();
  }

  void _updateSiteDetails(String? siteId) {
    if (siteId == null) return;
    final site = _siteMaps.firstWhere(
      (s) => s['id'] == siteId,
      orElse: () => {},
    );
    setState(() {
      _siteLocation = _parseStringOrTimestamp(site['location']);
      _projectStage = _parseStringOrTimestamp(site['projectStage']);
      _joinedOn = _parseStringOrTimestamp(site['joinedOn']);
      _siteComments = _parseStringOrTimestamp(site['siteComments']);
      _supervisorName = _parseStringOrTimestamp(site['supervisor']);

      _locationController.text = _siteLocation ?? '';
      _supervisorController.text = _supervisorName ?? '';
      _projectNameController.text = _parseStringOrTimestamp(site['projectName']) ?? '';
      _projectPhaseController.text = _projectStage ?? '';
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
        return sum + (salary * (count));
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
        final querySnapshot = await FirestoreService
            .siteSupervisorProjectStageSchedule
            .orderBy('wsReqId', descending: true)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          final lastId = querySnapshot.docs.first['wsReqId']?.toString();
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

      // Helper to sanitize strings for the document ID (replace spaces with underscores)
      String sanitize(String input) => input.trim().replaceAll(' ', '_');

      final docId =
          '${sanitize(siteId)}_'
          '${sanitize(projectName)}_'
          '${sanitize(supervisorName)}_'
          '${sanitize(projectStage)}_'
          '$wsReqId';

      await FirestoreService.siteSupervisorProjectStageSchedule.doc(docId).set({
        'wsReqId': wsReqId,
        'siteId': siteId,
        'projectName': projectName,
        'projectStage': projectStage,
        'supervisorId': widget.supervisorId,
        'supervisorName': supervisorName,
        'approvalStatus': approvalStatus,
        'estimatedPayment': estimatedPayment,
        'reqDays': reqDays,
        'reqLabours': reqLabours,
        'startDate': _selectedStartDate != null
            ? Timestamp.fromDate(_selectedStartDate!)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify the manager and organisation about the new work schedule request
      await NotificationService.notifyManager(
        title: '📅 New Work Schedule Submitted',
        body: '$supervisorName (Site: $siteId) submitted Work Schedule #$wsReqId for $projectStage.',
        requestType: 'workforce',
        requestId: wsReqId,
        docId: docId,
        siteId: siteId,
        status: 'pending_manager_review',
        senderRole: 'Supervisor',
        senderName: supervisorName,
      );

      await NotificationService.notifyOrganisation(
        title: '📅 New Work Schedule Request',
        body: '$supervisorName (Site: $siteId) submitted $wsReqId for $projectStage.',
        requestType: 'workforce',
        requestId: wsReqId,
        docId: docId,
        siteId: siteId,
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Work Schedule',
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
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: _isLoadingSupervisorSite
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _supervisorSiteError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _supervisorSiteError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Supervisor Profile Header Banner
                        _buildSupervisorHeader(darkAccent, primaryColor),
                        const SizedBox(height: 16),

                        // Site & Details Card
                        _buildSiteDetailsCard(primaryColor),
                        const SizedBox(height: 16),

                        // Start Date Calendar Card
                        _buildCalendarCard(primaryColor, darkAccent),
                        const SizedBox(height: 16),

                        // Labour Allocation Card
                        _buildLabourCard(primaryColor, darkAccent),
                        const SizedBox(height: 24),

                        // Action Buttons
                        _buildActionButtons(primaryColor),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Supervisor Profile Header Banner
  Widget _buildSupervisorHeader(Color darkAccent, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            darkAccent,
            Color.alphaBlend(
              primaryColor.withValues(alpha: 0.4),
              darkAccent,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supervisorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Supervisor ID: ${widget.supervisorId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Site & Schedule Details Card
  Widget _buildSiteDetailsCard(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apartment_rounded,
                    color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Site & Schedule Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedSiteId,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Assigned Site',
              labelStyle:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
              prefixIcon: Icon(Icons.location_on_rounded,
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
            dropdownColor: Colors.white,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
            items: _siteMaps.map((site) {
              final siteId = site['id']?.toString() ?? '';
              final displayName =
                  site['displayName']?.toString() ?? siteId;
              return DropdownMenuItem(
                value: siteId,
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
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
          const SizedBox(height: 14),
          _buildTextField(
            _locationController,
            'Location',
            Icons.map_rounded,
            primaryColor,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            _supervisorController,
            'Supervisor Name',
            Icons.person_outline_rounded,
            primaryColor,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            _projectNameController,
            'Project Name',
            Icons.business_rounded,
            primaryColor,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            _projectPhaseController,
            'Project Stage',
            Icons.account_tree_rounded,
            primaryColor,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Number of Days',
              labelStyle:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
              prefixIcon: Icon(Icons.timelapse_rounded,
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
          ),
        ],
      ),
    );
  }

  /// Start Date Calendar Card
  Widget _buildCalendarCard(Color primaryColor, Color darkAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    color: darkAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select Start Date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_isLoadingAvailability)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(darkAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
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
                color: darkAccent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: darkAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF0F172A)),
              rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF0F172A)),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildDayWithAvailability(day, primaryColor, darkAccent);
              },
              outsideBuilder: (context, day, focusedDay) {
                return Opacity(
                  opacity: 0.35,
                  child: _buildDayWithAvailability(day, primaryColor, darkAccent),
                );
              },
            ),
          ),
          if (_selectedStartDate != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: darkAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: darkAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: darkAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Selected Start: ${DateFormat('dd MMM yyyy').format(_selectedStartDate!)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: darkAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'High'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFF59E0B), 'Limited'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFEF4444), 'Unavailable'),
            ],
          ),
        ],
      ),
    );
  }

  /// Labour Allocation Card
  Widget _buildLabourCard(Color primaryColor, Color darkAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.group_add_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Labour Allocation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_labours.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No labours found. Please configure labours in Master data.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedLabour,
              isExpanded: true,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Select Labour Role',
                labelStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700),
                prefixIcon:
                    Icon(Icons.badge_rounded, color: primaryColor, size: 18),
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
              dropdownColor: Colors.white,
              icon:
                  Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
              items: _labours.map((labour) {
                final designation = labour['designation'] ?? '';
                final labourId = labour['labourId'] ?? '';
                return DropdownMenuItem(
                  value: labour,
                  child: Row(
                    children: [
                      Text(
                        '${labour['name'] ?? ''} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (designation.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            designation,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (labourId.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($labourId)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedLabour = value);
              },
            ),
            const SizedBox(height: 14),
            if (_selectedLabour != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Designation',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedLabour!['designation'] ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Counter incrementer
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove,
                                size: 16, color: primaryColor),
                            onPressed: _selectedLabourCount > 1
                                ? () => setState(() => _selectedLabourCount--)
                                : null,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_selectedLabourCount',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add,
                                size: 16, color: primaryColor),
                            onPressed: () =>
                                setState(() => _selectedLabourCount++),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectedLabour == null
                      ? null
                      : () {
                          setState(() {
                            final labourToAdd =
                                Map<String, dynamic>.from(_selectedLabour!);
                            labourToAdd['count'] = _selectedLabourCount;
                            _addedLabours.add(labourToAdd);
                            _selectedLabourCount = 1;
                          });
                        },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Labour to List',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ],
          if (_addedLabours.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Added Labours:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_addedLabours.length} items',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columnSpacing: 24,
                horizontalMargin: 16,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF0F172A),
                ),
                columns: const [
                  DataColumn(label: Text('Designation')),
                  DataColumn(label: Text('Count')),
                ],
                rows: _addedLabours.map((labour) {
                  final count = labour['count'] ?? 1;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(labour['designation'] ?? ''),
                      ),
                      DataCell(
                        Text(count.toString()),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Action Buttons (Reset & Send for Approval)
  Widget _buildActionButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _resetForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForApproval,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 3,
              shadowColor: primaryColor.withValues(alpha: 0.35),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Send for Approval',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDayWithAvailability(
    DateTime day,
    Color primaryColor,
    Color darkAccent,
  ) {
    if (day.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return Center(
        child: Text(
          '${day.day}',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
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
      if (busyCount > 0) dotColor = Colors.grey.withValues(alpha: 0.5);
    } else if (availabilityScore >= 1.0) {
      highlightColor = const Color(0xFF10B981).withValues(alpha: 0.12);
      dotColor = const Color(0xFF10B981);
    } else if (availabilityScore > 0.0) {
      highlightColor = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      dotColor = const Color(0xFFF59E0B);
    } else {
      highlightColor = const Color(0xFFEF4444).withValues(alpha: 0.12);
      dotColor = const Color(0xFFEF4444);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? darkAccent : highlightColor,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: darkAccent, width: 2)
                  : isSelected
                  ? Border.all(color: Colors.white24, width: 1)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: darkAccent.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isToday ? darkAccent : const Color(0xFF0F172A)),
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13.5,
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
                    color: isSelected ? darkAccent : dotColor,
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
    Color primaryColor,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        prefixIcon: Icon(icon, color: primaryColor, size: 18),
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
    );
  }
}
