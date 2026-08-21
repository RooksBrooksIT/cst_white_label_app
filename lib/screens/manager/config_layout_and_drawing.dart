import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class LayoutAndDrawingsPage extends StatefulWidget {
  const LayoutAndDrawingsPage({super.key});

  @override
  State<LayoutAndDrawingsPage> createState() => _LayoutAndDrawingsPageState();
}

class _LayoutAndDrawingsPageState extends State<LayoutAndDrawingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Color get primaryColor => Theme.of(context).primaryColor;

  // ── Form Controllers & State ───────────────────────────────────────────────
  String? _selectedSiteId;
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectPhaseController = TextEditingController();
  final TextEditingController _docNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  List<Map<String, String>> _uploadedDocuments = [];
  List<QueryDocumentSnapshot> _existingConfigDocs = [];
  String? _selectedConfigId;
  String? _pickedFileName;
  bool _isSaving = false;

  // ── Reference Data ────────────────────────────────────────────────────────
  List<Map<String, String>> _allSites = [];
  bool _isLoadingSites = true;

  // ── Directory Tab State ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _allSavedDrawings = [];
  bool _isLoadingDrawings = false;
  String _drawingSearchQuery = '';
  final TextEditingController _drawingSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _fetchAllDrawings();
      }
    });
    _loadInitialSites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supervisorNameController.dispose();
    _projectNameController.dispose();
    _projectPhaseController.dispose();
    _docNameController.dispose();
    _purposeController.dispose();
    _drawingSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final sites = await _fetchAllSitesData();
      if (mounted) {
        setState(() {
          _allSites = sites;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSites = false);
      }
    }
  }

  Future<List<Map<String, String>>> _fetchAllSitesData() async {
    try {
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();

      final mapSnapshot = await FirestoreService.getCollection('siteSupervisorMap').get();
      final Map<String, Map<String, dynamic>> supervisorMap = {};
      for (var doc in mapSnapshot.docs) {
        final data = doc.data();
        final sId = data['site']?.toString() ?? doc.id;
        if (sId.isNotEmpty) {
          supervisorMap[sId] = data;
        }
      }

      final projectsSnapshot = await FirestoreService.getCollection('projects').get();
      final Map<String, String> projectNames = {};
      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        final sId = data['siteId']?.toString();
        final pName = data['projectName']?.toString();
        if (sId != null && sId.isNotEmpty && pName != null && pName.isNotEmpty) {
          projectNames[sId] = pName;
        }
      }

      final Set<String> uniqueSiteIds = {};
      final List<Map<String, String>> result = [];

      for (var doc in sitesSnapshot.docs) {
        final sId = doc.id.trim();
        if (sId.isNotEmpty && !uniqueSiteIds.contains(sId)) {
          uniqueSiteIds.add(sId);
          final mapping = supervisorMap[sId];
          result.add({
            'site': sId,
            'supervisor': mapping?['supervisor']?.toString() ?? '',
            'projectName': mapping?['projectName']?.toString() ??
                projectNames[sId] ??
                doc.data()['siteName']?.toString() ??
                '',
            'projectStage': mapping?['projectStage']?.toString() ?? '',
          });
        }
      }

      // Also supplement with any from siteSupervisorMap
      for (var entry in supervisorMap.entries) {
        final sId = entry.key;
        if (!uniqueSiteIds.contains(sId)) {
          uniqueSiteIds.add(sId);
          final mapping = entry.value;
          result.add({
            'site': sId,
            'supervisor': mapping['supervisor']?.toString() ?? '',
            'projectName': mapping['projectName']?.toString() ?? projectNames[sId] ?? '',
            'projectStage': mapping['projectStage']?.toString() ?? '',
          });
        }
      }

      result.sort((a, b) => (a['site'] ?? '').compareTo(b['site'] ?? ''));
      return result;
    } catch (e) {
      debugPrint('Error fetching sites: $e');
      return [];
    }
  }

  void _onSiteSelected(String? siteId) async {
    setState(() {
      _selectedSiteId = siteId;
      _uploadedDocuments.clear();
      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
      _existingConfigDocs = [];
      _selectedConfigId = null;
    });

    if (siteId == null || siteId.isEmpty) {
      _supervisorNameController.clear();
      _projectNameController.clear();
      _projectPhaseController.clear();
      return;
    }

    final siteData = _allSites.firstWhere(
      (site) => site['site'] == siteId,
      orElse: () => {'supervisor': '', 'projectName': '', 'projectStage': ''},
    );

    _supervisorNameController.text = siteData['supervisor'] ?? '';
    _projectNameController.text = siteData['projectName'] ?? '';
    _projectPhaseController.text = siteData['projectStage'] ?? '';

    // Fetch previous drawing configs
    _fetchExistingConfigs(siteId);
  }

  Future<void> _fetchExistingConfigs(String siteId) async {
    try {
      final snapshot = await FirestoreService.getCollection('siteDrawings')
          .where('siteId', isEqualTo: siteId)
          .get();

      if (mounted) {
        setState(() {
          _existingConfigDocs = snapshot.docs;
          _selectedConfigId = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching configs: $e');
    }
  }

  void _loadConfiguration(String docId) {
    final doc = _existingConfigDocs.firstWhere((d) => d.id == docId);
    final data = doc.data() as Map<String, dynamic>;

    setState(() {
      _supervisorNameController.text = data['supervisorName']?.toString() ?? _supervisorNameController.text;
      _projectNameController.text = data['projectName']?.toString() ?? _projectNameController.text;
      _projectPhaseController.text = data['projectPhase']?.toString() ?? _projectPhaseController.text;

      final siteDocs = data['siteDocs'] as List<dynamic>? ?? [];
      _uploadedDocuments = siteDocs.map((item) {
        final docMap = Map<String, dynamic>.from(item);
        return {
          'Doc Name': docMap['docName']?.toString() ?? '',
          'Purpose': docMap['purpose']?.toString() ?? 'Previously Saved',
          'Upload Flag': 'Uploaded',
          'File Name': docMap['docUrl']?.toString() ?? '',
        };
      }).toList();
      _selectedConfigId = docId;
    });

    AppTheme.showSuccessToast(context, 'Loaded configuration: ${docId.split('_').last}');
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFileName = file.name;
          if (_docNameController.text.trim().isEmpty) {
            final dotIdx = file.name.lastIndexOf('.');
            _docNameController.text = dotIdx > 0 ? file.name.substring(0, dotIdx) : file.name;
          }
        });
        if (mounted) {
          AppTheme.showSuccessToast(context, 'Selected: ${file.name}');
        }
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Error picking file: $e');
      }
    }
  }

  void _addDocumentToStaging() {
    final docName = _docNameController.text.trim();
    final purpose = _purposeController.text.trim();

    if (docName.isEmpty) {
      AppTheme.showErrorToast(context, 'Please enter a Document Name');
      return;
    }
    if (purpose.isEmpty) {
      AppTheme.showErrorToast(context, 'Please enter the Purpose / Description');
      return;
    }

    setState(() {
      _uploadedDocuments.add({
        'Doc Name': docName,
        'Purpose': purpose,
        'Upload Flag': _pickedFileName != null ? 'Uploaded' : 'Pending',
        'File Name': _pickedFileName ?? 'Not attached',
      });
      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
    });

    AppTheme.showSuccessToast(context, 'Added "$docName" to staging list');
  }

  bool get _canSave {
    if (_selectedSiteId == null || _selectedSiteId!.trim().isEmpty) return false;
    if (_projectNameController.text.trim().isEmpty) return false;
    if (_uploadedDocuments.isEmpty) return false;
    return true;
  }

  Future<void> _saveDocuments() async {
    if (!_canSave) {
      AppTheme.showErrorToast(context, 'Please select a Site and add at least one document');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
      final docId = '${_selectedSiteId}_$formattedDate';
      final docRef = FirestoreService.getCollection('siteDrawings').doc(docId);

      List<dynamic> existingSiteDocs = [];
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null && docSnapshot.data()!["siteDocs"] != null) {
        existingSiteDocs = List.from(docSnapshot.data()!["siteDocs"]);
      }

      final newSiteDocs = _uploadedDocuments.map((doc) {
        return {
          "docName": doc['Doc Name'] ?? '',
          "purpose": doc['Purpose'] ?? '',
          "docUrl": doc['File Name'] ?? '',
          "uploadDate": DateTime.now().toIso8601String(),
        };
      }).toList();

      final combinedSiteDocs = [...existingSiteDocs, ...newSiteDocs];

      await docRef.set({
        "siteId": _selectedSiteId,
        "projectName": _projectNameController.text.trim(),
        "supervisorName": _supervisorNameController.text.trim(),
        "projectPhase": _projectPhaseController.text.trim(),
        "siteDocs": combinedSiteDocs,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Drawings configuration successfully saved for Site $_selectedSiteId!',
        );
      }

      _resetForm();
      _fetchAllDrawings();
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to save drawings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _uploadedDocuments.clear();
      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
      _selectedSiteId = null;
      _supervisorNameController.clear();
      _projectNameController.clear();
      _projectPhaseController.clear();
      _existingConfigDocs.clear();
      _selectedConfigId = null;
    });
  }

  Future<void> _fetchAllDrawings() async {
    setState(() => _isLoadingDrawings = true);
    try {
      final snapshot = await FirestoreService.getCollection('siteDrawings').get();
      final List<Map<String, dynamic>> list = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        list.add({
          'docId': doc.id,
          'siteId': data['siteId'] ?? doc.id.split('_').first,
          'projectName': data['projectName'] ?? '',
          'supervisorName': data['supervisorName'] ?? '',
          'projectPhase': data['projectPhase'] ?? '',
          'siteDocs': data['siteDocs'] is List ? data['siteDocs'] : [],
        });
      }

      if (mounted) {
        setState(() {
          _allSavedDrawings = list;
          _isLoadingDrawings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDrawings = false);
      }
    }
  }

  Future<void> _deleteDrawingSet(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Drawing Set?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete the configuration "$docId"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.getCollection('siteDrawings').doc(docId).delete();
        if (mounted) {
          AppTheme.showSuccessToast(context, 'Drawing set deleted');
          _fetchAllDrawings();
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showErrorToast(context, 'Failed to delete: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Layout & Construction Drawings',
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: () {
              _loadInitialSites();
              _fetchAllDrawings();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Segmented Pill Navigation ────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      _buildTabItem(0, 'UPLOAD & CONFIGURE', Icons.upload_file_rounded),
                      _buildTabItem(1, 'DRAWINGS DIRECTORY', Icons.folder_copy_rounded),
                    ],
                  );
                },
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUploadConfigureTab(isMobile, darkAccent),
                  _buildDirectoryTab(isMobile, darkAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: UPLOAD & CONFIGURE
  // ---------------------------------------------------------------------------

  Widget _buildUploadConfigureTab(bool isMobile, Color darkAccent) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Site & Project Details Card ────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
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
                          child: Icon(Icons.apartment_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Project & Site Context',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkAccent,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1),
                    ),

                    // Site Selector
                    _buildFieldLabel('Select Site ID *', Icons.location_on_rounded),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _isLoadingSites
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSiteId,
                                isExpanded: true,
                                hint: const Text(
                                  'Choose site for drawings...',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                ),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                items: _allSites.map((s) {
                                  final sId = s['site'] ?? '';
                                  final pName = s['projectName'] ?? '';
                                  return DropdownMenuItem<String>(
                                    value: sId,
                                    child: Text(
                                      pName.isNotEmpty ? '$sId - $pName' : sId,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _onSiteSelected,
                              ),
                            ),
                    ),

                    // Load saved drawing configuration
                    if (_existingConfigDocs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildFieldLabel('Load Previous Configuration', Icons.history_rounded),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedConfigId,
                            isExpanded: true,
                            hint: const Text(
                              'Select a saved drawing set to load...',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: _existingConfigDocs.map((doc) {
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  'Drawing Set: ${doc.id}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _loadConfiguration(val);
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Auto-populated Fields
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Project Name', Icons.business_rounded),
                              const SizedBox(height: 6),
                              _buildReadOnlyBox(_projectNameController.text, 'Auto-filled project'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Supervisor', Icons.badge_rounded),
                              const SizedBox(height: 6),
                              _buildReadOnlyBox(_supervisorNameController.text, 'Auto-filled supervisor'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Project Stage / Phase', Icons.timeline_rounded),
                    const SizedBox(height: 6),
                    _buildReadOnlyBox(_projectPhaseController.text, 'Stage / Phase'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. Add Documents Card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.note_add_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Attach Drawing Document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkAccent,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1),
                    ),

                    _buildFieldLabel('Document Name / Title *', Icons.title_rounded),
                    const SizedBox(height: 6),
                    _buildInputContainer(
                      child: TextField(
                        controller: _docNameController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Structural Ground Floor Layout Plan',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Purpose / Description *', Icons.description_rounded),
                    const SizedBox(height: 6),
                    _buildInputContainer(
                      child: TextField(
                        controller: _purposeController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: 'e.g. For foundation reinforcement execution',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // File attachment row
                    if (_pickedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pickedFileName!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _pickedFileName = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file_rounded, size: 18),
                              label: Text(
                                _pickedFileName == null ? 'Browse File' : 'Change File',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _addDocumentToStaging,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Add To List',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Supported formats: PDF, DOC, DOCX, PNG, JPG',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. Staged Documents Tray ──────────────────────────────────
              if (_uploadedDocuments.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Staged Drawings (${_uploadedDocuments.length})',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkAccent),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'READY TO SAVE',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _uploadedDocuments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = _uploadedDocuments[index];
                          final isUploaded = doc['Upload Flag'] == 'Uploaded';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isUploaded ? const Color(0xFF10B981) : Colors.amber)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isUploaded ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                                    size: 18,
                                    color: isUploaded ? const Color(0xFF047857) : Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['Doc Name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: darkAccent,
                                        ),
                                      ),
                                      Text(
                                        doc['Purpose'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if ((doc['File Name'] ?? '').isNotEmpty &&
                                          doc['File Name'] != 'Not attached')
                                        Text(
                                          'File: ${doc['File Name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF94A3B8),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _uploadedDocuments.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── 4. Main Submit & Reset Action ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDocuments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'SAVE DRAWINGS CONFIG',
                                    style: TextStyle(
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
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _resetForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: DRAWINGS REPOSITORY (DIRECTORY)
  // ---------------------------------------------------------------------------

  Widget _buildDirectoryTab(bool isMobile, Color darkAccent) {
    if (_isLoadingDrawings) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _allSavedDrawings.where((set) {
      final site = (set['siteId'] ?? '').toString().toLowerCase();
      final project = (set['projectName'] ?? '').toString().toLowerCase();
      final sup = (set['supervisorName'] ?? '').toString().toLowerCase();
      final q = _drawingSearchQuery.toLowerCase().trim();

      if (q.isEmpty) return true;
      if (site.contains(q) || project.contains(q) || sup.contains(q)) return true;

      final docs = set['siteDocs'] as List<dynamic>? ?? [];
      for (var d in docs) {
        final name = (d['docName'] ?? '').toString().toLowerCase();
        final purpose = (d['purpose'] ?? '').toString().toLowerCase();
        if (name.contains(q) || purpose.contains(q)) return true;
      }
      return false;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAllDrawings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _drawingSearchController,
                onChanged: (val) => setState(() => _drawingSearchQuery = val),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search site, project, document name...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                  suffixIcon: _drawingSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _drawingSearchController.clear();
                            setState(() => _drawingSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.folder_open_rounded,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _drawingSearchQuery.isEmpty ? 'No Drawings Registered' : 'No Matching Drawings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _drawingSearchQuery.isEmpty
                          ? 'Upload drawings and layouts for sites in the Upload tab.'
                          : 'Try adjusting your search terms.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final set = filtered[index];
                  final docs = set['siteDocs'] as List<dynamic>? ?? [];

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.03),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                set['siteId'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                set['projectName']?.toString().isNotEmpty == true
                                    ? set['projectName']
                                    : 'Site ${set['siteId']}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: darkAccent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteDrawingSet(set['docId']),
                            ),
                          ],
                        ),
                        if ((set['supervisorName'] ?? '').isNotEmpty || (set['projectPhase'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Supervisor: ${set['supervisorName'] ?? 'N/A'} • Stage: ${set['projectPhase'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Document Items in Set
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: docs.map((d) {
                            final name = d['docName'] ?? 'Document';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _buildReadOnlyBox(String text, String placeholder) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text.isNotEmpty ? text : placeholder,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
