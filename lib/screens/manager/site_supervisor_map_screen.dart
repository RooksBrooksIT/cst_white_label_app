import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SiteSupervisorMapScreen extends StatefulWidget {
  const SiteSupervisorMapScreen({super.key});

  @override
  _SiteSupervisorMapScreenState createState() =>
      _SiteSupervisorMapScreenState();
}

class _SiteSupervisorMapScreenState extends State<SiteSupervisorMapScreen> {
  bool isEntrySelected = true;
  int _infoCurrentPage = 1;
  final int _infoItemsPerPage = 10;
  String _infoSearchQuery = '';

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

  final locationController = TextEditingController();
  final commentsController = TextEditingController();

  List<String> siteList = [];
  List<Map<String, String>> _supervisorList = [];

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorMapDocs();
    _fetchSupervisors();
  }

  @override
  void dispose() {
    locationController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupervisors() async {
    try {
      final snapshot = await FirestoreService.getCollection('supervisor').get();
      if (!mounted) return;

      final loaded = <Map<String, String>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final supId = (data['SupervisorId'] ?? doc.id).toString();
        final fullName = (data['FullName'] ?? '').toString();

        if (supId.isNotEmpty) {
          loaded.add({
            'id': supId,
            'fullName': fullName,
          });
        }
      }

      setState(() {
        _supervisorList = loaded;
      });
    } catch (e) {
      debugPrint('Error fetching supervisors: $e');
    }
  }

  Future<void> _fetchSiteSupervisorMapDocs() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).get();

      final tempSiteList = <String>[];
      final tempSiteToDocId = <String, String>{};
      final tempCache = <String, Map<String, dynamic>>{};

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final docId = doc.id;
        final siteName = data['site'] ?? data['siteName'] ?? data['siteId'] ?? docId;

        tempSiteList.add(siteName);
        tempSiteToDocId[siteName] = docId;
        tempCache[docId] = data;
      }

      if (!mounted) return;
      setState(() {
        siteList = tempSiteList;
        _siteToDocId = tempSiteToDocId;
        _docCache = tempCache;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching site mapping docs: $e')),
      );
    }
  }

  Future<void> _autoFillFromSite(String siteName) async {
    try {
      final docId = _siteToDocId[siteName] ?? siteName;

      Map<String, dynamic>? data = _docCache[docId];

      if (data == null) {
        final docSnap = await FirestoreService.getCollection(
          'siteSupervisorMap',
        ).doc(docId).get();
        if (docSnap.exists) {
          data = docSnap.data();
          if (data != null) _docCache[docId] = data;
        }
      }

      if (data != null) {
        _applyMapData(data);
        return;
      }

      final siteSnap = await FirestoreService.getCollection('sites')
          .where('siteName', isEqualTo: siteName)
          .limit(1)
          .get();

      if (siteSnap.docs.isNotEmpty) {
        final siteData = siteSnap.docs.first.data();
        _applyMapData(siteData);
      }
    } catch (e) {
      debugPrint('Error auto-filling from site: $e');
    }
  }

  void _applyMapData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      projectName = data['projectName'] ?? data['project'] ?? '';

      final rawSupervisorId = (data['Supervisor ID'] ?? data['supervisorId'] ?? data['SupervisorId'] ?? '').toString();
      final rawSupervisorName = (data['supervisor'] ?? data['supervisorName'] ?? data['FullName'] ?? '').toString();

      if (rawSupervisorId.isNotEmpty) {
        selectedSupervisorId = rawSupervisorId;
      }

      if (rawSupervisorName.isNotEmpty) {
        selectedSupervisor = rawSupervisorName;
      } else if (selectedSupervisorId != null && selectedSupervisorId!.isNotEmpty) {
        final match = _supervisorList.firstWhere(
          (s) => s['id'] == selectedSupervisorId,
          orElse: () => {'id': '', 'fullName': ''},
        );
        selectedSupervisor = match['fullName'];
      }

      selectedProjectStage = data['projectStage'] ?? data['stage'] ?? '';
      selectedSite = data['site'] ?? data['siteName'] ?? data['siteId'] ?? selectedSite;

      locationController.text = data['location'] ?? data['address'] ?? '';
      commentsController.text = data['siteComments'] ?? data['comments'] ?? '';

      startDate = _parseDate(data['startDate'] ?? data['start_date']);
      endDate = _parseDate(data['endDate'] ?? data['end_date']);

      joinedDate = _parseDate(data['joinedDate'] ?? data['joined_date'] ?? data['Joined On']);
    });
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String && val.isNotEmpty) {
      try {
        return DateTime.parse(val);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _selectAnyDate(BuildContext context, {required String dateType}) async {
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
        if (dateType == 'start') startDate = picked;
        if (dateType == 'end') endDate = picked;
      });
    }
  }

  void resetForm() {
    setState(() {
      selectedSite = null;
      selectedSupervisor = null;
      selectedSupervisorId = null;
      selectedProjectStage = null;
      projectName = null;
      siteComments = null;
      joinedDate = null;
      startDate = null;
      endDate = null;

      locationController.clear();
      commentsController.clear();
    });
  }

  Future<void> _showSaveConfirmationDialog(BuildContext context) async {
    if (selectedSite == null || selectedSite!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Confirm Save',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
          ),
          content: Text(
            'Are you sure you want to save mapping for site "$selectedSite" with supervisor "$selectedSupervisor" ($selectedSupervisorId)?',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      final docId = _siteToDocId[selectedSite] ?? selectedSite!;

      final mappingData = {
        'site': selectedSite,
        'siteName': selectedSite,
        'projectName': projectName ?? '',
        'location': locationController.text.trim(),
        'Supervisor ID': selectedSupervisorId ?? '',
        'supervisorId': selectedSupervisorId ?? '',
        'supervisor': selectedSupervisor ?? '',
        'supervisorName': selectedSupervisor ?? '',
        'projectStage': selectedProjectStage ?? '',
        'siteComments': commentsController.text.trim(),
        'startDate': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '',
        'endDate': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '',
        'Joined On': joinedDate != null ? DateFormat('yyyy-MM-dd').format(joinedDate!) : '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('siteSupervisorMap')
          .doc(docId)
          .set(mappingData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site-Supervisor mapping saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _docCache[docId] = mappingData;

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
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
                          color: isEntrySelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: isEntrySelected ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MAPPING ENTRY',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: isEntrySelected ? Colors.white : const Color(0xFF0A183D),
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
                          color: !isEntrySelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: !isEntrySelected ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MAPPING INFO',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: !isEntrySelected ? Colors.white : const Color(0xFF0A183D),
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
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: isEntrySelected
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: _buildEntrySection(),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                controller: TextEditingController(text: projectName ?? ''),
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
                controller: TextEditingController(text: selectedSupervisor ?? ''),
                hint: 'Auto-filled from ID selection',
                readOnly: true,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Project Stage',
                controller: TextEditingController(text: selectedProjectStage ?? ''),
                hint: 'Auto-filled from site selection',
                readOnly: true,
                icon: Icons.timeline_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                label: 'Site',
                controller: TextEditingController(text: selectedSite ?? ''),
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
        const Text(
          'Select Site *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selectedSite,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select Site',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.location_on_rounded,
                  color: brandIconColor,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
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
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor ID *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: (_supervisorList.any((s) => s['id'] == selectedSupervisorId))
                ? selectedSupervisorId
                : null,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select Supervisor ID',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.badge_rounded,
                  color: brandIconColor,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
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
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 20),
                    )
                  : null,
              border: InputBorder.none,
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
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
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
      final site = (data['site'] ?? data['siteName'] ?? data['siteId'] ?? '').toString().toLowerCase();
      final supervisor = (data['supervisor'] ?? data['supervisorName'] ?? data['FullName'] ?? '').toString().toLowerCase();
      final supervisorId = (data['Supervisor ID'] ?? data['supervisorId'] ?? data['SupervisorId'] ?? '').toString().toLowerCase();
      final projectNameVal = (data['projectName'] ?? data['project'] ?? '').toString().toLowerCase();
      final projectStage = (data['projectStage'] ?? data['stage'] ?? '').toString().toLowerCase();
      final location = (data['location'] ?? data['address'] ?? '').toString().toLowerCase();

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
    final totalPages = (totalItems / _infoItemsPerPage).ceil().clamp(1, 999999);
    if (_infoCurrentPage > totalPages) {
      _infoCurrentPage = totalPages;
    }
    final startIndex = (totalItems == 0) ? 0 : (_infoCurrentPage - 1) * _infoItemsPerPage;
    final endIndex = (startIndex + _infoItemsPerPage).clamp(0, totalItems);
    final paginatedEntries = filteredEntries.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Live Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 44,
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
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _infoSearchQuery = val;
                  _infoCurrentPage = 1;
                });
              },
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A183D),
              ),
              decoration: InputDecoration(
                hintText: 'Search mapping by site, supervisor, project, stage...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                suffixIcon: _infoSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          setState(() {
                            _infoSearchQuery = '';
                            _infoCurrentPage = 1;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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

                    final siteName = data['site'] ?? data['siteName'] ?? data['siteId'] ?? entry.key;
                    final supervisorName = data['supervisor'] ?? data['supervisorName'] ?? data['FullName'] ?? 'Not Assigned';
                    final supervisorId = data['Supervisor ID'] ?? data['supervisorId'] ?? data['SupervisorId'] ?? '';
                    final pName = data['projectName'] ?? data['project'] ?? '';
                    final pStage = data['projectStage'] ?? data['stage'] ?? '';
                    final loc = data['location'] ?? data['address'] ?? '';
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
                            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
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
                                child: Icon(Icons.location_on_rounded, color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      siteName,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
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
                              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'Supervisor: ',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                              Expanded(
                                child: Text(
                                  supervisorName + (supervisorId.isNotEmpty ? ' ($supervisorId)' : ''),
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (loc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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
                                const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Duration: ${sDate.isEmpty ? 'N/A' : sDate} to ${eDate.isEmpty ? 'N/A' : eDate}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
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
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.last_page_rounded,
                  size: 18,
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
                tooltip: 'Last Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
