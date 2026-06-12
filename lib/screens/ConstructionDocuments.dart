import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/WebViewScreen.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';


class ConstructionDocuments extends StatefulWidget {
  const ConstructionDocuments({super.key});

  @override
  _ConstructionDocumentsState createState() => _ConstructionDocumentsState();
}

class _ConstructionDocumentsState extends State<ConstructionDocuments> {
  String? selectedSiteId;
  Map<String, dynamic>? selectedSiteData;

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
      print('Error fetching site data: $e');
      setState(() {
        selectedSiteData = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: 'Construction Documents',
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Selection Card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Selection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    SizedBox(height: 12),
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
                            .toList(); // Ensure unique IDs
                        return DropdownButtonFormField<String>(
                          value: selectedSiteId,
                          dropdownColor: cs.surfaceContainerHighest,
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            labelText: 'Select Site ID',
                            labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                          ),
                          isExpanded: true,
                          items: siteIds.map((String id) {
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                id,
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedSiteId = newValue;
                              selectedSiteData =
                                  null; // Clear previous selection
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
            SizedBox(height: 24),
            // Project Details and Documents Card
            Expanded(
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'Project Name: ${selectedSiteData!['projectName'] ?? 'N/A'}',
                                  style: TextStyle(color: cs.onSurface)),
                              Text(
                                  'Project Phase: ${selectedSiteData!['projectPhase'] ?? 'N/A'}',
                                  style: TextStyle(color: cs.onSurface)),
                              Text(
                                  'Supervisor: ${selectedSiteData!['supervisorName'] ?? 'N/A'}',
                                  style: TextStyle(color: cs.onSurface)),
                              const SizedBox(height: 24),
                              Text(
                                'Associated Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              SizedBox(height: 16),
                              if (selectedSiteData!['siteDocs'] != null &&
                                  selectedSiteData!['siteDocs'] is List)
                                Table(
                                  border: TableBorder.all(
                                      color: cs.outlineVariant),
                                  columnWidths: const {
                                    0: FlexColumnWidth(3),
                                    1: FlexColumnWidth(1),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.1)),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Document Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Doc Files',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: cs.primary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...List<TableRow>.from(
                                      (selectedSiteData!['siteDocs'] as List)
                                          .map((doc) {
                                        final docMap =
                                            Map<String, dynamic>.from(doc);
                                        final docName = docMap['docName'] ??
                                            'Unnamed Document';
                                        final docUrl = docMap['docUrl'] ?? '';
                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                                  child: Text(
                                                    docName,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: cs.onSurface,
                                                    ),
                                                  ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Center(
                                                child: ElevatedButton(
                                                  onPressed: docUrl.isNotEmpty
                                                      ? () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  WebViewScreen(
                                                                title: docName,
                                                                url: docUrl,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      : null,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        cs.primary,
                                                    foregroundColor: cs.onPrimary,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 8),
                                                  ),
                                                  child: Text(
                                                    'View',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              else
                                Text('No documents available'),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: 24),
            // Action Buttons
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
