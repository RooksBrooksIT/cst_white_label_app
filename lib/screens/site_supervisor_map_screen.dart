import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SiteSupervisorMapScreen extends StatefulWidget {
  const SiteSupervisorMapScreen({super.key});

  @override
  _SiteSupervisorMapScreenState createState() =>
      _SiteSupervisorMapScreenState();
}

class _SiteSupervisorMapScreenState extends State<SiteSupervisorMapScreen> {
  bool isEntrySelected = true;

  String? selectedSite;
  String? selectedSupervisor;
  String? selectedSupervisorId;
  String? selectedProjectStage;
  String? projectName;
  DateTime? joinedDate;
  DateTime? startDate;
  DateTime? endDate;

  final locationController = TextEditingController();
  final commentsController = TextEditingController();

  List<String> siteList = [];
  List<String> supervisorList = [];
  List<String> supervisorIdList = [];
  List<String> projectStageList = [];

  final Color primaryColor = Color(0xFF0b3470);

  @override
  void initState() {
    super.initState();
    fetchSiteList();
    fetchSupervisorList();
    fetchProjectStageList();
  }

  void fetchSiteList() async {
    try {
      QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('Site')
          .get();
      if (!mounted) return;
      setState(() {
        siteList = siteSnapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (error) {
      print('Error fetching site list: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching site list')));
    }
  }

  void fetchSupervisorList() async {
    try {
      QuerySnapshot supervisorSnapshot = await FirebaseFirestore.instance
          .collection('supervisor')
          .get();
      if (!mounted) return;
      setState(() {
        supervisorList = supervisorSnapshot.docs
            .map((doc) => doc['UserName'] as String)
            .toList();
        supervisorIdList = supervisorSnapshot.docs
            .map((doc) => doc.id)
            .toList();
      });
    } catch (error) {
      print('Error fetching supervisor list: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching supervisor list')));
    }
  }

  void fetchProjectStageList() async {
    try {
      QuerySnapshot projectStageSnapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .get();
      if (!mounted) return;
      setState(() {
        projectStageList = projectStageSnapshot.docs
            .map((doc) => doc['projectStage'] as String)
            .toSet()
            .toList();
      });
    } catch (error) {
      print('Error fetching project stage list: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching project stage list')),
      );
    }
  }

  void fetchSiteData(String siteId) async {
    try {
      DocumentSnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('Site')
          .doc(siteId)
          .get();
      if (!mounted) return;
      if (siteSnapshot.exists) {
        final data = siteSnapshot.data() as Map<String, dynamic>? ?? {};

        setState(() {
          locationController.text = data.containsKey('location')
              ? (data['location'] ?? '')
              : '';
          joinedDate = data.containsKey('startDate')
              ? _parseDate(data['startDate'])
              : null;
          startDate = data.containsKey('startDate')
              ? _parseDate(data['startDate'])
              : null;
          endDate = data.containsKey('endDate')
              ? _parseDate(data['endDate'])
              : null;
          projectName = data.containsKey('siteName')
              ? (data['siteName'] ?? '')
              : '';
        });

        try {
          final projQuery = await FirebaseFirestore.instance
              .collection('projects')
              .where('siteId', isEqualTo: siteId)
              .limit(1)
              .get();

          if (!mounted) return;
          if (projQuery.docs.isNotEmpty) {
            final projectData =
                projQuery.docs.first.data();
            final stage = projectData['projectStage']?.toString();
            if (stage != null && stage.isNotEmpty) {
              setState(() {
                selectedProjectStage = stage;
                if (!projectStageList.contains(stage)) {
                  projectStageList = [...projectStageList, stage];
                }
              });
            }
          }
        } catch (_) {
          // Ignore errors for project stage autofill
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Site data not found')));
      }
    } catch (error) {
      print('Error fetching site data: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching site data')));
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void resetForm() {
    setState(() {
      selectedSite = null;
      selectedSupervisor = null;
      selectedProjectStage = null;
      selectedSupervisorId = null;
      projectName = null;
      locationController.clear();
      commentsController.clear();
      joinedDate = null;
      startDate = null;
      endDate = null;
    });
  }

  Future<String?> findDocIdBySiteId(String siteId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
        .get();
    for (var doc in querySnapshot.docs) {
      if (doc.id.startsWith(siteId)) {
        return doc.id;
      }
    }
    return null;
  }

  void saveForm() async {
    if (selectedSite == null ||
        selectedSupervisor == null ||
        selectedProjectStage == null ||
        locationController.text.isEmpty ||
        joinedDate == null ||
        startDate == null ||
        endDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    try {
      String siteId = selectedSite ?? '';
      String? docId = await findDocIdBySiteId(siteId);
      String sanitizedLocation = locationController.text
          .replaceAll('/', '_')
          .replaceAll(',', '')
          .replaceAll(' ', '_');
      String sanitizedSupervisor = (selectedSupervisor ?? '')
          .replaceAll('/', '_')
          .replaceAll(',', '')
          .replaceAll(' ', '_');
      String sanitizedSupervisorId = (selectedSupervisorId ?? '')
          .replaceAll('/', '_')
          .replaceAll(',', '')
          .replaceAll(' ', '_');
      docId ??=
          '${siteId}_${sanitizedLocation}_${sanitizedSupervisorId}_$sanitizedSupervisor';
      Map<String, dynamic> data = {
        "joinedOn": joinedDate!.toIso8601String(),
        "startDate": startDate!.toIso8601String(),
        "endDate": endDate!.toIso8601String(),
        "location": locationController.text,
        "projectStage": selectedProjectStage,
        "site": selectedSite,
        "projectName": projectName ?? '',
        "siteComments": commentsController.text,
        "supervisor": selectedSupervisor,
        "Supervisor ID": selectedSupervisorId,
      };
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .doc(docId);
      DocumentSnapshot docSnapshot = await docRef.get();
      if (!mounted) return;
      if (docSnapshot.exists) {
        await docRef.update(data);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Entry updated successfully!')));
      } else {
        await docRef.set(data);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Entry created successfully!')));
      }
      resetForm();
    } catch (e) {
      print('Error saving form: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving form.')));
    }
  }

  @override
  void dispose() {
    locationController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Site-Supervisor Mapping',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            
            letterSpacing: 0.7,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        toolbarHeight: 65,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth * 0.06; // 6%
          double verticalPadding = constraints.maxHeight * 0.025; // 2.5%
          double cardPadding = constraints.maxWidth < 500 ? 16 : 24;
          double fontSize = constraints.maxWidth < 350 ? 13 : 16;
          double titleFontSize = constraints.maxWidth < 400 ? 18 : 22;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildResponsiveButton('Entry', isEntrySelected, () {
                      setState(() => isEntrySelected = true);
                    }),
                    SizedBox(width: constraints.maxWidth * 0.04),
                    _buildResponsiveButton('Info', !isEntrySelected, () {
                      setState(() => isEntrySelected = false);
                    }),
                  ],
                ),
                SizedBox(height: verticalPadding),
                if (isEntrySelected)
                  _buildEntrySection(
                    context,
                    cardPadding,
                    fontSize,
                    titleFontSize,
                  )
                else
                  _buildInfoTableSection(context, fontSize),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? primaryColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : primaryColor,
        side: BorderSide(color: primaryColor, width: isSelected ? 2.5 : 1.5),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 30),
        textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        elevation: isSelected ? 6 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: isSelected ? primaryColor.withOpacity(0.4) : null,
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildEntrySection(
    BuildContext context,
    double cardPadding,
    double fontSize,
    double titleFontSize,
  ) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primaryColor, width: 1.8),
    );
    final filledBackground = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 9,
          shadowColor: primaryColor.withOpacity(0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              children: [
                Text(
                  'Mapping Details',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 28),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedSite,
                  hint: Text(
                    'Select Site',
                    style: TextStyle(color: primaryColor, fontSize: fontSize),
                  ),
                  items: siteList.map((site) {
                    return DropdownMenuItem(
                      value: site,
                      child: Text(
                        site,
                        style: TextStyle(fontSize: fontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSite = value;
                    });
                    if (value != null) {
                      fetchSiteData(value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Site',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  elevation: 4,
                ),
                SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    prefixIcon: Icon(
                      Icons.business_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  controller: TextEditingController(text: projectName ?? ''),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.place_outlined, color: primaryColor),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedSupervisorId,
                  hint: Text(
                    'Select Supervisor ID',
                    style: TextStyle(color: primaryColor, fontSize: fontSize),
                  ),
                  items: supervisorIdList.map((id) {
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        id,
                        style: TextStyle(fontSize: fontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSupervisorId = value;
                      int idx = supervisorIdList.indexOf(value ?? '');
                      selectedSupervisor =
                          (idx >= 0 && idx < supervisorList.length)
                          ? supervisorList[idx]
                          : null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Supervisor ID',
                    prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
                    border: inputBorder.copyWith(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  elevation: 4,
                ),
                SizedBox(height: 14),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  controller: TextEditingController(
                    text: selectedSupervisor ?? '',
                  ),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Project Stage',
                    prefixIcon: Icon(Icons.work_outline, color: primaryColor),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  controller: TextEditingController(
                    text: selectedProjectStage ?? '',
                  ),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: commentsController,
                  decoration: InputDecoration(
                    labelText: 'Site Comments',
                    prefixIcon: Icon(
                      Icons.comment_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  maxLines: 4,
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    hintText: 'Start Date',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  controller: TextEditingController(
                    text: startDate != null
                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                        : '',
                  ),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    hintText: 'End Date',
                    prefixIcon: Icon(Icons.calendar_month, color: primaryColor),
                    border: inputBorder,
                    filled: true,
                    fillColor: filledBackground,
                    labelStyle: TextStyle(color: primaryColor),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                  ),
                  controller: TextEditingController(
                    text: endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : '',
                  ),
                  style: TextStyle(fontSize: fontSize, ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _selectAnyDate(context, dateType: 'joined'),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Joined On',
                        hintText: 'Select Joined On Date',
                        prefixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: primaryColor,
                        ),
                        border: inputBorder,
                        filled: true,
                        fillColor: filledBackground,
                        labelStyle: TextStyle(color: primaryColor),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 18,
                        ),
                      ),
                      controller: TextEditingController(
                        text: joinedDate != null
                            ? DateFormat('yyyy-MM-dd').format(joinedDate!)
                            : '',
                      ),
                      style: TextStyle(
                        fontSize: fontSize,
                        
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 32),
        _buildActionButtons(context, fontSize),
      ],
    );
  }

  Widget _buildInfoTableSection(BuildContext context, double fontSize) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('Site').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                'Error loading site info.',
                style: TextStyle(color: primaryColor, fontSize: fontSize),
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                'No site information available.',
                style: TextStyle(color: primaryColor, fontSize: fontSize),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              primaryColor.withOpacity(0.12),
            ),
            headingTextStyle: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: fontSize + 1,
            ),
            dataTextStyle: TextStyle(fontSize: fontSize),
            columnSpacing: 30,
            dividerThickness: 1.7,
            columns: [
              DataColumn(label: Text('Site ID')),
              DataColumn(label: Text('Site Name')),
              DataColumn(label: Text('Start Date')),
              DataColumn(label: Text('End Date')),
            ],
            rows: docs.map((doc) {
              String siteId = doc.id;
              final data = doc.data() as Map<String, dynamic>? ?? {};
              String siteName = data.containsKey('siteName')
                  ? data['siteName'].toString()
                  : '-';

              DateTime? start = data.containsKey('startDate')
                  ? _parseDate(data['startDate'])
                  : null;
              DateTime? end = data.containsKey('endDate')
                  ? _parseDate(data['endDate'])
                  : null;
              String startDateStr = start != null
                  ? DateFormat('yyyy-MM-dd').format(start)
                  : '-';
              String endDateStr = end != null
                  ? DateFormat('yyyy-MM-dd').format(end)
                  : '-';
              return DataRow(
                cells: [
                  DataCell(Text(siteId)),
                  DataCell(Text(siteName)),
                  DataCell(Text(startDateStr)),
                  DataCell(Text(endDateStr)),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _selectAnyDate(BuildContext context, {required String dateType}) async {
    DateTime? initialDate;
    if (dateType == 'start') {
      initialDate = startDate ?? DateTime.now();
    } else if (dateType == 'end') {
      initialDate = endDate ?? DateTime.now();
    } else if (dateType == 'joined') {
      initialDate = joinedDate ?? DateTime.now();
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: primaryColor,
            ),
            dialogTheme: DialogThemeData(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (dateType == 'start') {
          startDate = picked;
        } else if (dateType == 'end') {
          endDate = picked;
        } else if (dateType == 'joined') {
          joinedDate = picked;
        }
      });
    }
  }

  Widget _buildActionButtons(BuildContext context, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: _buildActionButton(
            context,
            icon: Icons.save,
            label: 'Save',
            color: primaryColor,
            onPressed: () => _showSaveConfirmationDialog(context),
            fontSize: fontSize,
          ),
        ),
        SizedBox(width: 20),
        Flexible(
          child: _buildActionButton(
            context,
            icon: Icons.refresh,
            label: 'Reset',
            color: Colors.deepOrange,
            onPressed: resetForm,
            fontSize: fontSize,
          ),
        ),
        SizedBox(width: 20),
        Flexible(
          child: _buildActionButton(
            context,
            icon: Icons.cancel,
            label: 'Cancel',
            color: Colors.redAccent,
            onPressed: cancelAction,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required double fontSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: fontSize + 16),
            onPressed: onPressed,
            padding: EdgeInsets.all(14),
            constraints: BoxConstraints(),
            splashRadius: 26,
          ),
        ),
        SizedBox(height: 8),
        FittedBox(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize - 1,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  void cancelAction() {
    Navigator.of(context).pop();
  }

  void _showSaveConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Save',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          content: Text(
            'Your details will be saved. Do you want to continue?',
            style: TextStyle(fontSize: 16),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                saveForm();
              },
            ),
          ],
        );
      },
    );
  }
}
