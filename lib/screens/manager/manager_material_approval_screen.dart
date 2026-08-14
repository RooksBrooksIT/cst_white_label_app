import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_text_field.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;

    return GlassScaffold(
      title: 'Material Approval',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: "PENDING"),
                        Tab(text: "APPROVED"),
                      ],
                      labelColor: isDark ? Colors.white : primaryColor,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                      unselectedLabelColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                      indicatorColor: primaryColor,
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
                      labelColor: isDark ? Colors.white : const Color(0xFF0A183D),
                      hintText: 'Search Requests...',
                      icon: Icons.search,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: isDark ? Colors.white70 : const Color(0xFF0A183D),
                              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: isDesktop ? 80 : 60,
                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No requests found.',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0A183D),
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
                  Icons.inbox_rounded,
                  size: isDesktop ? 80 : 60,
                  color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No $status requests found.',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0A183D),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final status = data['status'] ?? 'Processing';
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final subtextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final iconColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;

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
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textColor,
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
            iconColor: iconColor,
            textColor: textColor,
          ),
          _infoRow(
            Icons.business_outlined,
            data['projectName'] ?? 'No Project',
            iconColor: iconColor,
            textColor: textColor,
          ),
          _infoRow(
            Icons.person_outline,
            data['supervisorName'] ?? 'No Supervisor',
            iconColor: iconColor,
            textColor: textColor,
          ),
          Divider(
            height: 24,
            color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
          ),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: subtextColor,
              ),
              const SizedBox(width: 8),
              Text(
                "${(data['materials'] as List?)?.length ?? 0} Items",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                data['date'] ?? '',
                style: TextStyle(
                  color: subtextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isApproved = status.toLowerCase() == 'approved';
    final color = isApproved
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669))
        : Colors.amber.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
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

  Widget _infoRow(IconData icon, String value, {Color? iconColor, Color? textColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final effectiveIconColor = iconColor ?? (isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor);
    final effectiveTextColor = textColor ?? (isDark ? Colors.white : const Color(0xFF0A183D));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: effectiveIconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: effectiveTextColor,
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final isProcessing = data['status'] == 'Processing';
    final cardBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final subtextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final accentColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxModalWidth),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
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
                        color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    data['matReqId'] ?? 'Request Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.calendar_today_outlined, data['date'] ?? '', iconColor: accentColor, textColor: textColor),
                  _infoRow(Icons.person_outline, data['supervisorName'] ?? '', iconColor: accentColor, textColor: textColor),
                  const SizedBox(height: 24),
                  Text(
                    'REQUESTED MATERIALS',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: materials.length,
                      separatorBuilder: (_, index) => Divider(
                        height: 1,
                        color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (c, i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          materials[i]['materialName'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${materials[i]['materialQty']} ${materials[i]['materialUnit']}',
                          style: TextStyle(
                            color: subtextColor,
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'APPROVE REQUEST',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: primaryColor.withValues(alpha: 0.4),
                        ),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
