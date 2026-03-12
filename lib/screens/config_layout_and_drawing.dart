import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final Color primaryColor = const Color(0xFF0b3470);
  final Color accentColor = const Color(0xFF073060);
  final Color backgroundColor = const Color(0xFFF5F7FA);

  List<Map<String, String>> allSites = [];

  Future<List<Map<String, String>>> fetchAllSites() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
        .get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return {
            'site': data['site']?.toString() ?? '',
            'supervisor': data['supervisor']?.toString() ?? '',
            'projectName': data['projectName']?.toString() ?? '',
          };
        })
        .where((site) => site['site']!.isNotEmpty)
        .toList();
  }

  void setSupervisorAndProject(String? siteId) async {
    final siteData = allSites.firstWhere(
      (site) => site['site'] == siteId,
      orElse: () => {'supervisor': '', 'projectName': ''},
    );
    supervisorNameController.text = siteData['supervisor'] ?? '';
    projectNameController.text = siteData['projectName'] ?? '';

    if (siteId != null && siteId.isNotEmpty) {
      final query = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Layout and Drawings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        shadowColor: primaryColor.withOpacity(0.6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
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
                            style: const TextStyle(color: Colors.red),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text(
                            'No sites found',
                            style: TextStyle(color: Colors.black54),
                          );
                        }
                        allSites = snapshot.data!;
                        final sites = allSites
                            .map((site) => site['site']!)
                            .toList();
                        return DropdownButtonFormField<String>(
                          value: selectedSiteId,
                          decoration: InputDecoration(
                            labelText: 'Site ID',
                            labelStyle: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          items: sites
                              .map(
                                (site) => DropdownMenuItem(
                                  value: site,
                                  child: Text(
                                    site,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedSiteId = value);
                            setSupervisorAndProject(value);
                          },
                          hint: const Text('Select Site ID'),
                          borderRadius: BorderRadius.circular(14),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: primaryColor,
                          ),
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _readonlyTextField(
                      controller: supervisorNameController,
                      label: 'Supervisor Name',
                      fillColor: Colors.grey.shade100,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 24),
                    _readonlyTextField(
                      controller: projectNameController,
                      label: 'Project Name',
                      fillColor: Colors.grey.shade100,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 24),
                    _readonlyTextField(
                      controller: projectPhaseController,
                      label: 'Project Phase',
                      fillColor: Colors.grey.shade100,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _editableTextField(
                      controller: docNameController,
                      label: 'Doc Name',
                      enabled:
                          selectedSiteId != null && selectedSiteId!.isNotEmpty,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 20),
                    _editableTextField(
                      controller: purposeController,
                      label: 'Purpose',
                      maxLines: 3,
                      enabled:
                          selectedSiteId != null && selectedSiteId!.isNotEmpty,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (selectedSiteId == null ||
                                    selectedSiteId!.isEmpty)
                                ? null
                                : _uploadDocument,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Browse'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 5,
                              shadowColor: primaryColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                (selectedSiteId == null ||
                                    selectedSiteId!.isEmpty)
                                ? null
                                : _addDocument,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 5,
                              shadowColor: accentColor.withOpacity(0.7),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Note: Only DOC and PDF files are allowed for upload.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploaded Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowColor: WidgetStateProperty.all(
                          primaryColor.withOpacity(0.12),
                        ),
                        headingTextStyle: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        dataRowHeight: 54,
                        columns: [
                          const DataColumn(label: Text('Doc Name')),
                          const DataColumn(label: Text('Purpose')),
                          const DataColumn(label: Text('Uploaded')),
                          DataColumn(
                            label: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                          ),
                        ],
                        rows: uploadedDocuments.isEmpty
                            ? [
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        'No documents added',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(SizedBox()),
                                  ],
                                ),
                              ]
                            : List.generate(uploadedDocuments.length, (index) {
                                final doc = uploadedDocuments[index];
                                final uploaded =
                                    doc['Upload Flag'] == 'Uploaded';
                                return DataRow(
                                  color:
                                      WidgetStateProperty.resolveWith<Color?>(
                                        (states) => index.isEven
                                            ? Colors.grey.shade50
                                            : Colors.white,
                                      ),
                                  cells: [
                                    DataCell(
                                      Text(
                                        doc['Doc Name'] ?? '',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        doc['Purpose'] ?? '',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: uploaded
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: uploaded
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Text(
                                          uploaded ? 'Uploaded' : 'Pending',
                                          style: TextStyle(
                                            color: uploaded
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        splashRadius: 21,
                                        icon: Icon(
                                          Icons.delete_forever,
                                          color: Colors.red.shade700,
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _canSave ? _saveDocuments : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: primaryColor.withOpacity(0.8),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: _cancelDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black45,
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: Colors.red.shade900,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _editableTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    required bool enabled,
    required Color primaryColor,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: enabled ? Colors.black87 : Colors.grey.shade600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2.3),
        ),
      ),
    );
  }

  Future<void> _saveDocuments() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) return;
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    final docId = '${selectedSiteId}_$formattedDate';
    final docRef = FirebaseFirestore.instance
        .collection('siteDrawings')
        .doc(docId);

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
