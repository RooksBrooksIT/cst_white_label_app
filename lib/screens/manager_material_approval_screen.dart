import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerMaterialApprovalScreen extends StatefulWidget {
  const ManagerMaterialApprovalScreen({super.key});

  @override
  State<ManagerMaterialApprovalScreen> createState() =>
      _ManagerMaterialApprovalScreenState();
}

class _ManagerMaterialApprovalScreenState
    extends State<ManagerMaterialApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _processingSearchController = TextEditingController();
  final TextEditingController _approvedSearchController = TextEditingController();
  String _processingSearchQuery = '';
  String _approvedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _processingSearchController.dispose();
    _approvedSearchController.dispose();
    super.dispose();
  }

  EdgeInsets getSymmetricPadding(BuildContext context, {double fraction = 0.06}) {
    double width = MediaQuery.of(context).size.width;
    return EdgeInsets.symmetric(horizontal: width * fraction);
  }

  Widget buildSearchBar(TextEditingController controller, Function(String) onChanged) {
    return Padding(
      padding: getSymmetricPadding(context, fraction: 0.04).copyWith(top: 10, bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: "Search requests...",
          prefixIcon: Icon(Icons.search, color: Color(0xFF0b3470)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF0b3470)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF0b3470).withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF0b3470)),
          ),
          
          filled: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        cursorColor: Color(0xFF0b3470),
        style: TextStyle(),
        onChanged: onChanged,
      ),
    );
  }

  Widget buildRequestCard(Map<String, dynamic> data, String docId) {
    final List materials = data['materials'] ?? [];
    final bool isApproved = data['status'] == 'Approved';
    return GestureDetector(
      onTap: () => _showRequestDetailsModal(context, data, docId),
      child: Card(
        margin: getSymmetricPadding(context, fraction: 0.04).copyWith(top: 12, bottom: 10),
        
        elevation: 6,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, color: Color(0xFF0b3470), size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data['matReqId'] ?? '',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0b3470),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isApproved
                            ? [Colors.green.shade100, Colors.white]
                            : [Colors.orange.shade100, Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                          color: isApproved ? Colors.green.shade400 : Colors.orange.shade400),
                    ),
                    child: Text(
                      data['status'] ?? '',
                      style: TextStyle(
                        color: isApproved ? Colors.green.shade800 : Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text("Site: ${data['siteId'] ?? ''}",
                  style: TextStyle(fontSize: 16, )),
              Text("Project: ${data['projectName'] ?? ''}",
                  style: TextStyle(fontSize: 16, )),
              Text("Supervisor: ${data['supervisorName'] ?? ''}",
                  style: TextStyle(fontSize: 16, )),
              Text("Date: ${data['date'] ?? ''}",
                  style: TextStyle(fontSize: 15, )),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Color(0xFF0b3470), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "${materials.length} Materials",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetailsModal(BuildContext context, Map<String, dynamic> data, String docId) {
    final List materials = data['materials'] ?? [];
    final bool isProcessing = data['status'] == 'Processing';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.96,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: getSymmetricPadding(context, fraction: 0.06).copyWith(top: 32, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['matReqId'] ?? '',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0b3470),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: data['status'] == 'Approved'
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data['status'] ?? '',
                              style: TextStyle(
                                color: data['status'] == 'Approved'
                                    ? Colors.green[800]
                                    : Colors.orange[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      Divider(thickness: 1.1),
                      SizedBox(height: 10),
                      infoRow(Icons.location_on, "Site:", data['siteId']),
                      SizedBox(height: 8),
                      infoRow(Icons.business, "Project:", data['projectName']),
                      SizedBox(height: 8),
                      infoRow(Icons.person, "Supervisor:", data['supervisorName']),
                      SizedBox(height: 8),
                      infoRow(Icons.calendar_today, "Date:", data['date']),
                      SizedBox(height: 26),
                      Text("Materials Requested",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF0b3470))),
                      SizedBox(height: 12),
                      ...materials.map<Widget>((mat) => materialTile(mat)),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isProcessing)
                            ElevatedButton.icon(
                              icon: Icon(Icons.check, ),
                              label: Text("Approve",
                                  style: TextStyle( fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0b3470),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('siteMaterialsRequest')
                                      .doc(docId)
                                      .update({'status': 'Approved'});
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to approve: $e')),
                                  );
                                }
                              },
                            ),
                          if (isProcessing) SizedBox(width: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text("Close",
                                style:
                                    TextStyle( fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget infoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF0b3470), size: 20),
        SizedBox(width: 7),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value ?? '', overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget materialTile(Map<String, dynamic> mat) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow( blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFF0b3470).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory, color: Color(0xFF0b3470), size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mat['materialName'] ?? 'Unknown Material',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Quantity: ${mat['materialQty']} ${mat['materialUnit']}',
                    style: TextStyle(fontSize: 14, ),
                  ),
                  Text(
                    'Priority: ${mat['priority']}',
                    style: TextStyle(fontSize: 14, ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Material Approval",
          style: TextStyle( fontWeight: FontWeight.w700, fontSize: 22),
        ),
        centerTitle: true,
        elevation: 3,
        backgroundColor: Color(0xFF0b3470),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Material(
            
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFF0b3470),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Color(0xFF0b3470),
              indicatorWeight: 4,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              unselectedLabelStyle: TextStyle(fontSize: 16),
              tabs: [
                Tab(text: "All Requests"),
                Tab(text: "Approved"),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Processing Requests Tab with search
            Column(
              children: [
                buildSearchBar(_processingSearchController, (query) {
                  setState(() => _processingSearchQuery = query.trim().toLowerCase());
                }),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('siteMaterialsRequest')
                        .where('status', isEqualTo: 'Processing')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: Color(0xFF0b3470)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text('No processing requests found.',
                              style: TextStyle(fontSize: 18, )),
                        );
                      }
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final query = _processingSearchQuery;
                        if (query.isEmpty) return true;
                        return (data['matReqId'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['siteId'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['projectName'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['supervisorName'] ?? '').toString().toLowerCase().contains(query);
                      }).toList();
                      return ListView.builder(
                        padding: EdgeInsets.only(bottom: 28, top: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          return buildRequestCard(data, docId);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // Approved Requests Tab with search
            Column(
              children: [
                buildSearchBar(_approvedSearchController, (query) {
                  setState(() => _approvedSearchQuery = query.trim().toLowerCase());
                }),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('siteMaterialsRequest')
                        .where('status', isEqualTo: 'Approved')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: Color(0xFF0b3470)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text('No approved requests',
                              style: TextStyle(fontSize: 18, )),
                        );
                      }
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final query = _approvedSearchQuery;
                        if (query.isEmpty) return true;
                        return (data['matReqId'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['siteId'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['projectName'] ?? '').toString().toLowerCase().contains(query) ||
                            (data['supervisorName'] ?? '').toString().toLowerCase().contains(query);
                      }).toList();
                      return ListView.builder(
                        padding: EdgeInsets.only(bottom: 28, top: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          return buildRequestCard(data, docId);
                        },
                      );
                    },
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
