import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_text_field.dart';
import 'package:demo_cst/widgets/glass_button.dart';
import 'package:demo_cst/services/firestore_service.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;
    final maxModalWidth = 700.0;

    return GlassScaffold(
      title: 'Material Approval',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: "PENDING"),
                    Tab(text: "APPROVED"),
                  ],
                  labelColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isDesktop ? 16 : 14,
                  ),
                  unselectedLabelColor: const Color(0xFFCBD5E1),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isDesktop ? 16 : 14,
                  ),
                  indicatorColor: const Color(0xFF10B981),
                  indicatorWeight: 3,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: GlassTextField(
                  controller: _searchController,
                  label: 'Search Requests...',
                  labelColor: const Color(0xFF0A183D),
                  hintText: 'Search Requests...',
                  icon: Icons.search,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF0A183D)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: _buildRequestsList('Processing'),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: _buildRequestsList('Approved'),
                  ),
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

  Widget _buildRequestsList(String status) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxModalWidth = 700.0;

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: isDesktop ? 80 : 60,
                  color: const Color(0xFF0A183D),
                ),
                const SizedBox(height: 12),
                Text(
                  'No requests found.',
                  style: TextStyle(
                    color: const Color(0xFF0A183D),
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: isDesktop ? 80 : 60,
                  color: const Color(0xFF0A183D),
                ),
                const SizedBox(height: 12),
                Text(
                  'No $status requests found.',
                  style: TextStyle(
                    color: const Color(0xFF0A183D),
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _buildRequestCard(
              data,
              docId,
              isDesktop,
              isTablet,
              isMobile,
              maxModalWidth,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> data,
    String docId,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    double maxModalWidth,
  ) {
    final status = data['status'] ?? 'Processing';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showRequestDetails(
        data,
        docId,
        isDesktop,
        isTablet,
        isMobile,
        maxModalWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['matReqId'] ?? 'REQ-N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 16,
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
          const Divider(height: 24, color: Colors.white24),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 8),
              Text(
                "${(data['materials'] as List?)?.length ?? 0} Items",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                data['date'] ?? '',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isApproved = status.toLowerCase() == 'approved';
    final color = isApproved ? const Color(0xFF10B981) : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
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
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(
    Map<String, dynamic> data,
    String docId,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    double maxModalWidth,
  ) {
    final theme = Theme.of(context);
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final isProcessing = data['status'] == 'Processing';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxModalWidth),
          child: GlassCard(
            borderRadius: 24,
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 24)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.calendar_today_outlined, data['date'] ?? ''),
                  _infoRow(Icons.person_outline, data['supervisorName'] ?? ''),
                  const SizedBox(height: 24),
                  const Text(
                    'REQUESTED MATERIALS',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: materials.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white24),
                      itemBuilder: (c, i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          materials[i]['materialName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${materials[i]['materialQty']} ${materials[i]['materialUnit']}',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
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
                        final supName =
                            data['supervisorName']?.toString() ?? '';
                        final reqId = data['matReqId']?.toString() ?? '';
                        final siteId = data['siteId']?.toString() ?? '';
                        if (supName.isNotEmpty) {
                          await NotificationService.notifySupervisor(
                            supervisorName: supName,
                            title: '✅ Material Request Approved',
                                body: 'Your material request $reqId for Site $siteId has been approved by the organization.',
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
