import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ConstructionDocuments extends StatefulWidget {
  const ConstructionDocuments({super.key});

  @override
  State<ConstructionDocuments> createState() => _ConstructionDocumentsState();
}

class _ConstructionDocumentsState extends State<ConstructionDocuments> {
  String? selectedSiteId;
  Map<String, dynamic>? selectedSiteData;

  final Color primaryColor = const Color(0xFF772323);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  // Set your base URL here to prepend to relative doc URLs
  final String baseDocUrl = 'https://your-base-url.com/';

  Future<void> fetchSiteData(String siteId) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('siteDrawings')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          selectedSiteData = snapshot.docs.first.data() as Map<String, dynamic>;
        });
      } else {
        setState(() {
          selectedSiteData = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site data: $e');
      setState(() {
        selectedSiteData = null;
      });
    }
  }

  /// Prepare URL by ensuring it contains a valid scheme
  String prepareDocUrl(String docUrl) {
    if (docUrl.startsWith('http://') || docUrl.startsWith('https://')) {
      return docUrl;
    } else {
      final fullUrl = baseDocUrl + docUrl;
      debugPrint('Prepared URL: $fullUrl');
      return fullUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Construction Documents',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Selection Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Selection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('siteDrawings')
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error fetching site IDs');
                        }
                        final docs = snapshot.data?.docs ?? [];
                        final siteIds = docs
                            .map((doc) => doc['siteId']?.toString() ?? '')
                            .where((id) => id.isNotEmpty)
                            .toSet()
                            .toList();

                        return DropdownButtonFormField<String>(
                          initialValue: selectedSiteId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            labelText: 'Select Site ID',
                          ),
                          isExpanded: true,
                          items: siteIds.map((id) {
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                id,
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              selectedSiteId = newValue;
                              selectedSiteData = null;
                            });
                            if (newValue != null) {
                              fetchSiteData(newValue);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Project Details and Associated Documents Card
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: selectedSiteData == null
                      ? Center(
                          child: Text(
                            selectedSiteId == null
                                ? 'Please select a site'
                                : 'Loading site details...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'Project Name: ${selectedSiteData!['projectName'] ?? 'N/A'}'),
                              Text(
                                  'Project Phase: ${selectedSiteData!['projectPhase'] ?? 'N/A'}'),
                              Text(
                                  'Supervisor: ${selectedSiteData!['supervisorName'] ?? 'N/A'}'),
                              const SizedBox(height: 24),
                              Text(
                                'Associated Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (selectedSiteData!['siteDocs'] != null &&
                                  selectedSiteData!['siteDocs'] is List)
                                ...List<Widget>.from(
                                  (selectedSiteData!['siteDocs'] as List)
                                      .map((doc) {
                                    final docMap =
                                        Map<String, dynamic>.from(doc);
                                    final docName =
                                        docMap['docName'] ?? 'Unnamed Document';
                                    final docUrl = docMap['docUrl'] ?? '';

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              docName,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: docUrl.isNotEmpty
                                                ? () {
                                                    final url =
                                                        prepareDocUrl(docUrl);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            WebViewScreen(
                                                          title: docName,
                                                          url: url,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 20, vertical: 10),
                                            ),
                                            child: Text(
                                              'View',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                )
                              else
                                Text('No documents available'),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Clear and Cancel Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        selectedSiteId = null;
                        selectedSiteData = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: primaryColor),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

/// WebViewScreen that loads given URL using latest webview_flutter API
class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;
  int loadingProgress = 0;

  String get effectiveUrl {
    final lower = widget.url.toLowerCase();
    // Use Google Docs Viewer for raw PDFs on mobile to ensure proper rendering inside WebView
    if (!kIsWeb && (lower.endsWith('.pdf') || lower.contains('.pdf?')) && !lower.contains('docs.google.com')) {
      return 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    }
    return widget.url;
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(effectiveUrl))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                loadingProgress = progress;
                if (progress == 100) isLoading = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('Web resource error: $error');
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
        ),
      );
  }

  Future<void> _downloadOrOpenExternal() async {
    final uri = Uri.parse(widget.url);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open external link: ${widget.url}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download / open: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF772323),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reload',
            onPressed: () {
              setState(() => isLoading = true);
              _controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download / Open in Browser',
            onPressed: _downloadOrOpenExternal,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 800),
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (isLoading)
                Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF772323)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loadingProgress > 0 ? 'Loading document ($loadingProgress%)...' : 'Loading document...',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
