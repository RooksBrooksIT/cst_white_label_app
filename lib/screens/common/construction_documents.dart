import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/common/web_view_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

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

  Future<void> _fetchSiteData(String siteId) async {
    setState(() => _isLoadingSiteData = true);
    try {
      final snapshot = await FirestoreService.getCollection('siteDrawings')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _selectedSiteData = snapshot.docs.first.data();
        });
      } else {
        setState(() {
          _selectedSiteData = null;
        });
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
                          stream: FirestoreService.getCollection('siteDrawings').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final docs = snapshot.data?.docs ?? [];
                            final siteIds = docs
                                .map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return (data['siteId'] ?? doc.id.split('_').first).toString();
                                })
                                .where((id) => id.isNotEmpty)
                                .toSet()
                                .toList()
                              ..sort();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: siteIds.contains(_selectedSiteId) ? _selectedSiteId : null,
                                  isExpanded: true,
                                  hint: const Text(
                                    'Choose site to view drawings...',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                  ),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                  items: siteIds.map((id) {
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(
                                        'Site: $id',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Site Details & Associated Drawings ────────────────────
                  if (_isLoadingSiteData)
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (_selectedSiteData != null) ...[
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
                                      'Site ID: $_selectedSiteId',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                          const SizedBox(height: 20),

                          // Document list
                          Text(
                            'Available Documents & Layouts',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: darkAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedSiteData!['siteDocs'] != null &&
                              _selectedSiteData!['siteDocs'] is List &&
                              (_selectedSiteData!['siteDocs'] as List).isNotEmpty)
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (_selectedSiteData!['siteDocs'] as List).length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = (_selectedSiteData!['siteDocs'] as List)[index];
                                final docMap = Map<String, dynamic>.from(doc);
                                final docName = docMap['docName'] ?? 'Document ${index + 1}';
                                final purpose = docMap['purpose'] ?? '';
                                final docUrl = docMap['docUrl'] ?? '';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 20),
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
                                              Text(
                                                purpose,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (docUrl.isNotEmpty)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => WebViewScreen(
                                                  title: docName,
                                                  url: docUrl,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility_rounded, size: 16),
                                          label: const Text(
                                            'View',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: const Center(
                                child: Text(
                                  'No drawings attached to this site.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else if (_selectedSiteId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'No drawing records found for this site.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ),
                    ),
                  ],
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
}
