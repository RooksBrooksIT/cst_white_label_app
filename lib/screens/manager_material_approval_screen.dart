import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

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

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Material Approval',
      onBack: () => Navigator.pop(context),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRequestsTab('Processing'),
              _buildRequestsTab('Approved'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: "All Requests"),
          Tab(text: "Approved"),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(String status) {
    final controller = status == 'Processing' ? _processingSearchController : _approvedSearchController;
    final query = status == 'Processing' ? _processingSearchQuery : _approvedSearchQuery;

    return Column(
      children: [
        buildSearchBar(controller, (val) {
          setState(() {
            if (status == 'Processing') {
              _processingSearchQuery = val.trim().toLowerCase();
            } else {
              _approvedSearchQuery = val.trim().toLowerCase();
            }
          });
        }),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('siteMaterialsRequest')
                .where('status', isEqualTo: status)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No $status requests found.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (query.isEmpty) return true;
                return (data['matReqId'] ?? '').toString().toLowerCase().contains(query) ||
                    (data['siteId'] ?? '').toString().toLowerCase().contains(query) ||
                    (data['projectName'] ?? '').toString().toLowerCase().contains(query) ||
                    (data['supervisorName'] ?? '').toString().toLowerCase().contains(query);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  return _buildRequestCard(data, docId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data, String docId) {
    final bool isApproved = data['status'] == 'Approved';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showRequestDetailsModal(context, data, docId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['matReqId'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                _buildStatusBadge(data['status'] ?? ''),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.location_on, 'Site', data['siteId']),
            _infoRow(Icons.business, 'Project', data['projectName']),
            _infoRow(Icons.person, 'Supervisor', data['supervisorName']),
            _infoRow(Icons.calendar_today, 'Date', data['date']),
            const Divider(color: Colors.white12, height: 24),
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  "${(data['materials'] as List?)?.length ?? 0} Materials",
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isApproved = status == 'Approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isApproved ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isApproved ? Colors.green : Colors.orange).withOpacity(0.5),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isApproved ? Colors.green : Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(
              value ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestDetailsModal(BuildContext context, Map<String, dynamic> data, String docId) {
    final List materials = data['materials'] ?? [];
    final bool isProcessing = data['status'] == 'Processing';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassCard(
          borderRadius: 28,
          padding: EdgeInsets.zero,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.96,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['matReqId'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        _buildStatusBadge(data['status'] ?? ''),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _infoRow(Icons.location_on, "Site", data['siteId']),
                    _infoRow(Icons.business, "Project", data['projectName']),
                    _infoRow(Icons.person, "Supervisor", data['supervisorName']),
                    _infoRow(Icons.calendar_today, "Date", data['date']),
                    const SizedBox(height: 32),
                    const Text(
                      "Materials Selection",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...materials.map<Widget>((mat) => _buildMaterialTile(mat)),
                    const SizedBox(height: 32),
                    if (isProcessing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(docId),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve Materials'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMaterialTile(Map<String, dynamic> mat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory, color: Theme.of(context).colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['materialName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${mat['materialQty']} ${mat['materialUnit']} • Priority: ${mat['priority']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String docId) async {
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
  }

  Widget buildSearchBar(TextEditingController controller, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search requests...",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }
}
