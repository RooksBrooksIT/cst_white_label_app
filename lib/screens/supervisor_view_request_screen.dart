import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ViewApprovalScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const ViewApprovalScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _ViewApprovalScreenState createState() => _ViewApprovalScreenState();
}

class _ViewApprovalScreenState extends State<ViewApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryColor = const Color(0xFF0B3470);
  final Color secondaryColor = Colors.white;
  final Color accentColor = Color(0xFFD9A441);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Work Schedule Approvals',
          style: TextStyle( fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: secondaryColor,
          unselectedLabelColor: secondaryColor.withOpacity(0.7),
          tabs: [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ApprovalList(
            status: 'Pending',
            supervisorName: widget.supervisorName,
          ),
          ApprovalList(
            status: 'Approved',
            supervisorName: widget.supervisorName,
          ),
        ],
      ),
    );
  }
}

class ApprovalList extends StatefulWidget {
  final String status;
  final String supervisorName;
  final Color primaryColor = const Color(0xFF0B3470);

  const ApprovalList({super.key, required this.status, required this.supervisorName});

  @override
  _ApprovalListState createState() => _ApprovalListState();
}

class _ApprovalListState extends State<ApprovalList> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Request ID',
              prefixIcon: Icon(Icons.search, color: widget.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.2)),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService
                .getCollection('siteSupervisorProjectStageSchedule')
                .where('approvalStatus', isEqualTo: widget.status)
                .where('supervisorName', isEqualTo: widget.supervisorName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No ${widget.status} requests found',
                    style: TextStyle(color: widget.primaryColor),
                  ),
                );
              }

              // Filter and reorder
              List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
              if (_searchText.isNotEmpty) {
                final idx = docs.indexWhere((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['wsReqId'] ?? '').toString().toLowerCase().contains(_searchText.toLowerCase());
                });
                if (idx != -1) {
                  final match = docs.removeAt(idx);
                  docs.insert(0, match);
                }
                // Optionally, filter to only show matches:
                // docs = docs.where((doc) {
                //   final data = doc.data() as Map<String, dynamic>;
                //   return (data['wsReqId'] ?? '').toString().toLowerCase().contains(_searchText.toLowerCase());
                // }).toList();
              }

              return ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return ApprovalCard(
                    docId: doc.id,
                    data: data,
                    status: widget.status,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ApprovalCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String status;

  const ApprovalCard({super.key, 
    required this.docId,
    required this.data,
    required this.status,
  });

  @override
  _ApprovalCardState createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  final Color primaryColor = const Color(0xFF0B3470);
  final Color secondaryColor = Colors.white;
  final Color accentColor = Color(0xFFD9A441);

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSize(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            // Header Row: Request ID, Project Name, Expand/Collapse Arrow
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request ID: ${data['wsReqId']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          data['projectName'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: IconButton(
                      icon: Icon(Icons.keyboard_arrow_down,
                          size: 32, color: primaryColor),
                      onPressed: () {
                        setState(() {
                          _expanded = !_expanded;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Animated details
            if (_expanded)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.status == 'Pending'
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data['approvalStatus'],
                            style: TextStyle(
                              color: widget.status == 'Pending'
                                  ? Colors.orange
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    _buildInfoRow('Site', data['siteId']),
                    _buildInfoRow('Supervisor', data['supervisorName']),
                    _buildInfoRow('Project', data['projectName']),
                    _buildInfoRow('Stage', data['projectStage']),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDaysBox(
                            'Requested Days', data['reqDays'].toString()),
                        _buildDaysBox('Approved Days',
                            data['appDays']?.toString() ?? '-'),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPaymentBox(
                            'Estimated', data['estimatedPayment'].toString()),
                        _buildPaymentBox('Approved',
                            data['approvedPayment']?.toString() ?? '-'),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Labour Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildLabourTable(data['reqLabours'], 'Requested'),
                    if (data['appLabours'] != null)
                      Column(
                        children: [
                          SizedBox(height: 12),
                          _buildLabourTable(data['appLabours'], 'Approved'),
                        ],
                      ),
                    if (widget.status == 'Pending')
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _updateStatus(
                                    context, widget.docId, 'Approved');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Approve',
                                style: TextStyle(color: secondaryColor),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _updateStatus(
                                    context, widget.docId, 'Rejected');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Reject',
                                style: TextStyle(color: secondaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor.withOpacity(0.8)),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDaysBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: primaryColor.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: accentColor.withOpacity(0.8),
            ),
          ),
          Text(
            '₹$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourTable(List<dynamic> labours, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Table(
          columnWidths: {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
          border: TableBorder.all(
            color: Colors.grey,
            width: 1,
            borderRadius: BorderRadius.circular(4),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
              ),
              children: [
                _buildTableHeaderCell('Designation'),
                _buildTableHeaderCell('Count'),
                _buildTableHeaderCell('Salary'),
              ],
            ),
            ...labours.map((labour) {
              return TableRow(
                children: [
                  _buildTableCell(labour['labourDesignation']),
                  _buildTableCell(labour['labourCount'].toString()),
                  _buildTableCell('₹${labour['salary']}'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(text),
    );
  }

  void _updateStatus(
      BuildContext context, String docId, String newStatus) async {
    try {
      await FirestoreService
          .getCollection('siteSupervisorProjectStageSchedule')
          .doc(docId)
          .update({'approvalStatus': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}
