import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';


class LayoutAndDrawingsPage extends StatefulWidget {
  const LayoutAndDrawingsPage({super.key});

  @override
  State<LayoutAndDrawingsPage> createState() => _LayoutAndDrawingsPageState();
}

class _LayoutAndDrawingsPageState extends State<LayoutAndDrawingsPage> {
  String? selectedSiteId;
  final TextEditingController supervisorNameController =
      TextEditingController();
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController projectPhaseController = TextEditingController();
  final TextEditingController docNameController = TextEditingController();
  final TextEditingController purposeController = TextEditingController();

  List<Map<String, String>> uploadedDocuments = [];
  List<QueryDocumentSnapshot> existingConfigDocs = [];
  String? selectedConfigId;

  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get accentColor => Theme.of(context).colorScheme.primary;
  final Color backgroundColor = const Color(0xFFF5F7FA);

  List<Map<String, String>> allSites = [];

  Future<List<Map<String, String>>> fetchAllSites() async {
    try {
      final sitesSnapshot = await FirestoreService.getCollection('Site').get();

      final mapSnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).get();
      final Map<String, Map<String, dynamic>> supervisorMap = {};
      for (var doc in mapSnapshot.docs) {
        final data = doc.data();
        final sId = data['site']?.toString() ?? doc.id;
        if (sId.isNotEmpty) {
          supervisorMap[sId] = data;
        }
      }

      final projectsSnapshot = await FirestoreService.getCollection(
        'projects',
      ).get();
      final Map<String, String> projectNames = {};
      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        final sId = data['siteId']?.toString();
        final pName = data['projectName']?.toString();
        if (sId != null &&
            sId.isNotEmpty &&
            pName != null &&
            pName.isNotEmpty) {
          projectNames[sId] = pName;
        }
      }

      return sitesSnapshot.docs.map<Map<String, String>>((doc) {
        final sId = doc.id;
        final mapping = supervisorMap[sId];

        return {
          'site': sId,
          'supervisor': mapping?['supervisor']?.toString() ?? 'Not Assigned',
          'projectName':
              mapping?['projectName'] ?? projectNames[sId] ?? 'Not Assigned',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all sites: $e');
      return [];
    }
  }

  void setSupervisorAndProject(String? siteId) async {
    final siteData = allSites.firstWhere(
      (site) => site['site'] == siteId,
      orElse: () => {'supervisor': '', 'projectName': ''},
    );
    supervisorNameController.text = siteData['supervisor'] ?? '';
    projectNameController.text = siteData['projectName'] ?? '';

    if (siteId != null && siteId.isNotEmpty) {
      final query = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('site', isEqualTo: siteId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        projectPhaseController.text = data['projectStage']?.toString() ?? '';
      } else {
        projectPhaseController.text = '';
      }
    } else {
      projectPhaseController.text = '';
    }
    setState(() {});
  }

  Future<void> _fetchExistingConfigs(String siteId) async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'siteDrawings',
      ).where('siteId', isEqualTo: siteId).get();
      setState(() {
        existingConfigDocs = snapshot.docs;
        selectedConfigId = null;
      });
    } catch (e) {
      debugPrint('Error fetching existing configs: $e');
    }
  }

  void _loadConfiguration(String docId) {
    final doc = existingConfigDocs.firstWhere((d) => d.id == docId);
    final data = doc.data() as Map<String, dynamic>;

    setState(() {
      supervisorNameController.text = data['supervisorName']?.toString() ?? '';
      projectNameController.text = data['projectName']?.toString() ?? '';
      projectPhaseController.text = data['projectPhase']?.toString() ?? '';

      final siteDocs = data['siteDocs'] as List<dynamic>? ?? [];
      uploadedDocuments = siteDocs.map((item) {
        final docMap = Map<String, dynamic>.from(item);
        return {
          'Doc Name': docMap['docName']?.toString() ?? '',
          'Purpose': docMap['purpose']?.toString() ?? 'Previously Saved',
          'Upload Flag': 'Uploaded',
          'File Name': docMap['docUrl']?.toString() ?? '',
        };
      }).toList();
      selectedConfigId = docId;
    });
  }

  Future<void> _uploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      final ext = file.extension?.toLowerCase() ?? '';

      if (ext == 'pdf' || ext == 'doc' || ext == 'docx') {
        setState(() {
          uploadedDocuments.add({
            'Doc Name': docNameController.text,
            'Purpose': purposeController.text,
            'Upload Flag': 'Uploaded',
            'File Name': file.name,
          });

          docNameController.clear();
          purposeController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Document uploaded successfully!'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Only DOC and PDF files are allowed!'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addDocument() async {
    final docName = docNameController.text.trim();
    final purpose = purposeController.text.trim();
    if (docName.isEmpty || purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in both Doc Name and Purpose.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() {
      uploadedDocuments.add({
        'Doc Name': docName,
        'Purpose': purpose,
        'Upload Flag': 'No',
      });
      docNameController.clear();
      purposeController.clear();
    });
  }

  bool get _canSave {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) return false;
    if (supervisorNameController.text.trim().isEmpty) return false;
    if (projectNameController.text.trim().isEmpty) return false;
    if (uploadedDocuments.isEmpty) return false;
    for (final doc in uploadedDocuments) {
      if ((doc['Doc Name'] ?? '').trim().isEmpty ||
          (doc['Purpose'] ?? '').trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      title: 'Layout and Drawings',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site & Project Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
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
                        'Select Site ID *',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<Map<String, String>>>(
                        future: fetchAllSites(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Color(0xFFF87171)),
                            );
                          }

                          allSites = snapshot.data ?? [];
                          final sites = allSites
                              .map((site) => site['site']!)
                              .toList();
                          return Container(
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
                              value: selectedSiteId,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              decoration: InputDecoration(
                                hintText: 'Select Site ID',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                              items: sites
                                  .map(
                                    (site) => DropdownMenuItem(
                                      value: site,
                                      child: Text(
                                        site,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0A183D),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedSiteId = value;
                                  uploadedDocuments.clear();
                                  docNameController.clear();
                                  purposeController.clear();
                                  supervisorNameController.clear();
                                  projectNameController.clear();
                                  projectPhaseController.clear();
                                  existingConfigDocs = [];
                                  selectedConfigId = null;
                                });
                                setSupervisorAndProject(value);
                                if (value != null) {
                                  _fetchExistingConfigs(value);
                                }
                              },
                            ),
                          );
                        },
                      ),
                      if (existingConfigDocs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Load Previous Configuration',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                            value: selectedConfigId,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            decoration: InputDecoration(
                              hintText: 'Select a saved drawing set',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.history_rounded,
                                color: Color(0xFF0A183D),
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF0A183D),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                            items: existingConfigDocs.map((doc) {
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  doc.id.split('_').last,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0A183D),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _loadConfiguration(value);
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _readonlyTextField(
                        controller: supervisorNameController,
                        label: 'Supervisor Name',
                        fillColor: Colors.white,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      _readonlyTextField(
                        controller: projectNameController,
                        label: 'Project Name',
                        fillColor: Colors.white,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      _readonlyTextField(
                        controller: projectPhaseController,
                        label: 'Project Phase',
                        fillColor: Colors.white,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),

                // Document Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
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
                        'Document Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _editableTextField(
                        controller: docNameController,
                        label: 'Doc Name',
                        enabled:
                            selectedSiteId != null && selectedSiteId!.isNotEmpty,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      _editableTextField(
                        controller: purposeController,
                        label: 'Purpose',
                        maxLines: 3,
                        enabled:
                            selectedSiteId != null && selectedSiteId!.isNotEmpty,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed:
                                    (selectedSiteId == null ||
                                        selectedSiteId!.isEmpty)
                                    ? null
                                    : _uploadDocument,
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: const Text(
                                  'Browse',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  disabledBackgroundColor: const Color(0xFF1E293B),
                                  disabledForegroundColor: const Color(0xFF94A3B8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: (selectedSiteId == null ||
                                              selectedSiteId!.isEmpty)
                                          ? const Color(0xFF334155)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed:
                                    (selectedSiteId == null ||
                                        selectedSiteId!.isEmpty)
                                    ? null
                                    : _addDocument,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  disabledBackgroundColor: const Color(0xFF1E293B),
                                  disabledForegroundColor: const Color(0xFF94A3B8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: (selectedSiteId == null ||
                                              selectedSiteId!.isEmpty)
                                          ? const Color(0xFF334155)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Note: Only DOC and PDF files are allowed for upload.',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontStyle: FontStyle.italic,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Uploaded Documents Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                        'Uploaded Documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A183D),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DataTable(
                              columnSpacing: 24,
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF05112E),
                              ),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              dataTextStyle: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13.5,
                              ),
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 54,
                              columns: const [
                                DataColumn(label: Text('Doc Name')),
                                DataColumn(label: Text('Purpose')),
                                DataColumn(label: Text('Uploaded')),
                                DataColumn(
                                  label: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFF87171),
                                    size: 20,
                                  ),
                                ),
                              ],
                              rows: uploadedDocuments.isEmpty
                                  ? [
                                      const DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              'No documents added',
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text('')),
                                          DataCell(Text('')),
                                          DataCell(SizedBox()),
                                        ],
                                      ),
                                    ]
                                  : List.generate(uploadedDocuments.length, (index) {
                                      final doc = uploadedDocuments[index];
                                      final uploaded =
                                          doc['Upload Flag'] == 'Uploaded';
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              doc['Doc Name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              doc['Purpose'] ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: uploaded
                                                    ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: uploaded
                                                      ? const Color(0xFF22C55E)
                                                      : const Color(0xFFEF4444),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                uploaded ? 'Uploaded' : 'Pending',
                                                style: TextStyle(
                                                  color: uploaded
                                                      ? const Color(0xFF22C55E)
                                                      : const Color(0xFFEF4444),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              splashRadius: 20,
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFF87171),
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  uploadedDocuments.removeAt(index);
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSave ? _saveDocuments : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
                      disabledBackgroundColor: const Color(0xFF0B1942),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cancelDocuments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readonlyTextField({
    required TextEditingController controller,
    required String label,
    required Color fillColor,
    required Color primaryColor,
  }) {
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
        const SizedBox(height: 6),
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
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
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

  Widget _editableTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    required bool enabled,
    required Color primaryColor,
  }) {
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
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            enabled: enabled,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
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

  Future<void> _saveDocuments() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) return;
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    final docId = '${selectedSiteId}_$formattedDate';
    final docRef = FirestoreService.getCollection('siteDrawings').doc(docId);

    List<dynamic> existingSiteDocs = [];
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists &&
        docSnapshot.data() != null &&
        docSnapshot.data()!["siteDocs"] != null) {
      existingSiteDocs = List.from(docSnapshot.data()!["siteDocs"]);
    }

    final newSiteDocs = uploadedDocuments
        .map(
          (doc) => {
            "docName": doc['Doc Name'] ?? '',
            "docUrl": doc['File Name'] ?? '',
          },
        )
        .toList();

    final combinedSiteDocs = [...existingSiteDocs, ...newSiteDocs];

    await docRef.set({
      "projectName": projectNameController.text,
      "projectPhase": projectPhaseController.text,
      "siteId": selectedSiteId,
      "supervisorName": supervisorNameController.text,
      "siteDocs": combinedSiteDocs,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Documents saved!'),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _cancelDocuments() {
    setState(() {
      uploadedDocuments.clear();
      docNameController.clear();
      purposeController.clear();
      selectedSiteId = null;
      supervisorNameController.clear();
      projectNameController.clear();
      projectPhaseController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All entries cleared.'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    supervisorNameController.dispose();
    projectNameController.dispose();
    projectPhaseController.dispose();
    docNameController.dispose();
    purposeController.dispose();
    super.dispose();
  }
}
