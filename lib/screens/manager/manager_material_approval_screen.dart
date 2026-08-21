import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

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
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Request Approval',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
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
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: Column(
              children: [
                // TabBar Container
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: "PENDING"),
                      Tab(text: "APPROVED"),
                    ],
                    labelColor: primaryColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelColor: const Color(0xFF64748B),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Material Requests...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 1.8),
                      ),
                    ),
                  ),
                ),

                // TabBarView
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
          ),
        ),
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
          return const Center(
            child: Text(
              'Error loading requests',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(status);
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docStatus = (data['status'] ?? '').toString().toLowerCase();
          if (docStatus != status.toLowerCase()) return false;

          if (_searchQuery.isEmpty) return true;
          final searchStr =
              '${data['matReqId']} ${data['siteId']} ${data['projectName']} ${data['supervisorName']}'
                  .toLowerCase();
          return searchStr.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState(status);
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildEmptyState(String status) {
    final displayStatus = status.toLowerCase() == 'processing' ? 'Pending' : status;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_rounded,
              size: 64,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              'No $displayStatus Requests Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A183D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No material requests are currently in this list.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'Processing';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRequestDetails(data, docId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        data['matReqId'] ?? 'REQ-N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.place_rounded, data['siteId'] ?? 'Unknown Site'),
              _infoRow(Icons.assignment_rounded, data['projectName'] ?? 'No Project'),
              _infoRow(Icons.person_rounded, data['supervisorName'] ?? 'No Supervisor'),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              Row(
                children: [
                  const Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${(data['materials'] as List?)?.length ?? 0} Items",
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    data['date'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isApproved = status.toLowerCase() == 'approved';
    final color = isApproved ? const Color(0xFF10B981) : Colors.amber.shade900;
    final displayStatus = status.toLowerCase() == 'processing' ? 'Pending' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? const Color(0xFF10B981).withValues(alpha: 0.15)
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus.toUpperCase(),
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
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> data, String docId) {
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final isProcessing = (data['status'] ?? '').toString().toLowerCase() == 'processing';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700.0),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['matReqId'] ?? 'Request Details',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.calendar_today_rounded, data['date'] ?? ''),
                  _infoRow(Icons.person_rounded, data['supervisorName'] ?? ''),
                  _infoRow(Icons.place_rounded, data['siteId'] ?? ''),
                  const SizedBox(height: 20),
                  Text(
                    'REQUESTED MATERIALS',
                    style: TextStyle(
                      letterSpacing: 1.1,
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: materials.length,
                      separatorBuilder: (_, index) => const Divider(
                        height: 1,
                        color: Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (c, i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          materials[i]['materialName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          '${materials[i]['materialQty']} ${materials[i]['materialUnit']}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'APPROVE REQUEST',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final nav = Navigator.of(ctx);
                          await FirestoreService.getCollection(
                            'siteMaterialsRequest',
                          ).doc(docId).update({'status': 'Approved'});

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

                          nav.pop();
                        },
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

  Widget _buildPriorityChip(String priority) {
    final isHigh = priority.toLowerCase() == 'high';
    final color = isHigh ? Colors.red.shade700 : primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
