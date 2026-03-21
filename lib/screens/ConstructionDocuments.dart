import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/WebViewScreen.dart';


class ConstructionDocuments extends StatefulWidget {
  const ConstructionDocuments({super.key});

  @override
  _ConstructionDocumentsState createState() => _ConstructionDocumentsState();
}

class _ConstructionDocumentsState extends State<ConstructionDocuments> {
  String? selectedSiteId;
  Map<String, dynamic>? selectedSiteData;

  final Color primaryColor = Color(0xFF772323);
  final Color accentColor = Color(0xFFD9B6A3);
  final Color backgroundColor = Color(0xFFF5F5F5);

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
      body: Container(
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
                padding: const EdgeInsets.all(16.0),
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
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            labelText: 'Select Site ID',
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
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                                  
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                  'Project Name: ${selectedSiteData!['projectName'] ?? 'N/A'}'),
                              Text(
                                  'Project Phase: ${selectedSiteData!['projectPhase'] ?? 'N/A'}'),
                              Text(
                                  'Supervisor: ${selectedSiteData!['supervisorName'] ?? 'N/A'}'),
                              SizedBox(height: 24),
                              Text(
                                'Associated Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  
                                ),
                              ),
                              SizedBox(height: 16),
                              if (selectedSiteData!['siteDocs'] != null &&
                                  selectedSiteData!['siteDocs'] is List)
                                Table(
                                  border: TableBorder.all(
                                      color: Colors.grey.shade300),
                                  columnWidths: {
                                    0: FlexColumnWidth(3),
                                    1: FlexColumnWidth(1),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.2)),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Document Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              
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
                                                        primaryColor,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
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
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: primaryColor),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: primaryColor,
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
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
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
