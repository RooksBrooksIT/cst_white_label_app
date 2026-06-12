import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

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
  String? siteComments;
  DateTime? joinedDate;
  DateTime? startDate;
  DateTime? endDate;

  // Tracks which siteSupervisorMap doc ID corresponds to each site name
  // Key: site field value, Value: document ID
  Map<String, String> _siteToDocId = {};
  // Full document data cache keyed by doc ID
  Map<String, Map<String, dynamic>> _docCache = {};

  final locationController = TextEditingController();
  final commentsController = TextEditingController();

  List<String> siteList = [];
  // Supervisor data: list of {id, fullName} maps from Firestore 'supervisor' collection
  List<Map<String, String>> _supervisorList = [];

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorMapDocs();
    _fetchSupervisors();
  }

  /// Fetches all supervisors from the 'supervisor' collection to populate the Supervisor ID dropdown.
  void _fetchSupervisors() async {
    try {
      final snapshot = await FirestoreService.getCollection('supervisor').get();
      if (!mounted) return;
      final List<Map<String, String>> supervisors = [];
      final Set<String> seenIds = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final supId = (data['SupervisorId']?.toString() ?? doc.id).trim();
        final fullName = (data['FullName']?.toString() ?? '').trim();
        if (supId.isNotEmpty && !seenIds.contains(supId)) {
          seenIds.add(supId);
          supervisors.add({'id': supId, 'fullName': fullName});
        }
      }
      setState(() {
        _supervisorList = supervisors;
      });
    } catch (e) {
      debugPrint('Error fetching supervisors: $e');
    }
  }

  // Cache of Site collection document data keyed by doc ID
  Map<String, Map<String, dynamic>> _siteDocCache = {};

  /// Fetches all documents from siteSupervisorMap and populates the site dropdown.
  /// Path: /organisation/{OrgID}/siteSupervisorMap
  void _fetchSiteSupervisorMapDocs() async {
    try {
      // 1. Fetch all site docs from 'Site' and cache their data
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();
      final List<String> allSiteIds = [];
      final Map<String, Map<String, dynamic>> siteDocCache = {};
      for (final doc in sitesSnapshot.docs) {
        if (doc.id.isNotEmpty) {
          allSiteIds.add(doc.id);
          siteDocCache[doc.id] = doc.data();
        }
      }

      // 2. Fetch all mappings from 'siteSupervisorMap'
      final snapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).get();
      if (!mounted) return;

      final Map<String, String> siteToDocId = {};
      final Map<String, Map<String, dynamic>> docCache = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final site = data['site']?.toString();
        if (site != null && site.isNotEmpty) {
          siteToDocId[site] = doc.id;
          docCache[doc.id] = data;
        }
      }

      setState(() {
        _siteToDocId = siteToDocId;
        _docCache = docCache;
        _siteDocCache = siteDocCache;
        siteList = allSiteIds..sort();
      });
    } catch (error) {
      debugPrint('Error fetching siteSupervisorMap: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching site list')),
      );
    }
  }

  /// Retrieves the project name for a given site by querying the 'projects' collection.
  /// Tries multiple field names and query strategies to handle inconsistent data.
  Future<Map<String, dynamic>> _fetchProjectDataForSite(String siteId) async {
    try {
      // Try 1: query projects by siteId field
      var projSnap = await FirestoreService.getCollection('projects')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();

      // Try 2: if siteId query returned nothing, try querying by siteName from the Site doc
      if (projSnap.docs.isEmpty) {
        final siteData = _siteDocCache[siteId];
        final sName = siteData?['siteName']?.toString();
        if (sName != null && sName.isNotEmpty && sName != siteId) {
          projSnap = await FirestoreService.getCollection('projects')
              .where('siteName', isEqualTo: sName)
              .limit(1)
              .get();
        }
      }

      if (projSnap.docs.isNotEmpty) {
        return projSnap.docs.first.data();
      }
    } catch (e) {
      debugPrint('Error fetching project data for site $siteId: $e');
    }
    return {};
  }

  /// Extracts the project name from project data, trying multiple field names.
  String _extractProjectName(Map<String, dynamic> pData) {
    // projects collection sometimes stores the name in 'projectName', sometimes in 'siteName'
    final name = (pData['projectName']?.toString() ?? '').trim();
    if (name.isNotEmpty) return name;
    return (pData['siteName']?.toString() ?? '').trim();
  }

  /// Auto-fills all form fields from the cached siteSupervisorMap document
  /// corresponding to the selected site name.
  void _autoFillFromSite(String siteName) async {
    final docId = _siteToDocId[siteName];
    if (docId != null) {
      final data = _docCache[docId];
      if (data != null) {
        String pName = (data['projectName']?.toString() ?? '').trim();
        String pStage = (data['projectStage']?.toString() ?? '').trim();
        String loc = (data['location']?.toString() ?? '').trim();
        DateTime? sDate = _parseDate(data['startDate']);
        DateTime? eDate = _parseDate(data['endDate']);

        // If key fields are missing from the map doc, fetch from projects collection
        if (pName.isEmpty || sDate == null || eDate == null) {
          final pData = await _fetchProjectDataForSite(siteName);
          if (pData.isNotEmpty) {
            if (pName.isEmpty) pName = _extractProjectName(pData);
            if (pStage.isEmpty) pStage = (pData['projectStage']?.toString() ?? '').trim();
            if (loc.isEmpty) loc = (pData['location'] ?? pData['siteLocation'])?.toString() ?? '';
            sDate ??= _parseDate(pData['plannedStartDate']) ?? _parseDate(pData['startDate']);
            eDate ??= _parseDate(pData['plannedEndDate']) ?? _parseDate(pData['endDate']);
          }
        }

        // Final fallback: use siteName from the Site collection
        if (pName.isEmpty) {
          final siteData = _siteDocCache[siteName];
          pName = (siteData?['siteName']?.toString() ?? '').trim();
          if (loc.isEmpty) loc = (siteData?['location']?.toString() ?? '').trim();
          sDate ??= _parseDate(siteData?['startDate']);
          eDate ??= _parseDate(siteData?['endDate']);
        }

        if (!mounted) return;
        setState(() {
          selectedSupervisorId = data['Supervisor ID']?.toString() ?? '';
          selectedSupervisor = data['supervisor']?.toString() ?? '';
          projectName = pName;
          selectedProjectStage = pStage;
          locationController.text = loc;
          commentsController.text = data['siteComments']?.toString() ?? '';
          startDate = sDate;
          endDate = eDate;
          joinedDate = _parseDate(data['joinedOn']);
        });
        return;
      }
    }

    // Fallback: it's a newly created site with no siteSupervisorMap entry
    setState(() {
      selectedSupervisorId = '';
      selectedSupervisor = '';
      projectName = '';
      selectedProjectStage = '';
      locationController.clear();
      commentsController.clear();
      startDate = null;
      endDate = null;
      joinedDate = null;
    });

    try {
      // 1. Try fetching from the projects collection
      final pData = await _fetchProjectDataForSite(siteName);
      String pName = '';
      String pStage = '';
      String loc = '';
      DateTime? sDate;
      DateTime? eDate;

      if (pData.isNotEmpty) {
        pName = _extractProjectName(pData);
        pStage = (pData['projectStage']?.toString() ?? '').trim();
        loc = (pData['location'] ?? pData['siteLocation'])?.toString() ?? '';
        sDate = _parseDate(pData['plannedStartDate']) ?? _parseDate(pData['startDate']);
        eDate = _parseDate(pData['plannedEndDate']) ?? _parseDate(pData['endDate']);
      }

      // 2. Fallback to Site collection data for any still-missing fields
      final siteData = _siteDocCache[siteName];
      if (siteData != null) {
        if (pName.isEmpty) pName = (siteData['siteName']?.toString() ?? '').trim();
        if (loc.isEmpty) loc = (siteData['location']?.toString() ?? '').trim();
        sDate ??= _parseDate(siteData['startDate']);
        eDate ??= _parseDate(siteData['endDate']);
      }

      if (!mounted) return;
      setState(() {
        projectName = pName;
        selectedProjectStage = pStage;
        locationController.text = loc;
        startDate = sDate;
        endDate = eDate;
      });
    } catch (e) {
      debugPrint('Error auto-filling from site $siteName: $e');
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
      siteComments = null;
      locationController.clear();
      commentsController.clear();
      joinedDate = null;
      startDate = null;
      endDate = null;
    });
  }

  /// Finds the siteSupervisorMap doc ID for the selected site from the local cache.
  Future<String?> findDocIdBySiteId(String siteName) async {
    // Prefer the cached mapping populated from _fetchSiteSupervisorMapDocs
    if (_siteToDocId.containsKey(siteName)) {
      return _siteToDocId[siteName];
    }
    // Fallback: query Firestore directly
    final querySnapshot = await FirestoreService.getCollection(
      'siteSupervisorMap',
    ).where('site', isEqualTo: siteName).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
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
      DocumentReference docRef = FirestoreService.getCollection(
        'siteSupervisorMap',
      ).doc(docId);
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
    return GlassScaffold(
      title: 'Site-Supervisor Mapping',
      onBack: () => Navigator.pop(context),
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
                      _autoFillFromSite(value);
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
                  style: TextStyle(fontSize: fontSize),
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
                  style: TextStyle(fontSize: fontSize),
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: (_supervisorList.any((s) => s['id'] == selectedSupervisorId))
                      ? selectedSupervisorId
                      : null,
                  hint: Text(
                    'Select Supervisor ID',
                    style: TextStyle(color: primaryColor, fontSize: fontSize),
                  ),
                  items: _supervisorList.map((sup) {
                    return DropdownMenuItem<String>(
                      value: sup['id'],
                      child: Text(
                        '${sup['id']} - ${sup['fullName']}',
                        style: TextStyle(fontSize: fontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSupervisorId = value;
                      // Auto-fill supervisor name from the selected ID
                      final match = _supervisorList.firstWhere(
                        (s) => s['id'] == value,
                        orElse: () => {'id': '', 'fullName': ''},
                      );
                      selectedSupervisor = match['fullName'] ?? '';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Supervisor ID',
                    prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
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
                  style: TextStyle(fontSize: fontSize),
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
                  style: TextStyle(fontSize: fontSize),
                ),
                SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
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
                  controller: TextEditingController(
                    text: selectedSite ?? '',
                  ),
                  style: TextStyle(fontSize: fontSize),
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
                  style: TextStyle(fontSize: fontSize),
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
                  style: TextStyle(fontSize: fontSize),
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
                  style: TextStyle(fontSize: fontSize),
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
                      style: TextStyle(fontSize: fontSize),
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
    // Use the already-fetched cache if available; otherwise trigger a fresh fetch
    if (_docCache.isNotEmpty) {
      return _buildInfoCards(context, fontSize, _docCache);
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.getCollection('siteSupervisorMap').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
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
              padding: const EdgeInsets.symmetric(vertical: 32.0),
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
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                'No site mapping data available.',
                style: TextStyle(color: primaryColor, fontSize: fontSize),
              ),
            ),
          );
        }
        // Build a temporary cache from FutureBuilder results
        final Map<String, Map<String, dynamic>> tempCache = {
          for (final doc in docs)
            doc.id: doc.data() as Map<String, dynamic>? ?? {},
        };
        return _buildInfoCards(context, fontSize, tempCache);
      },
    );
  }

  Widget _buildInfoCards(
    BuildContext context,
    double fontSize,
    Map<String, Map<String, dynamic>> cache,
  ) {
    final entries = cache.entries.toList();
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No site mapping data available.',
            style: TextStyle(color: primaryColor, fontSize: fontSize),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final docId = entries[index].key;
        final data = entries[index].value;

        final site = data['site']?.toString() ?? '-';
        final supervisor = data['supervisor']?.toString() ?? '-';
        final supervisorId = data['Supervisor ID']?.toString() ?? '-';
        final projectNameVal = data['projectName']?.toString() ?? '-';
        final projectStage = data['projectStage']?.toString() ?? '-';
        final location = data['location']?.toString() ?? '-';
        final siteComments = data['siteComments']?.toString() ?? '';

        final startDateStr = _parseDate(data['startDate']) != null
            ? DateFormat('yyyy-MM-dd').format(_parseDate(data['startDate'])!)
            : '-';
        final endDateStr = _parseDate(data['endDate']) != null
            ? DateFormat('yyyy-MM-dd').format(_parseDate(data['endDate'])!)
            : '-';
        final joinedStr = _parseDate(data['joinedOn']) != null
            ? DateFormat('yyyy-MM-dd').format(_parseDate(data['joinedOn'])!)
            : '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: primaryColor.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: site icon + site name + doc ID badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.1),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.location_city, color: primaryColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site != '-' && site.isNotEmpty ? site : 'No Site',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              docId,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Divider(height: 1, thickness: 1),
                ),
                // Details grid
                _infoRow(Icons.person_outline, 'Supervisor', supervisor),
                _infoRow(Icons.badge_outlined, 'Supervisor ID', supervisorId),
                _infoRow(Icons.business_outlined, 'Project', projectNameVal),
                _infoRow(Icons.work_outline, 'Stage', projectStage),
                _infoRow(Icons.place_outlined, 'Location', location),
                if (siteComments.isNotEmpty)
                  _infoRow(Icons.comment_outlined, 'Comments', siteComments),
                const SizedBox(height: 8),
                // Dates row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dateChip(Icons.calendar_today, 'Start', startDateStr),
                    _dateChip(Icons.event_available, 'End', endDateStr),
                    _dateChip(Icons.login, 'Joined', joinedStr),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
        final themeColor = Theme.of(context).colorScheme.primary;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: themeColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: themeColor,
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
