import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/notification_service.dart';
import 'package:ebricks/utils/app_theme.dart';

class NotificationPage extends StatefulWidget {
  final String supervisorName;
  const NotificationPage({super.key, required this.supervisorName});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Action Needed', 'Approvals', 'Petty Cash', 'Materials', 'Tools', 'Declined'

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    // Mark all as read when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.markAllReadForSupervisor(widget.supervisorName);
    });
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
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Live Unread Badge
          StreamBuilder<int>(
            stream: NotificationService.unreadCountForSupervisor(widget.supervisorName),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$unreadCount new',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
          // Mark All Read Button
          TextButton.icon(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await NotificationService.markAllReadForSupervisor(widget.supervisorName);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read.'),
                  backgroundColor: Color(0xFF0F172A),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 16),
            label: const Text(
              'Read All',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Activity & Alerts'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.playlist_add_check_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('My Request Pipeline'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 840.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActivityAlertsTab(),
                _buildRequestPipelineTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: ACTIVITY & ALERTS
  // ===========================================================================
  Widget _buildActivityAlertsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationService.streamForSupervisor(widget.supervisorName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Count metrics for category chips
        final unreadCount = allDocs.where((d) => d.data()['isRead'] != true).length;
        final actionNeededCount = allDocs.where((d) {
          final data = d.data();
          final reqAction = (data['requiredAction'] ?? '').toString();
          final title = (data['title'] ?? '').toString().toLowerCase();
          return reqAction.isNotEmpty || title.contains('action') || title.contains('pending');
        }).length;
        final approvedCount = allDocs.where((d) {
          final title = (d.data()['title'] ?? '').toString().toLowerCase();
          return title.contains('approved') || title.contains('✅');
        }).length;

        // Filter notifications based on selected filter and search query
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data();
          final isRead = data['isRead'] == true;
          final title = (data['title'] ?? '').toString().toLowerCase();
          final body = (data['body'] ?? '').toString().toLowerCase();
          final reqType = (data['requestType'] ?? '').toString().toLowerCase();
          final siteId = (data['siteId'] ?? '').toString().toLowerCase();
          final reqAction = (data['requiredAction'] ?? '').toString().toLowerCase();

          // Category filter
          bool categoryMatch = true;
          switch (_selectedFilter) {
            case 'Unread':
              categoryMatch = !isRead;
              break;
            case 'Action Needed':
              categoryMatch = reqAction.isNotEmpty || title.contains('action') || title.contains('pending');
              break;
            case 'Approvals':
              categoryMatch = title.contains('approved') || title.contains('✅');
              break;
            case 'Petty Cash':
              categoryMatch = reqType.contains('payment') || reqType.contains('cash') || title.contains('petty') || title.contains('payment');
              break;
            case 'Materials':
              categoryMatch = reqType.contains('material') || title.contains('material');
              break;
            case 'Tools':
              categoryMatch = reqType.contains('tool') || title.contains('tool');
              break;
            case 'Declined':
              categoryMatch = title.contains('rejected') || title.contains('declined') || title.contains('❌');
              break;
            default:
              categoryMatch = true;
          }
          if (!categoryMatch) return false;

          // Search filter
          if (_searchQuery.isNotEmpty) {
            return title.contains(_searchQuery) ||
                body.contains(_searchQuery) ||
                siteId.contains(_searchQuery) ||
                reqType.contains(_searchQuery) ||
                reqAction.contains(_searchQuery);
          }

          return true;
        }).toList();

        return Column(
          children: [
            // 1. Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search alerts by site, action, or keyword...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),

            // 2. Category Filter Chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('All', allDocs.length),
                    _buildFilterChip('Unread', unreadCount),
                    _buildFilterChip('Action Needed', actionNeededCount),
                    _buildFilterChip('Approvals', approvedCount),
                    _buildFilterChip(
                      'Petty Cash',
                      allDocs.where((d) => (d.data()['requestType'] ?? '').toString().toLowerCase().contains('payment') || (d.data()['title'] ?? '').toString().toLowerCase().contains('petty')).length,
                    ),
                    _buildFilterChip(
                      'Materials',
                      allDocs.where((d) => (d.data()['requestType'] ?? '').toString().toLowerCase().contains('material') || (d.data()['title'] ?? '').toString().toLowerCase().contains('material')).length,
                    ),
                    _buildFilterChip(
                      'Tools',
                      allDocs.where((d) => (d.data()['requestType'] ?? '').toString().toLowerCase().contains('tool') || (d.data()['title'] ?? '').toString().toLowerCase().contains('tool')).length,
                    ),
                    _buildFilterChip(
                      'Declined',
                      allDocs.where((d) => (d.data()['title'] ?? '').toString().toLowerCase().contains('rejected') || (d.data()['title'] ?? '').toString().toLowerCase().contains('❌')).length,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 3. Notifications List
            Expanded(
              child: filteredDocs.isEmpty
                  ? _buildEmptyState(
                      title: 'No notifications found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'No matches for "$_searchQuery".'
                          : _selectedFilter != 'All'
                              ? 'No notifications found under "$_selectedFilter".'
                              : 'Approval updates and notifications will appear here.',
                    )
                  : RefreshIndicator(
                      color: primaryColor,
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          return _buildNotificationCard(filteredDocs[index]);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // FILTER CHIP WIDGET
  // ===========================================================================
  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: primaryColor,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (selected) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  // ===========================================================================
  // NOTIFICATION CARD
  // ===========================================================================
  Widget _buildNotificationCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final docId = doc.id;
    final isRead = data['isRead'] == true;
    final title = data['title']?.toString() ?? 'Notification';
    final body = data['body']?.toString() ?? '';
    final reqType = (data['requestType'] ?? '').toString().toLowerCase();
    final siteId = data['siteId']?.toString() ?? '';
    final siteName = data['siteName']?.toString() ?? '';
    final requiredAction = data['requiredAction']?.toString() ?? '';
    final createdAt = data['createdAt'];

    String timeStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        timeStr = '${diff.inDays}d ago';
      } else {
        timeStr = DateFormat('dd MMM, hh:mm a').format(dt);
      }
    }

    final isApproval = title.toLowerCase().contains('approved') || title.contains('✅');
    final isRejection = title.toLowerCase().contains('rejected') || title.toLowerCase().contains('declined') || title.contains('❌');
    final isCash = reqType.contains('payment') || reqType.contains('cash') || title.toLowerCase().contains('petty');

    final Color statusColor = isApproval
        ? const Color(0xFF059669) // Emerald
        : isRejection
            ? const Color(0xFFEF4444) // Red
            : isCash
                ? const Color(0xFF0284C7) // Sky Blue
                : _getCategoryColor(reqType);

    final IconData statusIcon = isApproval
        ? Icons.check_circle_rounded
        : isRejection
            ? Icons.cancel_rounded
            : _getCategoryIcon(reqType);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
      ),
      onDismissed: (_) {
        NotificationService.markAsRead(docId);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            NotificationService.markAsRead(docId);
            NotificationService.navigateToTarget(context, data);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead ? const Color(0xFFE2E8F0) : statusColor.withValues(alpha: 0.35),
                width: isRead ? 1.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRead
                      ? const Color(0xFF0F172A).withValues(alpha: 0.03)
                      : statusColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accent colored bar on the left
                    Container(
                      width: 5,
                      color: isRead
                          ? const Color(0xFFCBD5E1)
                          : statusColor,
                    ),

                    // Card Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Icon + Title + Unread Indicator
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(statusIcon, color: statusColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(left: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Body Message
                            Padding(
                              padding: const EdgeInsets.only(left: 46),
                              child: Text(
                                body,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475569),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Chips Row: Site, Required Action, Category
                            Padding(
                              padding: const EdgeInsets.only(left: 46),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (siteId.isNotEmpty || siteName.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF64748B)),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              siteName.isNotEmpty ? siteName : 'Site: $siteId',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (requiredAction.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFFEDD5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.pending_actions_rounded, size: 11, color: Color(0xFFEA580C)),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              requiredAction,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFC2410C),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Footer: Time and Action prompt
                            Padding(
                              padding: const EdgeInsets.only(left: 46),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (timeStr.isNotEmpty)
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Text(
                                        'View Details',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 10,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: MY REQUEST PIPELINE
  // ===========================================================================
  Widget _buildRequestPipelineTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('siteMaterialsRequest')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            title: 'No requests submitted',
            subtitle: 'Your submitted material requisitions will appear here with live tracking.',
          );
        }

        // Sort descending by date if available
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final da = (a.data() as Map<String, dynamic>)['date'];
          final db = (b.data() as Map<String, dynamic>)['date'];
          if (da is Timestamp && db is Timestamp) {
            return db.compareTo(da);
          }
          return 0;
        });

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            return _buildPipelineRequestCard(sortedDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildPipelineRequestCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String dateStr = 'N/A';
    if (data['date'] != null) {
      if (data['date'] is Timestamp) {
        dateStr = DateFormat('MMM dd, yyyy • hh:mm a')
            .format((data['date'] as Timestamp).toDate());
      } else if (data['date'] is String) {
        dateStr = data['date'];
      }
    }
    final status = (data['status'] ?? 'Processing').toString();
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              title: Text(
                'Request #${data['matReqId'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Site: ${data['siteId'] ?? 'N/A'} ${data['projectName'] != null ? '• ${data['projectName']}' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: _statusChip(status, statusColor),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow(Icons.calendar_today_outlined, dateStr),
                      if (data['supervisorName'] != null)
                        _detailRow(Icons.person_outline_rounded, data['supervisorName'].toString()),
                      const SizedBox(height: 10),
                      const Text(
                        'Requested Items:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (data['materials'] is List)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: List<Widget>.from(
                              (data['materials'] as List).map(
                                (mat) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          color: primaryColor, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${mat['materialName'] ?? 'Item'}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '${mat['materialQty'] ?? ''} ${mat['materialUnit'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            if (_selectedFilter != 'All' || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'All';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF059669);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'processing':
        return const Color(0xFFD97706);
      case 'delivered':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'processing':
        return Icons.hourglass_top_rounded;
      case 'delivered':
        return Icons.local_shipping_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Color _getCategoryColor(String reqType) {
    if (reqType.contains('material')) return const Color(0xFF2563EB); // Blue
    if (reqType.contains('tool')) return const Color(0xFFD97706); // Amber
    if (reqType.contains('payment') || reqType.contains('cash')) return const Color(0xFF059669); // Emerald
    if (reqType.contains('work') || reqType.contains('sched')) {
      return const Color(0xFF6366F1); // Indigo
    }
    if (reqType.contains('site')) return const Color(0xFF0284C7); // Sky
    return primaryColor;
  }

  IconData _getCategoryIcon(String reqType) {
    if (reqType.contains('material')) return Icons.inventory_2_rounded;
    if (reqType.contains('tool')) return Icons.construction_rounded;
    if (reqType.contains('payment') || reqType.contains('cash')) return Icons.payments_rounded;
    if (reqType.contains('work') || reqType.contains('sched')) {
      return Icons.groups_rounded;
    }
    if (reqType.contains('site')) return Icons.location_city_rounded;
    return Icons.notifications_rounded;
  }
}