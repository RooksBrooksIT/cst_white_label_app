import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../services/firestore_service.dart';

class ManagerMaterialApprovalScreen extends StatefulWidget {
  const ManagerMaterialApprovalScreen({super.key});

  @override
  State<ManagerMaterialApprovalScreen> createState() =>
      _ManagerMaterialApprovalScreenState();
}

class _ManagerMaterialApprovalScreenState
    extends State<ManagerMaterialApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      title: 'Material Approval',
      appBarBackgroundColor: theme.colorScheme.primary,
      appBarForegroundColor: theme.colorScheme.onPrimary,
      body: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "PENDING"),
                Tab(text: "APPROVED"),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassTextField(
              controller: _searchController,
              label: 'Search Requests...',
              icon: Icons.search,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList('Processing'),
                _buildRequestsList('Approved'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection(
        'siteMaterialsRequest',
      ).orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading requests',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No requests found.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Match status case-insensitively
          final docStatus = (data['status'] ?? '').toString().toLowerCase();
          if (docStatus != status.toLowerCase()) return false;

          if (_searchQuery.isEmpty) return true;
          final searchStr =
              '${data['matReqId']} ${data['siteId']} ${data['projectName']} ${data['supervisorName']}'
                  .toLowerCase();
          return searchStr.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $status requests found.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _buildRequestCard(data, docId);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data, String docId) {
    final theme = Theme.of(context);
    final status = data['status'] ?? 'Processing';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showRequestDetails(data, docId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['matReqId'] ?? 'REQ-N/A',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.location_on_outlined,
            data['siteId'] ?? 'Unknown Site',
          ),
          _infoRow(
            Icons.business_outlined,
            data['projectName'] ?? 'No Project',
          ),
          _infoRow(
            Icons.person_outline,
            data['supervisorName'] ?? 'No Supervisor',
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                "${(data['materials'] as List?)?.length ?? 0} Items",
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(data['date'] ?? '', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isApproved = status == 'Approved';
    final color = isApproved ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> data, String docId) {
    final theme = Theme.of(context);
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final isProcessing = data['status'] == 'Processing';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                data['matReqId'] ?? 'Request Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow(Icons.calendar_today_outlined, data['date'] ?? ''),
              _infoRow(Icons.person_outline, data['supervisorName'] ?? ''),
              const SizedBox(height: 24),
              Text(
                'REQUESTED MATERIALS',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: materials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      materials[i]['materialName'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${materials[i]['materialQty']} ${materials[i]['materialUnit']}',
                    ),
                    trailing: _buildPriorityChip(
                      materials[i]['priority'] ?? 'Normal',
                    ),
                  ),
                ),
              ),
              if (isProcessing) ...[
                const SizedBox(height: 32),
                GlassButton(
                  label: 'APPROVE REQUEST',
                  onPressed: () async {
                    await FirestoreService.getCollection(
                      'siteMaterialsRequest',
                    ).doc(docId).update({'status': 'Approved'});

                    // Notify supervisor of material approval
                    final supName = data['supervisorName']?.toString() ?? '';
                    final reqId = data['matReqId']?.toString() ?? '';
                    final siteId = data['siteId']?.toString() ?? '';
                    if (supName.isNotEmpty) {
                      await NotificationService.notifySupervisor(
                        supervisorName: supName,
                        title: '✅ Material Request Approved',
                        body:
                            'Your material request $reqId for Site $siteId has been approved by the organization.',
                        data: {
                          'type': 'material_approval',
                          'matReqId': reqId,
                          'siteId': siteId,
                          'status': 'Approved',
                        },
                      );
                    }

                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final color = priority.toLowerCase() == 'high' ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
