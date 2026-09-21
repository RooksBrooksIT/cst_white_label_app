import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/services/notification_service.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class SiteSupervisorMapScreen extends StatefulWidget {
  const SiteSupervisorMapScreen({super.key});

  @override
  State<SiteSupervisorMapScreen> createState() =>
      _SiteSupervisorMapScreenState();
}

class _SiteSupervisorMapScreenState extends State<SiteSupervisorMapScreen> {
  bool isEntrySelected = true;
  int _infoCurrentPage = 1;
  final int _infoItemsPerPage = 10;
  String _infoSearchQuery = '';

  String? selectedSiteKey;
  String? selectedSiteId;
  String? selectedSite;
  String? selectedSupervisor;
  String? selectedSupervisorId;
  String? selectedProjectStage;
  String? projectName;
  DateTime? joinedDate;
  DateTime? startDate;
  DateTime? endDate;

  bool _isLoadingSites = true;
  bool _isLoadingSupervisors = true;

  Map<String, Map<String, dynamic>> _docCache = {};

  final locationController = TextEditingController();
  final commentsController = TextEditingController();
  final projectNameController = TextEditingController();
  final supervisorNameController = TextEditingController();
  final projectStageController = TextEditingController();
  final siteNameController = TextEditingController();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();

  List<Map<String, dynamic>> _allSites = [];
  List<Map<String, String>> _supervisorList = [];

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchSitesAndMappings();
    _fetchSupervisors();
  }

  @override
  void dispose() {
    locationController.dispose();
    commentsController.dispose();
    projectNameController.dispose();
    supervisorNameController.dispose();
    projectStageController.dispose();
    siteNameController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupervisors() async {
    setState(() => _isLoadingSupervisors = true);
    try {
      final snapshot = await FirestoreService.getCollection('supervisor').get();
      if (!mounted) return;

      final loaded = <Map<String, String>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final supId = (data['SupervisorId'] ?? data['supervisorId'] ?? doc.id).toString();
        final fullName = (data['FullName'] ?? data['fullName'] ?? data['name'] ?? '').toString();

        if (supId.isNotEmpty) {
          loaded.add({
            'id': supId,
            'fullName': fullName,
          });
        }
      }

      setState(() {
        _supervisorList = loaded;
        _isLoadingSupervisors = false;
      });
    } catch (e) {
      debugPrint('Error fetching supervisors: $e');
      if (mounted) setState(() => _isLoadingSupervisors = false);
    }
  }

  Future<void> _fetchSitesAndMappings() async {
    setState(() => _isLoadingSites = true);
    try {
      // 1. Fetch from 'Site' collection (primary) and 'sites' (legacy fallback)
      final siteDocs = <String, Map<String, dynamic>>{};

      try {
        final siteSnap = await FirestoreService.getCollection('Site').get();
        for (var doc in siteSnap.docs) {
          final data = doc.data();
          siteDocs[doc.id] = {
            ...data,
            'docId': doc.id,
          };
        }
      } catch (e) {
        debugPrint('Error fetching Site collection: $e');
      }

      try {
        final legacySiteSnap = await FirestoreService.getCollection('sites').get();
        for (var doc in legacySiteSnap.docs) {
          if (!siteDocs.containsKey(doc.id)) {
            siteDocs[doc.id] = {
              ...doc.data(),
              'docId': doc.id,
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching legacy sites: $e');
      }

      // 2. Fetch projects to correlate project name & stage with site
      final projectMap = <String, Map<String, dynamic>>{};
      try {
        final projSnap = await FirestoreService.getCollection('projects').get();
        for (var doc in projSnap.docs) {
          final pData = doc.data();
          final sId = (pData['siteId'] ?? '').toString().trim();
          final sName = (pData['siteName'] ?? '').toString().trim();
          if (sId.isNotEmpty) projectMap[sId] = pData;
          if (sName.isNotEmpty) projectMap[sName] = pData;
          projectMap[doc.id] = pData;
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      // 3. Fetch existing mappings in siteSupervisorMap
      final mappingMap = <String, Map<String, dynamic>>{};
      final tempCache = <String, Map<String, dynamic>>{};
      try {
        final mapSnap = await FirestoreService.getCollection('siteSupervisorMap').get();
        for (var doc in mapSnap.docs) {
          final mData = doc.data();
          tempCache[doc.id] = mData;
          final sField = (mData['site'] ?? mData['siteName'] ?? mData['siteId'] ?? '').toString().trim();
          final sId = (mData['siteId'] ?? '').toString().trim();
          if (sField.isNotEmpty) mappingMap[sField] = mData;
          if (sId.isNotEmpty) mappingMap[sId] = mData;
          mappingMap[doc.id] = mData;
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorMap: $e');
      }

      // 4. Ingest and deduplicate across all sources by canonical siteId
      final Map<String, Map<String, dynamic>> consolidatedMap = {};

      void ingestSiteRecord({
        required String docId,
        required Map<String, dynamic> data,
      }) {
        final rawSiteId = (data['siteId'] ??
                data['siteCode'] ??
                data['SiteCode'] ??
                data['id'] ??
                data['siteDocId'] ??
                docId)
            .toString()
            .trim();

        String cleanSiteId = SiteDisplayHelper.extractSiteId(rawSiteId);
        if (cleanSiteId.isEmpty) {
          cleanSiteId = rawSiteId.contains('_') ? rawSiteId.split('_').first.trim() : rawSiteId;
        }
        if (cleanSiteId.isEmpty) {
          cleanSiteId = docId.trim();
        }

        String cleanSiteName = (data['siteName'] ??
                data['name'] ??
                data['projectName'] ??
                data['project'] ??
                '')
            .toString()
            .trim();

        if (cleanSiteName.isEmpty || cleanSiteName.toLowerCase() == cleanSiteId.toLowerCase()) {
          cleanSiteName = SiteDisplayHelper.extractSiteName(data['siteName'] ?? data['site'] ?? docId, siteId: cleanSiteId);
        }
        if (cleanSiteName.isEmpty) {
          cleanSiteName = cleanSiteId;
        }

        // Canonical deduplication key (using siteId)
        final canonicalKey = cleanSiteId.isNotEmpty ? cleanSiteId.toLowerCase() : cleanSiteName.toLowerCase();
        if (canonicalKey.isEmpty) return;

        final proj = projectMap[cleanSiteId] ??
            projectMap[cleanSiteName] ??
            projectMap[docId] ??
            projectMap[canonicalKey];
        final mapping = mappingMap[cleanSiteId] ??
            mappingMap[cleanSiteName] ??
            mappingMap[docId] ??
            mappingMap[canonicalKey];

        final projectNameVal = (mapping?['projectName'] ??
                mapping?['project'] ??
                proj?['projectName'] ??
                data['projectName'] ??
                data['project'] ??
                cleanSiteName)
            .toString()
            .trim();

        final stageVal = (mapping?['projectStage'] ??
                mapping?['stage'] ??
                proj?['projectStage'] ??
                proj?['stage'] ??
                data['projectStage'] ??
                data['stage'] ??
                '')
            .toString()
            .trim();

        final locVal = (mapping?['location'] ??
                mapping?['address'] ??
                data['location'] ??
                data['address'] ??
                proj?['location'] ??
                proj?['address'] ??
                '')
            .toString()
            .trim();

        final sDate = _parseDate(mapping?['startDate'] ?? proj?['startDate'] ?? data['startDate']);
        final eDate = _parseDate(mapping?['endDate'] ?? proj?['endDate'] ?? data['endDate']);
        final jDate = _parseDate(mapping?['Joined On'] ?? mapping?['joinedDate'] ?? data['Joined On'] ?? data['joinedDate']);

        final supId = (mapping?['Supervisor ID'] ??
                mapping?['supervisorId'] ??
                mapping?['SupervisorId'] ??
                data['Supervisor ID'] ??
                data['supervisorId'] ??
                data['SupervisorId'] ??
                '')
            .toString()
            .trim();

        final supName = (mapping?['supervisor'] ??
                mapping?['supervisorName'] ??
                mapping?['FullName'] ??
                data['supervisor'] ??
                data['supervisorName'] ??
                data['FullName'] ??
                '')
            .toString()
            .trim();

        final comments = (mapping?['siteComments'] ??
                mapping?['comments'] ??
                data['siteComments'] ??
                data['comments'] ??
                '')
            .toString()
            .trim();

        final label = SiteDisplayHelper.formatSiteDisplay(
          siteId: cleanSiteId,
          siteName: cleanSiteName,
        );

        if (consolidatedMap.containsKey(canonicalKey)) {
          final existing = consolidatedMap[canonicalKey]!;
          if ((existing['projectName'] as String).isEmpty && projectNameVal.isNotEmpty) {
            existing['projectName'] = projectNameVal;
          }
          if ((existing['projectStage'] as String).isEmpty && stageVal.isNotEmpty) {
            existing['projectStage'] = stageVal;
          }
          if ((existing['location'] as String).isEmpty && locVal.isNotEmpty) {
            existing['location'] = locVal;
          }
          if (existing['startDate'] == null && sDate != null) {
            existing['startDate'] = sDate;
          }
          if (existing['endDate'] == null && eDate != null) {
            existing['endDate'] = eDate;
          }
          if (existing['joinedDate'] == null && jDate != null) {
            existing['joinedDate'] = jDate;
          }
          if ((existing['siteComments'] as String).isEmpty && comments.isNotEmpty) {
            existing['siteComments'] = comments;
          }
          if ((existing['supervisorId'] as String).isEmpty && supId.isNotEmpty) {
            existing['supervisorId'] = supId;
          }
          if ((existing['supervisorName'] as String).isEmpty && supName.isNotEmpty) {
            existing['supervisorName'] = supName;
          }
        } else {
          consolidatedMap[canonicalKey] = {
            'key': cleanSiteId.isNotEmpty ? cleanSiteId : canonicalKey,
            'docId': docId,
            'siteId': cleanSiteId,
            'siteName': cleanSiteName,
            'displayLabel': label.isNotEmpty ? label : (cleanSiteName.isNotEmpty ? '${cleanSiteId}_$cleanSiteName' : cleanSiteId),
            'projectName': projectNameVal,
            'projectStage': stageVal,
            'location': locVal,
            'startDate': sDate,
            'endDate': eDate,
            'joinedDate': jDate,
            'supervisorId': supId,
            'supervisorName': supName,
            'siteComments': comments,
            'rawMapping': mapping,
          };
        }
      }

      // Ingest from Site collection
      for (var entry in siteDocs.entries) {
        ingestSiteRecord(docId: entry.key, data: entry.value);
      }

      // Ingest from projects collection
      for (var entry in projectMap.entries) {
        ingestSiteRecord(docId: entry.key, data: entry.value);
      }

      // Ingest from siteSupervisorMap collection
      for (var entry in tempCache.entries) {
        ingestSiteRecord(docId: entry.key, data: entry.value);
      }

      final consolidated = consolidatedMap.values.toList();
      consolidated.sort((a, b) =>
          (a['displayLabel'] as String).toLowerCase().compareTo(
                (b['displayLabel'] as String).toLowerCase(),
              ));

      if (!mounted) return;
      setState(() {
        _allSites = consolidated;
        _docCache = tempCache;
        _isLoadingSites = false;
      });
    } catch (e) {
      debugPrint('Error fetching sites and mappings: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sites: $e')),
        );
      }
    }
  }

  void _onSiteSelected(String? siteKey) {
    if (siteKey == null) return;
    final site = _allSites.firstWhere(
      (s) =>
          s['key'] == siteKey ||
          s['siteId'] == siteKey ||
          s['siteName'] == siteKey,
      orElse: () => {},
    );
    if (site.isEmpty) return;

    setState(() {
      selectedSiteKey = site['key'] as String?;
      selectedSiteId = (site['siteId'] != null &&
              site['siteId'].toString().isNotEmpty)
          ? site['siteId'].toString()
          : (site['siteName']?.toString() ?? siteKey);
      selectedSite = site['siteName']?.toString() ?? selectedSiteId;
      projectName = site['projectName']?.toString() ?? '';
      selectedProjectStage = site['projectStage']?.toString() ?? '';

      locationController.text = site['location']?.toString() ?? '';
      commentsController.text = site['siteComments']?.toString() ?? '';
      projectNameController.text = projectName ?? '';
      projectStageController.text = selectedProjectStage ?? '';
      siteNameController.text = selectedSite ?? '';

      startDate = site['startDate'] as DateTime?;
      endDate = site['endDate'] as DateTime?;
      joinedDate = site['joinedDate'] as DateTime?;

      startDateController.text = startDate != null
          ? DateFormat('yyyy-MM-dd').format(startDate!)
          : '';
      endDateController.text =
          endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '';

      final supId = site['supervisorId']?.toString() ?? '';
      final supName = site['supervisorName']?.toString() ?? '';
      if (supId.isNotEmpty) {
        selectedSupervisorId = supId;
        selectedSupervisor = supName;
        if (selectedSupervisor == null || selectedSupervisor!.isEmpty) {
          final match = _supervisorList.firstWhere(
            (s) => s['id'] == supId,
            orElse: () => {'id': '', 'fullName': ''},
          );
          selectedSupervisor = match['fullName'];
        }
      }
      supervisorNameController.text = selectedSupervisor ?? '';
    });
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.isNotEmpty) {
      try {
        return DateTime.parse(val);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _selectAnyDate(BuildContext context,
      {required String dateType}) async {
    DateTime initial = DateTime.now();
    if (dateType == 'joined' && joinedDate != null) initial = joinedDate!;
    if (dateType == 'start' && startDate != null) initial = startDate!;
    if (dateType == 'end' && endDate != null) initial = endDate!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (dateType == 'joined') joinedDate = picked;
        if (dateType == 'start') {
          startDate = picked;
          startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
        if (dateType == 'end') {
          endDate = picked;
          endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  void resetForm() {
    setState(() {
      selectedSiteKey = null;
      selectedSiteId = null;
      selectedSite = null;
      selectedSupervisor = null;
      selectedSupervisorId = null;
      selectedProjectStage = null;
      projectName = null;
      joinedDate = null;
      startDate = null;
      endDate = null;

      locationController.clear();
      commentsController.clear();
      projectNameController.clear();
      supervisorNameController.clear();
      projectStageController.clear();
      siteNameController.clear();
      startDateController.clear();
      endDateController.clear();
    });
  }

  Future<void> _showSaveConfirmationDialog(BuildContext context) async {
    if ((selectedSite == null || selectedSite!.isEmpty) &&
        (selectedSiteId == null || selectedSiteId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site ID / site')),
      );
      return;
    }
    if (selectedSupervisorId == null || selectedSupervisorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supervisor ID')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Confirm Save',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
          ),
          content: Text(
            'Are you sure you want to save mapping for site "${selectedSiteId ?? selectedSite}" with supervisor "$selectedSupervisor" ($selectedSupervisorId)?',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _saveMappingData();
    }
  }

  Future<void> _saveMappingData() async {
    try {
      final sId = (selectedSiteId != null && selectedSiteId!.trim().isNotEmpty)
          ? selectedSiteId!.trim()
          : (selectedSite ?? 'SITE').trim();
      final sName = (selectedSite != null && selectedSite!.trim().isNotEmpty)
          ? selectedSite!.trim()
          : sId;
      final supName = (selectedSupervisor != null && selectedSupervisor!.trim().isNotEmpty)
          ? selectedSupervisor!.trim()
          : (selectedSupervisorId ?? 'SUPERVISOR').trim();

      // Construct document ID as unique combination of Site ID, Site Name, and Supervisor Name
      // e.g. ST001_Testing_Suban
      final docId = '${sId}_${sName}_$supName';

      final canonicalSiteDocId = ExpenseService.formatCanonicalSiteDocId(
        selectedSiteId ?? '',
        selectedSite ?? '',
      );

      final managerName = (AuthService().userData['FullName'] ??
              AuthService().userData['fullName'] ??
              AuthService().userData['Name'] ??
              AuthService().userData['name'] ??
              AuthService().userData['managerName'] ??
              AuthService().userData['username'] ??
              AuthService().userData['userName'] ??
              'Manager Admin')
          .toString()
          .trim();
      final effectiveManagerName =
          managerName.isNotEmpty ? managerName : 'Manager Admin';

      final mappingData = {
        'siteId': sId,
        'siteName': sName,
        'supervisorName': supName,
        'managerName': effectiveManagerName,
        'site': canonicalSiteDocId.isNotEmpty
            ? canonicalSiteDocId
            : (selectedSiteId ?? selectedSite),
        'siteDocId': canonicalSiteDocId.isNotEmpty ? canonicalSiteDocId : sId,
        'projectName': projectName ?? projectNameController.text.trim(),
        'project': projectName ?? projectNameController.text.trim(),
        'location': locationController.text.trim(),
        'Supervisor ID': selectedSupervisorId ?? '',
        'supervisorId': selectedSupervisorId ?? '',
        'SupervisorId': selectedSupervisorId ?? '',
        'supervisor': supName,
        'FullName': supName,
        'manager': effectiveManagerName,
        'assignedByManager': effectiveManagerName,
        'managerId': FirebaseAuth.instance.currentUser?.uid ??
            AuthService().userData['id']?.toString() ??
            AuthService().userData['userId']?.toString() ??
            '',
        'projectStage':
            selectedProjectStage ?? projectStageController.text.trim(),
        'stage': selectedProjectStage ?? projectStageController.text.trim(),
        'siteComments': commentsController.text.trim(),
        'startDate': startDate != null
            ? DateFormat('yyyy-MM-dd').format(startDate!)
            : startDateController.text.trim(),
        'endDate': endDate != null
            ? DateFormat('yyyy-MM-dd').format(endDate!)
            : endDateController.text.trim(),
        'Joined On': joinedDate != null
            ? DateFormat('yyyy-MM-dd').format(joinedDate!)
            : '',
        'joinedDate': joinedDate != null
            ? DateFormat('yyyy-MM-dd').format(joinedDate!)
            : '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Store in siteSupervisorMap with document ID siteId_siteName_supervisorName
      await FirestoreService.getCollection('siteSupervisorMap')
          .doc(docId)
          .set(mappingData, SetOptions(merge: true));

      // Trigger immediate real-time push notification to the mapped supervisor
      try {
        await NotificationService.notifySiteAssignment(
          supervisorName: supName,
          supervisorId: selectedSupervisorId,
          siteId: sId,
          siteName: sName,
          projectName: projectName ?? projectNameController.text.trim(),
          location: locationController.text.trim(),
          managerName: effectiveManagerName,
        );
      } catch (notifErr) {
        debugPrint('Error triggering site assignment notification: $notifErr');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site-Supervisor mapping saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _docCache[docId] = mappingData;

      await _fetchSitesAndMappings();

      setState(() {
        isEntrySelected = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save mapping: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Supervisor Mapping',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isEntrySelected = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isEntrySelected
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MAPPING ENTRY',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFF0A183D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isEntrySelected = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isEntrySelected
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: !isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MAPPING INFO',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: !isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFF0A183D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 600),
                  child: isEntrySelected
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: _buildEntrySection(),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: _buildInfoTableSection(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.connect_without_contact_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Mapping Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildSiteDropdown(),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Project Name',
                controller: projectNameController,
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.business_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Location',
                controller: locationController,
                hint: 'Enter site location',
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 14),

              _buildSupervisorIdDropdown(),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Supervisor Name',
                controller: supervisorNameController,
                hint: 'Auto-filled from ID selection',
                readOnly: true,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Project Stage',
                controller: projectStageController,
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.timeline_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Site',
                controller: siteNameController,
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Site Comments',
                controller: commentsController,
                hint: 'Enter site comments or instructions',
                maxLines: 3,
                icon: Icons.comment_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Start Date',
                controller: startDateController,
                hint: 'Auto-filled start date',
                readOnly: true,
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'End Date',
                controller: endDateController,
                hint: 'Auto-filled end date',
                readOnly: true,
                icon: Icons.event_rounded,
              ),
              const SizedBox(height: 14),

              _buildDateField(
                label: 'Joined On',
                date: joinedDate,
                onTap: () => _selectAnyDate(context, dateType: 'joined'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildActionButtons(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: const TextSpan(
                  text: 'Select Site ID / Site',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                    letterSpacing: -0.1,
                  ),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingSites)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(brandIconColor),
                ),
              ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: (_allSites.any((s) => s['key'] == selectedSiteKey))
              ? selectedSiteKey
              : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: _isLoadingSites
                ? 'Loading site IDs & sites...'
                : (_allSites.isEmpty
                    ? 'No sites found'
                    : 'Select Site ID / Site'),
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.location_on_rounded,
                color: brandIconColor,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
          ),
          items: _allSites.map((site) {
            return DropdownMenuItem<String>(
              value: site['key'] as String,
              child: Text(
                site['displayLabel'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            _onSiteSelected(value);
          },
        ),
      ],
    );
  }

  Widget _buildSupervisorIdDropdown() {
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: const TextSpan(
                  text: 'Supervisor ID',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                    letterSpacing: -0.1,
                  ),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingSupervisors)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(brandIconColor),
                ),
              ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue:
              (_supervisorList.any((s) => s['id'] == selectedSupervisorId))
                  ? selectedSupervisorId
                  : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: _isLoadingSupervisors
                ? 'Loading supervisors...'
                : (_supervisorList.isEmpty
                    ? 'No supervisors found'
                    : 'Select Supervisor ID'),
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.badge_rounded,
                color: brandIconColor,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
          ),
          items: _supervisorList.map((sup) {
            final id = sup['id'] ?? '';
            final name = sup['fullName'] ?? '';
            final label = name.isNotEmpty ? '$id - $name' : id;
            return DropdownMenuItem<String>(
              value: id,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSupervisorId = value;
              final match = _supervisorList.firstWhere(
                (s) => s['id'] == value,
                orElse: () => {'id': '', 'fullName': ''},
              );
              selectedSupervisor = match['fullName'] ?? '';
              supervisorNameController.text = selectedSupervisor ?? '';

              // If a mapping for this (site, supervisor) already exists in cache, load its specific details
              final sId = (selectedSiteId != null && selectedSiteId!.trim().isNotEmpty)
                  ? selectedSiteId!.trim()
                  : (selectedSite ?? '').trim();
              final sName = (selectedSite != null && selectedSite!.trim().isNotEmpty)
                  ? selectedSite!.trim()
                  : sId;
              final supName = (selectedSupervisor ?? '').trim();
              final directDocId = '${sId}_${sName}_$supName';

              Map<String, dynamic>? existing = _docCache[directDocId];
              if (existing == null && sId.isNotEmpty && supName.isNotEmpty) {
                for (var entry in _docCache.entries) {
                  final d = entry.value;
                  final dSite = (d['siteId'] ?? d['site'] ?? '').toString().trim().toLowerCase();
                  final dSup = (d['supervisorName'] ?? d['supervisor'] ?? d['FullName'] ?? '').toString().trim().toLowerCase();
                  final dSupId = (d['Supervisor ID'] ?? d['supervisorId'] ?? '').toString().trim().toLowerCase();
                  if ((dSite == sId.toLowerCase() || entry.key.toLowerCase().startsWith('${sId.toLowerCase()}_')) &&
                      (dSup == supName.toLowerCase() || (value != null && dSupId == value.toLowerCase()))) {
                    existing = d;
                    break;
                  }
                }
              }

              if (existing != null) {
                if ((existing['location'] ?? '').toString().isNotEmpty) {
                  locationController.text = existing['location'].toString();
                }
                if ((existing['siteComments'] ?? existing['comments'] ?? '').toString().isNotEmpty) {
                  commentsController.text = (existing['siteComments'] ?? existing['comments']).toString();
                }
                final jDate = _parseDate(existing['Joined On'] ?? existing['joinedDate']);
                if (jDate != null) {
                  joinedDate = jDate;
                }
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
    final isMultiLine = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          textAlignVertical: isMultiLine ? TextAlignVertical.top : TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 8,
                      top: isMultiLine ? 10 : 0,
                      bottom: isMultiLine ? 10 : 0,
                    ),
                    child: Icon(icon, color: brandIconColor, size: 18),
                  )
                : null,
            prefixIconConstraints: BoxConstraints(
              minWidth: 38,
              minHeight: isMultiLine ? 24 : 38,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isMultiLine ? 12 : 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
              letterSpacing: -0.1,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.calendar_today_rounded, color: brandIconColor, size: 18),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandIconColor, width: 1.5),
              ),
            ),
            child: Text(
              date == null
                  ? 'Select Joined Date'
                  : DateFormat('MMM d, yyyy').format(date),
              style: TextStyle(
                color: date == null
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0A183D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () => _showSaveConfirmationDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SAVE MAPPING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: resetForm,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A183D),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0A183D)),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTableSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading site info: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFF0A183D)),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 64,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No site mapping data available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create your first mapping in the "MAPPING ENTRY" tab',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final Map<String, Map<String, dynamic>> tempCache = {
          for (final doc in docs)
            doc.id: doc.data() as Map<String, dynamic>? ?? {},
        };
        return _buildInfoCards(tempCache);
      },
    );
  }

  Widget _buildInfoCards(Map<String, Map<String, dynamic>> cache) {
    final allEntries = cache.entries.toList();

    final filteredEntries = allEntries.where((entry) {
      final docId = entry.key.toLowerCase();
      final data = entry.value;
      final site = (data['site'] ?? data['siteName'] ?? data['siteId'] ?? '')
          .toString()
          .toLowerCase();
      final supervisor = (data['supervisor'] ??
              data['supervisorName'] ??
              data['FullName'] ??
              '')
          .toString()
          .toLowerCase();
      final supervisorId = (data['Supervisor ID'] ??
              data['supervisorId'] ??
              data['SupervisorId'] ??
              '')
          .toString()
          .toLowerCase();
      final projectNameVal =
          (data['projectName'] ?? data['project'] ?? '').toString().toLowerCase();
      final projectStage =
          (data['projectStage'] ?? data['stage'] ?? '').toString().toLowerCase();
      final location =
          (data['location'] ?? data['address'] ?? '').toString().toLowerCase();

      final query = _infoSearchQuery.trim().toLowerCase();
      return query.isEmpty ||
          docId.contains(query) ||
          site.contains(query) ||
          supervisor.contains(query) ||
          supervisorId.contains(query) ||
          projectNameVal.contains(query) ||
          projectStage.contains(query) ||
          location.contains(query);
    }).toList();

    final totalItems = filteredEntries.length;
    final totalPages =
        (totalItems / _infoItemsPerPage).ceil().clamp(1, 999999);
    if (_infoCurrentPage > totalPages) {
      _infoCurrentPage = totalPages;
    }
    final startIndex =
        (totalItems == 0) ? 0 : (_infoCurrentPage - 1) * _infoItemsPerPage;
    final endIndex = (startIndex + _infoItemsPerPage).clamp(0, totalItems);
    final paginatedEntries = filteredEntries.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Live Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _infoSearchQuery = val;
                _infoCurrentPage = 1;
              });
            },
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hintText:
                  'Search mapping by site, supervisor, project, stage...',
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              suffixIcon: _infoSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        setState(() {
                          _infoSearchQuery = '';
                          _infoCurrentPage = 1;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: filteredEntries.isEmpty
              ? const Center(
                  child: Text(
                    'No matching site mappings found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: paginatedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = paginatedEntries[index];
                    final data = entry.value;

                    final siteName = (data['siteName'] ??
                        data['site'] ??
                        data['siteId'] ??
                        entry.key).toString();
                    final siteIdVal = (data['siteId'] ?? data['site'] ?? '').toString();
                    final displaySite = SiteDisplayHelper.formatSiteDisplay(
                      siteId: siteIdVal,
                      siteName: siteName,
                    );

                    final supervisorName = data['supervisor'] ??
                        data['supervisorName'] ??
                        data['FullName'] ??
                        'Not Assigned';
                    final supervisorId = data['Supervisor ID'] ??
                        data['supervisorId'] ??
                        data['SupervisorId'] ??
                        '';
                    final pName =
                        data['projectName'] ?? data['project'] ?? '';
                    final pStage =
                        data['projectStage'] ?? data['stage'] ?? '';
                    final loc =
                        data['location'] ?? data['address'] ?? '';
                    final sDate = data['startDate'] ?? '';
                    final eDate = data['endDate'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF0A183D).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.location_on_rounded,
                                    color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displaySite,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0A183D),
                                      ),
                                    ),
                                    if (pName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        pName,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (pStage.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pStage,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              const Text(
                                'Supervisor: ',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600),
                              ),
                              Expanded(
                                child: Text(
                                  supervisorName +
                                      (supervisorId.isNotEmpty
                                          ? ' ($supervisorId)'
                                          : ''),
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((data['managerName'] ?? data['manager'] ?? data['assignedByManager'] ?? '').toString().isNotEmpty &&
                              (data['managerName'] ?? data['manager'] ?? data['assignedByManager'] ?? '').toString().toLowerCase() != 'manager') ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.manage_accounts_rounded,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Manager: ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600),
                                ),
                                Expanded(
                                  child: Text(
                                    (data['managerName'] ?? data['manager'] ?? data['assignedByManager'] ?? '').toString(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF0A183D),
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (loc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (sDate.isNotEmpty || eDate.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.date_range_rounded,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Duration: ${sDate.isEmpty ? 'N/A' : sDate} to ${eDate.isEmpty ? 'N/A' : eDate}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Pagination Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildPaginationControls(
            currentPage: _infoCurrentPage,
            totalPages: totalPages,
            totalItems: totalItems,
            itemsPerPage: _infoItemsPerPage,
            onPageChanged: (newPage) {
              setState(() => _infoCurrentPage = newPage);
            },
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required Function(int) onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$startItem–$endItem of $totalItems',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.first_page_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
                tooltip: 'First Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed:
                    currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: currentPage < totalPages
                      ? primaryColor
                      : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Next Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.last_page_rounded,
                  size: 18,
                  color: currentPage < totalPages
                      ? primaryColor
                      : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(totalPages)
                    : null,
                tooltip: 'Last Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
