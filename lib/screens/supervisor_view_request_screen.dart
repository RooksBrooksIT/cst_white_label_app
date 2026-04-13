import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

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
    final cs = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: 'Work Schedule Approvals',
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cs.primary,
              ),
              labelColor: cs.onPrimary,
              unselectedLabelColor: cs.onSurface.withOpacity(0.7),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
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
          ),
        ],
      ),
    );
  }
}

class ApprovalList extends StatefulWidget {
  final String status;
  final String supervisorName;

  const ApprovalList({
    super.key,
    required this.status,
    required this.supervisorName,
  });

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
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search by Request ID',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: cs.primary),
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
              filled: true,
              fillColor: cs.surface.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
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
            stream:
                FirestoreService.getCollection(
                      'siteSupervisorProjectStageSchedule',
                    )
                    .where('approvalStatus', isEqualTo: widget.status)
                    .where('supervisorName', isEqualTo: widget.supervisorName)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: cs.error),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: cs.primary),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: cs.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${widget.status} requests found',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
              if (_searchText.isNotEmpty) {
                final idx = docs.indexWhere((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['wsReqId'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_searchText.toLowerCase());
                });
                if (idx != -1) {
                  final match = docs.removeAt(idx);
                  docs.insert(0, match);
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
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

  const ApprovalCard({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.data;
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['projectName'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 32,
                        color: cs.primary,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
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
                    const SizedBox(height: 8),
                    Divider(color: cs.outlineVariant),
                    const SizedBox(height: 8),
                    _buildInfoRow('Site', data['siteId'], cs),
                    _buildInfoRow('Supervisor', data['supervisorName'], cs),
                    _buildInfoRow('Project', data['projectName'], cs),
                    _buildInfoRow('Stage', data['projectStage'], cs),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDaysBox(
                          'Requested Days',
                          data['reqDays'].toString(),
                          cs,
                        ),
                        _buildDaysBox(
                          'Approved Days',
                          data['appDays']?.toString() ?? '-',
                          cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPaymentBox(
                          'Estimated',
                          data['estimatedPayment'].toString(),
                          cs,
                        ),
                        _buildPaymentBox(
                          'Approved',
                          data['approvedPayment']?.toString() ?? '-',
                          cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Labour Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLabourTable(data['reqLabours'], 'Requested', cs),
                    if (data['appLabours'] != null)
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildLabourTable(data['appLabours'], 'Approved', cs),
                        ],
                      ),
                    if (widget.status == 'Pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _updateStatus(
                                  context,
                                  widget.docId,
                                  'Approved',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Approve'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _updateStatus(
                                  context,
                                  widget.docId,
                                  'Rejected',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Reject'),
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

  Widget _buildInfoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary.withOpacity(0.8),
            ),
          ),
          Text(value, style: TextStyle(color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _buildDaysBox(String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.primary.withOpacity(0.8)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBox(String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.secondary.withOpacity(0.8),
            ),
          ),
          Text(
            '₹$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourTable(
    List<dynamic> labours,
    String title,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cs.primary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
          border: TableBorder.all(
            color: cs.outlineVariant,
            width: 1,
            borderRadius: BorderRadius.circular(4),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.1)),
              children: [
                _buildTableHeaderCell('Designation', cs),
                _buildTableHeaderCell('Count', cs),
                _buildTableHeaderCell('Salary', cs),
              ],
            ),
            ...labours.map((labour) {
              return TableRow(
                children: [
                  _buildTableCell(labour['labourDesignation'], cs),
                  _buildTableCell(labour['labourCount'].toString(), cs),
                  _buildTableCell('₹${labour['salary']}', cs),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
      ),
    );
  }

  Widget _buildTableCell(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: TextStyle(color: cs.onSurface)),
    );
  }

  void _updateStatus(
    BuildContext context,
    String docId,
    String newStatus,
  ) async {
    try {
      await FirestoreService.getCollection(
        'siteSupervisorProjectStageSchedule',
      ).doc(docId).update({'approvalStatus': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }
}
