import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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

  Map<String, String> _siteToDocId = {};
  Map<String, Map<String, dynamic>> _docCache = {};
  Map<String, Map<String, dynamic>> _siteDocCache = {};

  final locationController = TextEditingController();
  final commentsController = TextEditingController();

  List<String> siteList = [];
  List<Map<String, String>> _supervisorList = [];

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorMapDocs();
    _fetchSupervisors();
  }

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

  void _fetchSiteSupervisorMapDocs() async {
    try {
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();
      final List<String> allSiteIds = [];
      final Map<String, Map<String, dynamic>> siteDocCache = {};
      for (final doc in sitesSnapshot.docs) {
        if (doc.id.isNotEmpty) {
          allSiteIds.add(doc.id);
          siteDocCache[doc.id] = doc.data();
        }
      }

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

  Future<Map<String, dynamic>> _fetchProjectDataForSite(String siteId) async {
    try {
      var projSnap = await FirestoreService.getCollection('projects')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();

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

  String _extractProjectName(Map<String, dynamic> pData) {
    final name = (pData['projectName']?.toString() ?? '').trim();
    if (name.isNotEmpty) return name;
    return (pData['siteName']?.toString() ?? '').trim();
  }

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

        if (pName.isEmpty || sDate == null || eDate == null) {
          final pData = await _fetchProjectDataForSite(siteName);
          if (pData.isNotEmpty) {
            if (pName.isEmpty) pName = _extractProjectName(pData);
            if (pStage.isEmpty)
              pStage = (pData['projectStage']?.toString() ?? '').trim();
            if (loc.isEmpty)
              loc = (pData['location'] ?? pData['siteLocation'])?.toString() ??
                  '';
            sDate ??= _parseDate(pData['plannedStartDate']) ??
                _parseDate(pData['startDate']);
            eDate ??= _parseDate(pData['plannedEndDate']) ??
                _parseDate(pData['endDate']);
          }
        }

        if (pName.isEmpty) {
          final siteData = _siteDocCache[siteName];
          pName = (siteData?['siteName']?.toString() ?? '').trim();
          if (loc.isEmpty)
            loc = (siteData?['location']?.toString() ?? '').trim();
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
        sDate = _parseDate(pData['plannedStartDate']) ??
            _parseDate(pData['startDate']);
        eDate = _parseDate(pData['plannedEndDate']) ??
            _parseDate(pData['endDate']);
      }

      final siteData = _siteDocCache[siteName];
      if (siteData != null) {
        if (pName.isEmpty)
          pName = (siteData['siteName']?.toString() ?? '').trim();
        if (loc.isEmpty)
          loc = (siteData['location']?.toString() ?? '').trim();
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
      debugPrint('Error auto-filling for new site $siteName: $e');
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  void resetForm() {
    setState(() {
      selectedSite = null;
      selectedSupervisor = null;
      selectedSupervisorId = null;
      selectedProjectStage = null;
      projectName = null;
      siteComments = null;
      locationController.clear();
      commentsController.clear();
      joinedDate = null;
      startDate = null;
      endDate = null;
    });
  }

  void saveForm() async {
    if (selectedSite == null || selectedSite!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site.')));
      return;
    }

    try {
      final docIdToUse =
          _siteToDocId[selectedSite] ?? selectedSite!.replaceAll(' ', '');

      final Map<String, dynamic> dataToSave = {
        'site': selectedSite,
        'Supervisor ID': selectedSupervisorId ?? '',
        'supervisor': selectedSupervisor ?? '',
        'projectName': projectName ?? '',
        'projectStage': selectedProjectStage ?? '',
        'location': locationController.text.trim(),
        'siteComments': commentsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startDate != null) dataToSave['startDate'] = startDate;
      if (endDate != null) dataToSave['endDate'] = endDate;
      if (joinedDate != null) dataToSave['joinedOn'] = joinedDate;

      await FirestoreService.getCollection('siteSupervisorMap')
          .doc(docIdToUse)
          .set(dataToSave, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form saved successfully!')),
      );

      _fetchSiteSupervisorMapDocs();
      resetForm();
    } catch (e) {
      debugPrint('Error saving form: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error saving form.')));
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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final Color darkCardBg = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Site-Supervisor Mapping',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Dark Pill Mode Switcher ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ENTRY',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isEntrySelected
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: !isEntrySelected
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'INFO',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: !isEntrySelected
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
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

            // ── Scrollable Tab Content ──────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: isEntrySelected
                        ? _buildEntrySection(darkCardBg, primaryColor)
                        : _buildInfoTableSection(darkCardBg, primaryColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ENTRY SECTION ─────────────────────────────────────────────────────────
  Widget _buildEntrySection(Color darkCardBg, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: darkCardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: darkCardBg.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mapping Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

              // Select Site Dropdown
              _buildSiteDropdown(),
              const SizedBox(height: 14),

              // Project Name (read-only)
              _buildTextField(
                label: 'Project Name',
                controller: TextEditingController(text: projectName ?? ''),
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.business_rounded,
              ),
              const SizedBox(height: 14),

              // Location
              _buildTextField(
                label: 'Location',
                controller: locationController,
                hint: 'Enter site location',
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 14),

              // Supervisor ID Dropdown
              _buildSupervisorIdDropdown(),
              const SizedBox(height: 14),

              // Supervisor Name (read-only)
              _buildTextField(
                label: 'Supervisor Name',
                controller: TextEditingController(text: selectedSupervisor ?? ''),
                hint: 'Auto-filled from ID selection',
                readOnly: true,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),

              // Project Stage (read-only)
              _buildTextField(
                label: 'Project Stage',
                controller: TextEditingController(text: selectedProjectStage ?? ''),
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.timeline_rounded,
              ),
              const SizedBox(height: 14),

              // Site (read-only)
              _buildTextField(
                label: 'Site',
                controller: TextEditingController(text: selectedSite ?? ''),
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 14),

              // Site Comments
              _buildTextField(
                label: 'Site Comments',
                controller: commentsController,
                hint: 'Enter site comments or instructions',
                maxLines: 3,
                icon: Icons.comment_rounded,
              ),
              const SizedBox(height: 14),

              // Start Date (read-only)
              _buildTextField(
                label: 'Start Date',
                controller: TextEditingController(
                  text: startDate != null
                      ? DateFormat('yyyy-MM-dd').format(startDate!)
                      : '',
                ),
                hint: 'Auto-filled start date',
                readOnly: true,
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 14),

              // End Date (read-only)
              _buildTextField(
                label: 'End Date',
                controller: TextEditingController(
                  text: endDate != null
                      ? DateFormat('yyyy-MM-dd').format(endDate!)
                      : '',
                ),
                hint: 'Auto-filled end date',
                readOnly: true,
                icon: Icons.event_rounded,
              ),
              const SizedBox(height: 14),

              // Joined On Date Picker
              _buildDateField(
                label: 'Joined On',
                date: joinedDate,
                onTap: () => _selectAnyDate(context, dateType: 'joined'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        _buildActionButtons(primaryColor),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Site *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: selectedSite,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select Site',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.location_on_rounded,
                  color: brandIconColor,
                  size: 22,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: siteList.map((site) {
              return DropdownMenuItem(
                value: site,
                child: Text(
                  site,
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
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorIdDropdown() {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor ID *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: (_supervisorList.any((s) => s['id'] == selectedSupervisorId))
                ? selectedSupervisorId
                : null,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select Supervisor ID',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.badge_rounded,
                  color: brandIconColor,
                  size: 22,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: _supervisorList.map((sup) {
              return DropdownMenuItem<String>(
                value: sup['id'],
                child: Text(
                  '${sup['id']} - ${sup['fullName']}',
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
              });
            },
          ),
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
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: brandIconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select Joined Date'
                        : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      color: date == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0A183D),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _showSaveConfirmationDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save_rounded,
                    size: 20,
                    color: Color(0xFF0A183D),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SAVE MAPPING',
                    style: TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: resetForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

  // ── INFO TABLE SECTION ────────────────────────────────────────────────────
  Widget _buildInfoTableSection(Color darkCardBg, Color primaryColor) {
    if (_docCache.isNotEmpty) {
      return _buildInfoCards(darkCardBg, primaryColor, _docCache);
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.getCollection('siteSupervisorMap').get(),
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
                  'Create your first mapping in the "ENTRY" tab',
                  style: TextStyle(
                    color: Color(0xFF475569),
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
        return _buildInfoCards(darkCardBg, primaryColor, tempCache);
      },
    );
  }

  Widget _buildInfoCards(
    Color darkCardBg,
    Color primaryColor,
    Map<String, Map<String, dynamic>> cache,
  ) {
    final entries = cache.entries.toList();
    if (entries.isEmpty) {
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
              'Create your first mapping in the "ENTRY" tab',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
              ),
            ),
          ],
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

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: darkCardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: darkCardBg.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.18),
                    ),
                    child: Icon(Icons.location_city_rounded,
                        color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site != '-' && site.isNotEmpty ? site : 'No Site',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            docId,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
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
                child: Divider(height: 1, color: Color(0xFF334155)),
              ),

              _infoRow(Icons.person_rounded, 'Supervisor', supervisor),
              _infoRow(Icons.badge_rounded, 'Supervisor ID', supervisorId),
              _infoRow(Icons.business_rounded, 'Project', projectNameVal),
              _infoRow(Icons.timeline_rounded, 'Stage', projectStage),
              _infoRow(Icons.location_on_rounded, 'Location', location),
              if (siteComments.isNotEmpty)
                _infoRow(Icons.comment_rounded, 'Comments', siteComments),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dateChip(Icons.calendar_today_rounded, 'Start', startDateStr),
                  _dateChip(Icons.event_available_rounded, 'End', endDateStr),
                  _dateChip(Icons.login_rounded, 'Joined', joinedStr),
                ],
              ),
            ],
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
          Icon(icon, size: 15, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
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
        Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w700,
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

  void _showSaveConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Confirm Save',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          content: const Text(
            'Your details will be saved. Do you want to continue?',
            style: TextStyle(fontSize: 15),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
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
