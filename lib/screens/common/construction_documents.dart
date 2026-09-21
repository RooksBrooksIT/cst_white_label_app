import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ebricks/screens/common/web_view_screen.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/site_display_helper.dart';

class _SiteOption {
  final String canonicalId;
  String siteName;
  String displayLabel;
  final Set<String> aliases;

  _SiteOption({
    required this.canonicalId,
    required this.siteName,
    required this.displayLabel,
    required this.aliases,
  });
}

class ConstructionDocuments extends StatefulWidget {
  const ConstructionDocuments({super.key});

  @override
  State<ConstructionDocuments> createState() => _ConstructionDocumentsState();
}

class _ConstructionDocumentsState extends State<ConstructionDocuments> {
  String? _selectedSiteId;
  Map<String, dynamic>? _selectedSiteData;
  bool _isLoadingSiteData = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  Future<void> _fetchSiteData(String siteIdentifier) async {
    setState(() => _isLoadingSiteData = true);
    try {
      final cleanInput = siteIdentifier.trim();
      final canonicalId = SiteDisplayHelper.extractSiteId(cleanInput);
      final searchKeys = {cleanInput, canonicalId}.where((k) => k.isNotEmpty).toList();

      QuerySnapshot<Map<String, dynamic>>? snapshot;
      for (final key in searchKeys) {
        final snap = await FirestoreService.getCollection('siteDrawings')
            .where('siteId', isEqualTo: key)
            .get();
        if (snap.docs.isNotEmpty) {
          snapshot = snap;
          break;
        }
      }

      if (snapshot != null && snapshot.docs.isNotEmpty) {
        // Pick the most recent document if multiple
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) => b.id.compareTo(a.id));
        setState(() {
          _selectedSiteData = sortedDocs.first.data();
        });
      } else {
        // Direct document ID lookup fallback
        bool found = false;
        final directDocKeys = [
          cleanInput,
          canonicalId,
          if (canonicalId.isNotEmpty) 'DRAWING_$canonicalId',
          'DRAWING_$cleanInput',
        ];

        for (final docKey in directDocKeys) {
          if (docKey.isEmpty) continue;
          final docDirect = await FirestoreService.getCollection('siteDrawings').doc(docKey).get();
          if (docDirect.exists && docDirect.data() != null) {
            setState(() {
              _selectedSiteData = docDirect.data();
            });
            found = true;
            break;
          }
        }

        if (!found && canonicalId.isNotEmpty) {
          final allDrawingsSnap = await FirestoreService.getCollection('siteDrawings').get();
          for (final doc in allDrawingsSnap.docs) {
            final data = doc.data();
            final docSiteId = (data['siteId'] ?? '').toString().trim();
            final docId = doc.id;
            if (docSiteId == canonicalId || docSiteId == cleanInput ||
                docId.contains(canonicalId) || docId == cleanInput) {
              setState(() {
                _selectedSiteData = data;
              });
              found = true;
              break;
            }
          }
        }

        if (!found) {
          // Check siteSupervisorMap or sites for basic metadata fallback
          Map<String, dynamic>? metaData;
          for (final key in searchKeys) {
            final mapSnap = await FirestoreService.getCollection('siteSupervisorMap')
                .where('siteId', isEqualTo: key)
                .limit(1)
                .get();
            if (mapSnap.docs.isNotEmpty) {
              metaData = mapSnap.docs.first.data();
              break;
            }
          }

          if (metaData == null) {
            for (final key in searchKeys) {
              final mapDoc = await FirestoreService.getCollection('siteSupervisorMap').doc(key).get();
              if (mapDoc.exists && mapDoc.data() != null) {
                metaData = mapDoc.data();
                break;
              }
            }
          }

          if (metaData != null) {
            final siteName = SiteDisplayHelper.extractSiteName(cleanInput, siteId: canonicalId);
            setState(() {
              _selectedSiteData = {
                'siteId': cleanInput,
                'projectName': metaData!['projectName'] ?? metaData['siteName'] ?? (siteName.isNotEmpty ? siteName : 'Site $canonicalId'),
                'supervisorName': metaData['supervisor'] ?? metaData['supervisorName'] ?? 'N/A',
                'projectPhase': metaData['projectStage'] ?? metaData['phase'] ?? 'N/A',
                'siteDocs': <dynamic>[],
              };
            });
          } else {
            setState(() {
              _selectedSiteData = null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching site data: $e');
      setState(() {
        _selectedSiteData = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSiteData = false);
      }
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

  Future<void> _viewDocument(String title, String url, {String? fileName}) async {
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      if (mounted) AppTheme.showErrorToast(context, 'No valid cloud download link for this drawing');
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
          if (mounted) AppTheme.showErrorToast(context, 'Could not open URL: $url');
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


  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Construction Documents & Drawings',
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
            child: SingleChildScrollView(
              primary: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Site Selection Card ───────────────────────────────────
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
                              child: Icon(Icons.location_on_rounded, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Select Construction Site',
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
                        StreamBuilder<QuerySnapshot>(
                          stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
                          builder: (context, mapSnap) {
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirestoreService.getCollection('siteDrawings').snapshots(),
                              builder: (context, drawSnap) {
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirestoreService.getCollection('sites').snapshots(),
                                  builder: (context, sitesSnap) {
                                    if (mapSnap.connectionState == ConnectionState.waiting &&
                                        drawSnap.connectionState == ConnectionState.waiting &&
                                        sitesSnap.connectionState == ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    }

                                    final Map<String, _SiteOption> siteOptionMap = {};

                                    void ingestSite(Map<String, dynamic> data, String docId) {
                                      final rawSiteId = (data['siteCode'] ?? data['siteId'] ?? data['site'] ?? data['siteDocId'] ?? docId).toString().trim();
                                      final rawSiteName = (data['siteName'] ?? data['projectName'] ?? data['name'] ?? '').toString().trim();

                                      if (rawSiteId.isEmpty || rawSiteId == 'null') return;

                                      final extracted = SiteDisplayHelper.extractSiteId(rawSiteId);
                                      final canonicalId = extracted.isNotEmpty
                                          ? extracted
                                          : (SiteDisplayHelper.extractSiteId(docId).isNotEmpty
                                              ? SiteDisplayHelper.extractSiteId(docId)
                                              : rawSiteId);

                                      final display = SiteDisplayHelper.formatSiteDisplay(
                                        siteId: canonicalId,
                                        siteName: rawSiteName,
                                        data: data,
                                        rawCombined: rawSiteId,
                                      );

                                      final key = canonicalId.toUpperCase();
                                      if (key.isEmpty || key == 'NULL') return;

                                      if (!siteOptionMap.containsKey(key)) {
                                        siteOptionMap[key] = _SiteOption(
                                          canonicalId: canonicalId,
                                          siteName: rawSiteName,
                                          displayLabel: display.isNotEmpty ? display : canonicalId,
                                          aliases: {rawSiteId, docId, canonicalId, display}..removeWhere((s) => s.isEmpty),
                                        );
                                      } else {
                                        final existing = siteOptionMap[key]!;
                                        existing.aliases.addAll({rawSiteId, docId, canonicalId, display}..removeWhere((s) => s.isEmpty));

                                        if (!existing.displayLabel.contains('_') && display.contains('_')) {
                                          existing.displayLabel = display;
                                        }
                                        if (existing.siteName.isEmpty && rawSiteName.isNotEmpty) {
                                          existing.siteName = rawSiteName;
                                        }
                                      }
                                    }

                                    if (mapSnap.hasData) {
                                      for (var doc in mapSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        ingestSite(data, doc.id);
                                      }
                                    }
                                    if (sitesSnap.hasData) {
                                      for (var doc in sitesSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        ingestSite(data, doc.id);
                                      }
                                    }
                                    if (drawSnap.hasData) {
                                      for (var doc in drawSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        ingestSite(data, doc.id);
                                      }
                                    }

                                    final siteOptions = siteOptionMap.values.toList()
                                      ..sort((a, b) => a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()));

                                    String? matchedDropdownValue;
                                    if (_selectedSiteId != null) {
                                      final match = siteOptions.firstWhere(
                                        (opt) =>
                                            opt.displayLabel == _selectedSiteId ||
                                            opt.canonicalId.toLowerCase() == _selectedSiteId!.toLowerCase() ||
                                            opt.aliases.any((a) => a.toLowerCase() == _selectedSiteId!.toLowerCase()),
                                        orElse: () => _SiteOption(canonicalId: '', siteName: '', displayLabel: '', aliases: {}),
                                      );
                                      if (match.displayLabel.isNotEmpty) {
                                        matchedDropdownValue = match.displayLabel;
                                      }
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: matchedDropdownValue,
                                          isExpanded: true,
                                          hint: const Text(
                                            'Choose site to view drawings...',
                                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                          ),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                          items: siteOptions.map((opt) {
                                            return DropdownMenuItem<String>(
                                              value: opt.displayLabel,
                                              child: Text(
                                                opt.displayLabel,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedSiteId = val;
                                              _selectedSiteData = null;
                                            });
                                            if (val != null) {
                                              _fetchSiteData(val);
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Site Details & Associated Drawings ────────────────────
                  if (_isLoadingSiteData)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading construction drawings & documents...',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_selectedSiteId == null)
                    _buildInitialPromptCard(primaryColor: primaryColor, darkAccent: darkAccent)
                  else if (_selectedSiteData != null) ...[
                    Builder(
                      builder: (context) {
                        final rawDocs = _selectedSiteData!['siteDocs'];
                        final List<dynamic> siteDocsList = (rawDocs is List) ? rawDocs : <dynamic>[];
                        final hasDocs = siteDocsList.isNotEmpty;

                        return Container(
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
                                    child: const Icon(Icons.business_rounded, color: Color(0xFF0284C7), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedSiteData!['projectName'] ?? 'Project Site',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: darkAccent,
                                          ),
                                        ),
                                        Text(
                                          'Site ID: $_selectedSiteId ${_selectedSiteData!['docId'] != null ? "• ${_selectedSiteData!['docId']}" : ""}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(color: Color(0xFFF1F5F9), height: 1),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailChip(
                                      'Supervisor',
                                      _selectedSiteData!['supervisorName'] ?? 'N/A',
                                      Icons.person_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildDetailChip(
                                      'Phase / Stage',
                                      _selectedSiteData!['projectPhase'] ?? 'N/A',
                                      Icons.timeline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedSiteData!['date'] != null || _selectedSiteData!['formattedDate'] != null) ...[
                                const SizedBox(height: 10),
                                _buildDetailChip(
                                  'Date Configured',
                                  _selectedSiteData!['date'] ?? _selectedSiteData!['formattedDate'] ?? 'N/A',
                                  Icons.calendar_today_rounded,
                                ),
                              ],
                              const SizedBox(height: 20),

                              // Document list or Empty State
                              Text(
                                'Available Documents & Layouts',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: darkAccent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (hasDocs)
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: siteDocsList.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final doc = siteDocsList[index];
                                    final docMap = doc is Map ? Map<String, dynamic>.from(doc) : <String, dynamic>{};
                                    final docName = docMap['docName'] ?? 'Document ${index + 1}';
                                    final purpose = docMap['purpose'] ?? '';
                                    final docUrl = docMap['fileUrl'] ?? docMap['docUrl'] ?? '';
                                    final fileSize = docMap['fileSize']?.toString() ?? '';
                                    final uploadDate = docMap['uploadDate']?.toString() ?? '';
                                    final isCloud = docUrl.toString().startsWith('http://') || docUrl.toString().startsWith('https://');

                                    final docIcon = _getDocumentIconData(docName, docUrl);
                                    final docColor = _getDocumentColor(docName, docUrl);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                                child: Icon(
                                                  docIcon,
                                                  color: docColor,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      docName,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w800,
                                                        color: darkAccent,
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
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              if (fileSize.isNotEmpty || uploadDate.isNotEmpty)
                                                Expanded(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      if (fileSize.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            fileSize,
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
                                                ElevatedButton.icon(
                                                  onPressed: () => _viewDocument(docName, docUrl),
                                                  icon: const Icon(Icons.visibility_rounded, size: 14),
                                                  label: const Text(
                                                    'View',
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: primaryColor,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: const Size(0, 32),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    elevation: 0,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton.icon(
                                                  onPressed: () => _downloadDocument(docName, docUrl),
                                                  icon: const Icon(Icons.download_rounded, size: 14),
                                                  label: const Text(
                                                    'Download',
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: primaryColor,
                                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.45)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: const Size(0, 32),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              else
                                _buildEmptyStateCard(
                                  siteId: _selectedSiteId,
                                  primaryColor: primaryColor,
                                  darkAccent: darkAccent,
                                  isEmbedded: true,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else
                    _buildEmptyStateCard(
                      siteId: _selectedSiteId,
                      primaryColor: primaryColor,
                      darkAccent: darkAccent,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ],
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

  Widget _buildEmptyStateCard({
    String? siteId,
    required Color primaryColor,
    required Color darkAccent,
    bool isEmbedded = false,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: const Center(
            child: Icon(
              Icons.description_outlined,
              size: 30,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Drawings or Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: darkAccent,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: const Text(
            '📄 No drawings or documents have been assigned to this site yet.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (siteId != null && siteId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Selected Site: $siteId',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );

    if (isEmbedded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
      child: content,
    );
  }

  Widget _buildInitialPromptCard({
    required Color primaryColor,
    required Color darkAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.architecture_rounded,
              size: 32,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a Construction Site',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: const Text(
              'Choose a site from the dropdown above to view associated architectural drawings, site plans, and construction documents.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
