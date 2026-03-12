import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorWorkSchedulePage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const SupervisorWorkSchedulePage(
      {super.key, required this.supervisorId, required this.supervisorName});

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

  static const Color mainColor = Color(0xFF0b3470);

  @override
  void initState() {
    super.initState();
    _fetchSitesForSupervisor();
    _fetchProjectPhases();
    _fetchLabours();
  }

  Future<void> _fetchLabours() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('labours').get();
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
    final snapshot =
        await FirebaseFirestore.instance.collection('projectStages').get();
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> tempSiteMaps = [];
        for (var d in querySnapshot.docs) {
          final data = d.data();
          data['id'] = d['site'];
          final siteDoc = await FirebaseFirestore.instance
              .collection('sites')
              .doc(d['site'])
              .get();
          final siteName =
              siteDoc.exists ? (siteDoc.data()?['siteName'] ?? '') : '';
          data['displayName'] =
              siteName.isNotEmpty ? '${d['site']}_$siteName' : d['site'];
          tempSiteMaps.add(data);
        }
        _siteMaps = tempSiteMaps;

        _selectedSiteId = _siteMaps[0]['id'] as String?;
        _updateSiteDetails(_selectedSiteId);

        setState(() {
          _isLoadingSupervisorSite = false;
        });
      } else {
        setState(() {
          _isLoadingSupervisorSite = false;
          _supervisorSiteError =
              'No site assignment found for this supervisor.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingSupervisorSite = false;
        _supervisorSiteError = 'Error loading site assignment: $e';
      });
    }
  }

  void _updateSiteDetails(String? siteId) {
    if (siteId == null) return;
    final site =
        _siteMaps.firstWhere((s) => s['id'] == siteId, orElse: () => {});
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
        int.tryParse(_daysController.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields and enter number of days.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _numberOfDays = int.tryParse(_daysController.text.trim());

    setState(() {
      _isSubmitting = true;
    });

    try {
      final grandTotal = _addedLabours.fold<int>(
        0,
        (sum, labour) {
          final countRaw = labour['count'];
          final count = (countRaw is int)
              ? countRaw
              : int.tryParse(countRaw?.toString() ?? '1') ?? 1;
          final salaryRaw = labour['salary'];
          final salary = (salaryRaw is int)
              ? salaryRaw
              : int.tryParse(salaryRaw?.toString() ?? '0') ?? 0;
          return sum + (salary * count);
        },
      );
      final numberOfDays = _numberOfDays ?? 1;
      final grandTotalWithDays = grandTotal * numberOfDays;
      final estimatedPayment = grandTotalWithDays;

      final List<Map<String, dynamic>> reqLabours = _addedLabours.map((labour) {
        return {
          'labourDesignation': labour['designation'] ?? '',
          'labourCount': (labour['count'] is int)
              ? labour['count']
              : int.tryParse(labour['count']?.toString() ?? '1') ?? 1,
        };
      }).toList();

      String wsReqId = 'WSR001';
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorProjectStageSchedule')
            .orderBy('wsReqId', descending: true)
            .limit(1)
            .get();
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

      await FirebaseFirestore.instance
          .collection('siteSupervisorProjectStageSchedule')
          .doc(docId)
          .set({
        'wsReqId': wsReqId,
        'siteId': siteId,
        'projectName': projectName,
        'projectStage': projectStage,
        'supervisorName': supervisorName,
        'approvalStatus': approvalStatus,
        'estimatedPayment': estimatedPayment,
        'reqDays': reqDays,
        'reqLabours': reqLabours,
      });

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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _submitForApproval() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit for Approval', style: TextStyle(color: mainColor)),
        content:
            Text('Are you sure you want to submit this schedule for approval?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Work Schedule', style: TextStyle(color: Colors.white)),
        backgroundColor: mainColor,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoadingSupervisorSite
          ? Center(child: CircularProgressIndicator(color: mainColor))
          : _supervisorSiteError != null
              ? Center(
                  child: Text(_supervisorSiteError!,
                      style: TextStyle(color: Colors.red, fontSize: 16)),
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
                            color: Color(0xFFE6E7F8),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 24.0, horizontal: 20.0),
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
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
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
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  prefixIcon:
                                      Icon(Icons.location_on_outlined, color: mainColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
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
                                      style: TextStyle(color: Colors.black),
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
                              Text('Project Stage: ${_projectStage ?? "-"}',
                                  style: TextStyle(fontSize: 16)),
                              Text('Location: ${_siteLocation ?? "-"}',
                                  style: TextStyle(fontSize: 16)),
                              SizedBox(height: 20),
                              _buildTextField(_locationController, 'Location',
                                  Icons.map_outlined),
                              SizedBox(height: 20),
                              _buildTextField(_supervisorController, 'Supervisor',
                                  Icons.person_outline),
                              SizedBox(height: 20),
                              _buildTextField(_projectNameController, 'Project Name',
                                  Icons.work_outline),
                              SizedBox(height: 20),
                              _buildTextField(_projectPhaseController, 'Project Stage',
                                  Icons.work_outline),
                              SizedBox(height: 20),
                              TextField(
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Number of Days',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  prefixIcon:
                                      Icon(Icons.calendar_today, color: mainColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        color: Color(0xFFF4F7FF),
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
                                  vertical: 16, horizontal: 20),
                              child: Row(
                                children: [
                                  Icon(Icons.group_add,
                                      color: Colors.white, size: 26),
                                  SizedBox(width: 10),
                                  Text('Add Labour',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      )),
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
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                            SizedBox(height: 10),
                                          ],
                                        )
                                      : DropdownButtonFormField<
                                          Map<String, dynamic>>(
                                          value: _selectedLabour,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'Select Labour',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide:
                                                  BorderSide(color: mainColor),
                                            ),
                                            prefixIcon:
                                                Icon(Icons.person, color: mainColor),
                                            filled: true,
                                            fillColor: Colors.white,
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
                                                  Icon(Icons.badge,
                                                      color: mainColor, size: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '${labour['name'] ?? ''} ',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black),
                                                  ),
                                                  if (designation.isNotEmpty)
                                                    ...[
                                                      SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Color(0xFFE0E5F8),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                        ),
                                                        child: Text(
                                                            designation,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: mainColor)),
                                                      ),
                                                    ],
                                                  if (labourId.isNotEmpty)
                                                    ...[
                                                      SizedBox(width: 8),
                                                      Text('($labourId)',
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey[700])),
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
                                      color: Color(0xFFF9F9FF),
                                      child: Padding(
                                        padding: EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.assignment_ind,
                                                    color: mainColor),
                                                SizedBox(width: 8),
                                                Text('Designation:',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                SizedBox(width: 8),
                                                Text(
                                                    _selectedLabour![
                                                            'designation'] ??
                                                        '-',
                                                    style: TextStyle(
                                                        fontSize: 16)),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(Icons.confirmation_num,
                                                    color: mainColor),
                                                SizedBox(width: 8),
                                                Text('Count:',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(
                                                        color: mainColor),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(Icons.remove,
                                                            size: 18),
                                                        onPressed:
                                                            _selectedLabourCount >
                                                                    1
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
                                                                horizontal: 8.0),
                                                        child: Text(
                                                            '$_selectedLabourCount',
                                                            style: TextStyle(
                                                                fontSize: 16)),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.add,
                                                            size: 18),
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
                                                          _selectedLabour!);
                                                  labourToAdd['count'] =
                                                      _selectedLabourCount;
                                                  _addedLabours.add(labourToAdd);
                                                  _selectedLabourCount = 1;
                                                });
                                              },
                                        icon: Icon(Icons.add, color: Colors.white),
                                        label: Text('Add Labours',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: mainColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 30),
                                  if (_addedLabours.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Added Labours:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              DataTable(
                                                columns: [
                                                  DataColumn(
                                                      label:
                                                          Text('Designation')),
                                                  DataColumn(label: Text('Count')),
                                                ],
                                                rows:
                                                    _addedLabours.map((labour) {
                                                  final count =
                                                      labour['count'] ?? 1;
                                                  return DataRow(cells: [
                                                    DataCell(Text(
                                                        labour['designation'] ??
                                                            '')),
                                                    DataCell(
                                                        Text(count.toString())),
                                                  ]);
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
                              backgroundColor: Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 15),
                            ),
                            child: Text('Reset',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed:
                                _isSubmitting ? null : _submitForApproval,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 15),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Send for Approval',
                                    style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        prefixIcon: Icon(icon, color: mainColor),
        filled: true,
        fillColor: Colors.grey[50],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: mainColor, width: 1.5),
        ),
      ),
    );
  }
}
