import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/app_storage_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/screens/common/web_view_screen.dart';

/// Model representing an individual drawing document item
class DrawingDocItem {
  String docId;
  String docName;
  String purpose;
  String fileName;
  PlatformFile? platformFile;
  String? fileUrl;
  String? storagePath;
  String fileType;
  int fileSizeBytes;
  String fileSize;
  String uploadDate;
  bool isCloudUploaded;

  DrawingDocItem({
    required this.docId,
    required this.docName,
    required this.purpose,
    required this.fileName,
    this.platformFile,
    this.fileUrl,
    this.storagePath,
    this.fileType = '',
    this.fileSizeBytes = 0,
    this.fileSize = '',
    this.uploadDate = '',
    this.isCloudUploaded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'docName': docName,
      'purpose': purpose,
      'fileName': fileName,
      'docUrl': (fileUrl != null && fileUrl!.isNotEmpty) ? fileUrl : fileName,
      'fileUrl': fileUrl ?? '',
      'storagePath': storagePath ?? '',
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'fileSize': fileSize,
      'uploadDate': uploadDate.isNotEmpty ? uploadDate : DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'uploadedAt': DateTime.now().toIso8601String(),
      'isCloudUploaded': (fileUrl != null && fileUrl!.isNotEmpty),
    };
  }

  factory DrawingDocItem.fromMap(Map<String, dynamic> map) {
    final fUrl = map['fileUrl']?.toString() ?? map['docUrl']?.toString() ?? '';
    final isCloud = fUrl.startsWith('http://') || fUrl.startsWith('https://');
    final fName = map['fileName']?.toString() ?? (isCloud ? 'Cloud Document' : (map['docUrl']?.toString() ?? ''));

    return DrawingDocItem(
      docId: map['docId']?.toString() ?? 'DOC_${DateTime.now().millisecondsSinceEpoch}',
      docName: map['docName']?.toString() ?? '',
      purpose: map['purpose']?.toString() ?? '',
      fileName: fName,
      fileUrl: isCloud ? fUrl : null,
      storagePath: map['storagePath']?.toString() ?? '',
      fileType: map['fileType']?.toString() ?? '',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      fileSize: map['fileSize']?.toString() ?? '',
      uploadDate: map['uploadDate']?.toString() ?? '',
      isCloudUploaded: isCloud,
    );
  }
}

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

  final List<DrawingDocItem> _stagedDocuments = [];
  List<QueryDocumentSnapshot> _existingConfigDocs = [];
  String? _selectedConfigId;
  PlatformFile? _pickedPlatformFile;
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      _stagedDocuments.clear();
      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
      _pickedPlatformFile = null;
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
      _supervisorNameController.text =
          data['supervisorName']?.toString() ?? _supervisorNameController.text;
      _projectNameController.text =
          data['projectName']?.toString() ?? _projectNameController.text;
      _projectPhaseController.text =
          data['projectPhase']?.toString() ?? _projectPhaseController.text;

      final siteDocs = data['siteDocs'] as List<dynamic>? ?? [];
      _stagedDocuments.clear();
      for (var item in siteDocs) {
        if (item is Map) {
          _stagedDocuments.add(DrawingDocItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      _selectedConfigId = docId;
    });

    AppTheme.showSuccessToast(context, 'Loaded configuration: $docId');
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'dwg', 'dxf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedPlatformFile = file;
          _pickedFileName = file.name;
          if (_docNameController.text.trim().isEmpty) {
            final dotIdx = file.name.lastIndexOf('.');
            _docNameController.text = dotIdx > 0 ? file.name.substring(0, dotIdx) : file.name;
          }
        });
        if (mounted) {
          AppTheme.showSuccessToast(context, 'Selected: ${file.name} (${_formatBytes(file.size)})');
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

    final pFile = _pickedPlatformFile;
    final extension = pFile?.extension ??
        (_pickedFileName != null && _pickedFileName!.contains('.')
            ? _pickedFileName!.split('.').last.toLowerCase()
            : '');
    final sizeBytes = pFile?.size ?? 0;
    final sizeFormatted = _formatBytes(sizeBytes);

    setState(() {
      _stagedDocuments.add(DrawingDocItem(
        docId: 'DOC_${DateTime.now().millisecondsSinceEpoch}',
        docName: docName,
        purpose: purpose,
        fileName: _pickedFileName ?? 'Not attached',
        platformFile: pFile,
        fileType: extension,
        fileSizeBytes: sizeBytes,
        fileSize: sizeFormatted,
        uploadDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
        isCloudUploaded: false,
      ));

      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
      _pickedPlatformFile = null;
    });

    AppTheme.showSuccessToast(context, 'Added "$docName" to staging list');
  }

  bool get _canSave {
    if (_selectedSiteId == null || _selectedSiteId!.trim().isEmpty) return false;
    if (_projectNameController.text.trim().isEmpty) return false;
    if (_stagedDocuments.isEmpty) return false;
    return true;
  }

  /// Upload file to Firebase Storage under organisation/{orgId}/drawings/{siteId}/{timestamp}_{filename}
  Future<String?> _uploadFileToCloud(PlatformFile file, String siteId) async {
    try {
      final uploadResult = await AppStorageService.uploadDrawingDoc(
        siteId: siteId,
        fileName: file.name,
        file: (!kIsWeb && file.path != null && file.path!.isNotEmpty) ? File(file.path!) : null,
        bytes: file.bytes,
      );
      return uploadResult?.downloadUrl;
    } catch (e) {
      debugPrint('Error uploading drawing file to Firebase Storage: $e');
      return null;
    }
  }

  bool _isImageFile(String nameOrUrl) {
    final lower = nameOrUrl.toLowerCase();
    return lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('.bmp');
  }

  bool _isPdfFile(String nameOrUrl) {
    final lower = nameOrUrl.toLowerCase();
    return lower.contains('.pdf');
  }

  void _showImagePreviewDialog(String title, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                      tooltip: 'Download Image',
                      onPressed: () => _downloadDocument(title, url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Interactive Image Viewer
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 560),
                  color: Colors.black,
                  child: Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          final total = loadingProgress.expectedTotalBytes;
                          final loaded = loadingProgress.cumulativeBytesLoaded;
                          final progress = total != null ? loaded / total : null;
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(value: progress, color: Colors.white),
                                const SizedBox(height: 12),
                                const Text(
                                  'Loading drawing preview...',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Failed to load image preview directly',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _downloadDocument(title, url),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('Open External / Download'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Footer instructions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF0F172A),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pinch_rounded, size: 14, color: Colors.white54),
                    SizedBox(width: 6),
                    Text(
                      'Pinch / Scroll to zoom • Drag to pan blueprint',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewDocument(String title, String url, {String? fileType, String? fileName}) async {
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      if (mounted) AppTheme.showErrorToast(context, 'No valid cloud URL available for this document');
      return;
    }

    final combinedName = '${fileName ?? ''} $title $url'.toLowerCase();

    if (_isImageFile(combinedName)) {
      _showImagePreviewDialog(title, url);
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (kIsWeb) {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) AppTheme.showErrorToast(context, 'Could not launch URL: $url');
        }
      } else {
        if (_isPdfFile(combinedName)) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewScreen(title: title, url: url),
              ),
            );
          }
        } else {
          // CAD/DWG, Word, DXF or other documents
          final canLaunch = await canLaunchUrl(uri);
          if (canLaunch) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewScreen(title: title, url: url),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) AppTheme.showErrorToast(context, 'Failed to open document: $e');
    }
  }

  Future<void> _downloadDocument(String title, String url) async {
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      if (mounted) AppTheme.showErrorToast(context, 'No valid download link found for this drawing');
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (mounted) {
        AppTheme.showSuccessToast(context, 'Starting download for "$title"...');
      }
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) AppTheme.showErrorToast(context, 'Could not initiate download: $url');
      }
    } catch (e) {
      if (mounted) AppTheme.showErrorToast(context, 'Download failed: $e');
    }
  }

  Future<void> _saveDocuments() async {
    if (!_canSave) {
      AppTheme.showErrorToast(context, 'Please select a Site and add at least one document');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final dateFormatted = DateFormat('yyyyMMdd').format(now);
      final cleanSiteId = _selectedSiteId!.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // ── Standard Document ID format: DRAWING_<siteId>_<yyyyMMdd> ───────────
      final standardDocId = 'DRAWING_${cleanSiteId}_$dateFormatted';
      final docRef = FirestoreService.getCollection('siteDrawings').doc(standardDocId);

      // Upload newly staged files to cloud storage
      final List<Map<String, dynamic>> finalNewDocs = [];
      for (var docItem in _stagedDocuments) {
        String fileUrl = docItem.fileUrl ?? '';
        String storagePath = docItem.storagePath ?? '';

        if ((fileUrl.isEmpty || !fileUrl.startsWith('http')) && docItem.platformFile != null) {
          final uploadedUrl = await _uploadFileToCloud(docItem.platformFile!, _selectedSiteId!);
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            fileUrl = uploadedUrl;
            storagePath = 'organisation/${FirestoreService.currentOrgId}/drawings/$_selectedSiteId/${docItem.platformFile!.name}';
            docItem.fileUrl = uploadedUrl;
            docItem.storagePath = storagePath;
            docItem.isCloudUploaded = true;
          }
        }

        finalNewDocs.add({
          "docId": docItem.docId.isNotEmpty ? docItem.docId : 'DOC_${DateTime.now().millisecondsSinceEpoch}',
          "docName": docItem.docName,
          "purpose": docItem.purpose,
          "fileName": docItem.fileName,
          "docUrl": fileUrl.isNotEmpty ? fileUrl : docItem.fileName,
          "fileUrl": fileUrl,
          "storagePath": storagePath,
          "fileType": docItem.fileType,
          "fileSize": docItem.fileSize,
          "fileSizeBytes": docItem.fileSizeBytes,
          "uploadDate": docItem.uploadDate.isNotEmpty ? docItem.uploadDate : DateFormat('dd/MM/yyyy').format(now),
          "uploadedAt": now.toIso8601String(),
          "isCloudUploaded": fileUrl.isNotEmpty,
        });
      }

      // Check existing documents in document for merging
      List<dynamic> existingSiteDocs = [];
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists &&
          docSnapshot.data() != null &&
          docSnapshot.data()!["siteDocs"] != null) {
        existingSiteDocs = List.from(docSnapshot.data()!["siteDocs"]);
      }

      // Merge and deduplicate by docId or docName+fileName
      final combinedSiteDocs = [...existingSiteDocs];
      for (var newDoc in finalNewDocs) {
        final existingIdx = combinedSiteDocs.indexWhere((ex) =>
            (ex is Map && ex['docId'] == newDoc['docId']) ||
            (ex is Map && ex['docName'] == newDoc['docName'] && ex['fileName'] == newDoc['fileName']));
        if (existingIdx >= 0) {
          combinedSiteDocs[existingIdx] = newDoc;
        } else {
          combinedSiteDocs.add(newDoc);
        }
      }

      final documentData = {
        "docId": standardDocId,
        "siteId": _selectedSiteId,
        "projectName": _projectNameController.text.trim(),
        "supervisorName": _supervisorNameController.text.trim(),
        "projectPhase": _projectPhaseController.text.trim(),
        "date": DateFormat('dd/MM/yyyy').format(now),
        "formattedDate": DateFormat('dd-MM-yyyy').format(now),
        "createdAt": docSnapshot.exists && docSnapshot.data()?['createdAt'] != null
            ? docSnapshot.data()!['createdAt']
            : FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "createdDateIso": now.toIso8601String(),
        "status": "Active",
        "totalDocuments": combinedSiteDocs.length,
        "siteDocs": combinedSiteDocs,
      };

      await docRef.set(documentData, SetOptions(merge: true));

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Drawings configuration successfully saved for Site $_selectedSiteId!\n\nStandard Doc ID: $standardDocId',
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
      _stagedDocuments.clear();
      _docNameController.clear();
      _purposeController.clear();
      _pickedFileName = null;
      _pickedPlatformFile = null;
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
          'date': data['date'] ?? data['formattedDate'] ?? '',
          'updatedAt': data['updatedAt'],
          'siteDocs': data['siteDocs'] is List ? data['siteDocs'] : [],
        });
      }

      // Sort by docId descending (newest first)
      list.sort((a, b) => (b['docId'] ?? '').toString().compareTo((a['docId'] ?? '').toString()));

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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Segmented Tab Switcher ───────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          primary: true,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Supervisor', Icons.person_rounded),
                              const SizedBox(height: 6),
                              _buildReadOnlyBox(_supervisorNameController.text, 'Auto-filled supervisor'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Current Project Stage / Phase', Icons.timeline_rounded),
                    const SizedBox(height: 6),
                    _buildReadOnlyBox(_projectPhaseController.text, 'Auto-filled stage'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. Add / Attach Drawing Document Card ──────────────────────
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
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
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

                    // File attachment preview row
                    if (_pickedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFileName!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF047857),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_pickedPlatformFile != null)
                                    Text(
                                      _formatBytes(_pickedPlatformFile!.size),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _pickedFileName = null;
                                _pickedPlatformFile = null;
                              }),
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
                      'Supported formats: PDF, DWG, DXF, DOC, DOCX, PNG, JPG',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. Staged Documents Tray ──────────────────────────────────
              if (_stagedDocuments.isNotEmpty) ...[
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
                            'Staged Drawings (${_stagedDocuments.length})',
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
                        itemCount: _stagedDocuments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = _stagedDocuments[index];
                          final isCloud = doc.isCloudUploaded;

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
                                    color: (isCloud ? const Color(0xFF10B981) : primaryColor)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isCloud ? Icons.cloud_done_rounded : Icons.description_rounded,
                                    size: 18,
                                    color: isCloud ? const Color(0xFF047857) : primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.docName,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: darkAccent,
                                        ),
                                      ),
                                      Text(
                                        doc.purpose,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (doc.fileName.isNotEmpty && doc.fileName != 'Not attached')
                                        Text(
                                          'File: ${doc.fileName} ${doc.fileSize.isNotEmpty ? "(${doc.fileSize})" : ""}',
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
                                if (doc.fileUrl != null && doc.fileUrl!.isNotEmpty) ...[
                                  IconButton(
                                    icon: Icon(Icons.visibility_rounded, color: primaryColor, size: 20),
                                    tooltip: 'View Document',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _viewDocument(doc.docName, doc.fileUrl!, fileType: doc.fileType, fileName: doc.fileName),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 20),
                                    tooltip: 'Download Document',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _downloadDocument(doc.docName, doc.fileUrl!),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  tooltip: 'Remove',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _stagedDocuments.removeAt(index);
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
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'UPLOADING & SAVING...',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_rounded, size: 20),
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
      final docId = (set['docId'] ?? '').toString().toLowerCase();
      final q = _drawingSearchQuery.toLowerCase().trim();

      if (q.isEmpty) return true;
      if (site.contains(q) || project.contains(q) || sup.contains(q) || docId.contains(q)) return true;

      final docs = set['siteDocs'] as List<dynamic>? ?? [];
      for (var d in docs) {
        if (d is Map) {
          final name = (d['docName'] ?? '').toString().toLowerCase();
          final purpose = (d['purpose'] ?? '').toString().toLowerCase();
          final fileName = (d['fileName'] ?? '').toString().toLowerCase();
          if (name.contains(q) || purpose.contains(q) || fileName.contains(q)) return true;
        }
      }
      return false;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAllDrawings,
      child: SingleChildScrollView(
        primary: true,
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
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final set = filtered[index];
                  final docs = set['siteDocs'] as List<dynamic>? ?? [];
                  final docId = set['docId']?.toString() ?? '';
                  final date = set['date']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Site header row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                set['siteId'] ?? '',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    set['projectName']?.toString().isNotEmpty == true
                                        ? set['projectName']
                                        : 'Site ${set['siteId']}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: darkAccent,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Doc ID: $docId ${date.isNotEmpty ? "• $date" : ""}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete set',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteDrawingSet(docId),
                            ),
                          ],
                        ),
                        if ((set['supervisorName'] ?? '').isNotEmpty || (set['projectPhase'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if ((set['supervisorName'] ?? '').isNotEmpty) ...[
                                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    set['supervisorName'],
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if ((set['projectPhase'] ?? '').isNotEmpty) ...[
                                  const Icon(Icons.timeline_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    set['projectPhase'],
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFFF1F5F9), height: 1),
                        ),

                        // Document Items in Set
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Drawing Documents (${docs.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: darkAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...docs.map((d) {
                              final docMap = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
                              final name = docMap['docName']?.toString() ?? 'Document';
                              final purpose = docMap['purpose']?.toString() ?? '';
                              final docUrl = docMap['fileUrl']?.toString() ?? docMap['docUrl']?.toString() ?? '';
                              final fileName = docMap['fileName']?.toString() ?? '';
                              final fileType = docMap['fileType']?.toString() ?? '';
                              final size = docMap['fileSize']?.toString() ?? '';
                              final uploadDate = docMap['uploadDate']?.toString() ?? '';
                              final isCloud = docUrl.startsWith('http://') || docUrl.startsWith('https://');

                              final docIcon = _getDocumentIconData(name, fileType.isNotEmpty ? fileType : fileName);
                              final docColor = _getDocumentColor(name, fileType.isNotEmpty ? fileType : fileName);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: docColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(docIcon, size: 20, color: docColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (purpose.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    purpose,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              if (fileName.isNotEmpty && fileName != 'Not attached')
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 3),
                                                  child: Text(
                                                    'File: $fileName',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF94A3B8),
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Metadata chips & Action buttons row
                                    Row(
                                      children: [
                                        if (size.isNotEmpty || uploadDate.isNotEmpty)
                                          Expanded(
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (size.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE2E8F0),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      size,
                                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                                    ),
                                                  ),
                                                if (uploadDate.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      uploadDate,
                                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          )
                                        else
                                          const Spacer(),

                                        if (isCloud) ...[
                                          // ── View Button ─────────────────────
                                          ElevatedButton.icon(
                                            onPressed: () => _viewDocument(name, docUrl, fileType: fileType, fileName: fileName),
                                            icon: const Icon(Icons.visibility_rounded, size: 14),
                                            label: const Text(
                                              'View',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: const Size(0, 32),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // ── Download Button ─────────────────
                                          OutlinedButton.icon(
                                            onPressed: () => _downloadDocument(name, docUrl),
                                            icon: const Icon(Icons.download_rounded, size: 14),
                                            label: const Text(
                                              'Download',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primaryColor,
                                              side: BorderSide(color: primaryColor.withValues(alpha: 0.45)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: const Size(0, 32),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ] else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'No cloud file',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
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

  IconData _getDocumentIconData(String name, String type) {
    final lower = '$name $type'.toLowerCase();
    if (lower.contains('.pdf') || type == 'pdf') return Icons.picture_as_pdf_rounded;
    if (_isImageFile(lower) || ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(type)) return Icons.image_rounded;
    if (lower.contains('.dwg') || lower.contains('.dxf') || type == 'dwg' || type == 'dxf') return Icons.architecture_rounded;
    if (lower.contains('.doc') || lower.contains('.docx') || type == 'doc' || type == 'docx') return Icons.article_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getDocumentColor(String name, String type) {
    final lower = '$name $type'.toLowerCase();
    if (lower.contains('.pdf') || type == 'pdf') return const Color(0xFFDC2626);
    if (_isImageFile(lower) || ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(type)) return const Color(0xFF0284C7);
    if (lower.contains('.dwg') || lower.contains('.dxf') || type == 'dwg' || type == 'dxf') return const Color(0xFFD97706);
    if (lower.contains('.doc') || lower.contains('.docx') || type == 'doc' || type == 'docx') return const Color(0xFF4F46E5);
    return primaryColor;
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
