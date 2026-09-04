import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ManagerNotificationScreen extends StatefulWidget {
  const ManagerNotificationScreen({super.key});

  @override
  State<ManagerNotificationScreen> createState() =>
      _ManagerNotificationScreenState();
}

class _ManagerNotificationScreenState extends State<ManagerNotificationScreen> {
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Materials', 'Tools', 'Payments', 'Workforce', 'Sites', 'Scheduled'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
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
            stream: NotificationService.unreadCountForRole(role: 'manager'),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
          TextButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await NotificationService.markAllReadForRole(role: 'manager');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read.'),
                  backgroundColor: Color(0xFF0F172A),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
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
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isDesktop ? 840.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: Column(
              children: [
                // 1. Search Bar
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search by site, supervisor, request ID or keyword...',
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
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),

                // 2. Filter Chips Bar with Live Counts
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: NotificationService.streamForRole(role: 'manager'),
                  builder: (context, snapshot) {
                    final allDocs = snapshot.data?.docs ?? [];
                    final unreadTotal =
                        allDocs.where((d) => d.data()['isRead'] != true).length;
                    final materialsTotal = allDocs
                        .where((d) => (d.data()['requestType'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains('material'))
                        .length;
                    final toolsTotal = allDocs
                        .where((d) => (d.data()['requestType'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains('tool'))
                        .length;
                    final paymentsTotal = allDocs
                        .where((d) => (d.data()['requestType'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains('payment'))
                        .length;
                    final workforceTotal = allDocs
                        .where((d) =>
                            (d.data()['requestType'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('work') ||
                            (d.data()['requestType'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('sched'))
                        .length;
                    final sitesTotal = allDocs
                        .where((d) => (d.data()['requestType'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains('site'))
                        .length;

                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('All', allDocs.length),
                            _buildFilterChip('Unread', unreadTotal),
                            _buildFilterChip('Materials', materialsTotal),
                            _buildFilterChip('Tools', toolsTotal),
                            _buildFilterChip('Payments', paymentsTotal),
                            _buildFilterChip('Workforce', workforceTotal),
                            _buildFilterChip('Sites', sitesTotal),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // 3. Real-Time Notifications Stream List
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: NotificationService.streamForRole(role: 'manager'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allDocs = snapshot.data?.docs ?? [];

                      // Apply search and category filter in real-time
                      final filteredDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final isRead = data['isRead'] == true;
                        final title =
                            (data['title'] ?? '').toString().toLowerCase();
                        final body =
                            (data['body'] ?? '').toString().toLowerCase();
                        final reqType = (data['requestType'] ?? '')
                            .toString()
                            .toLowerCase();
                        final siteId =
                            (data['siteId'] ?? '').toString().toLowerCase();
                        final siteName =
                            (data['siteName'] ?? '').toString().toLowerCase();
                        final senderName =
                            (data['senderName'] ?? '').toString().toLowerCase();
                        final reqId =
                            (data['requestId'] ?? '').toString().toLowerCase();

                        // 1. Category Filter Match
                        bool categoryMatch = true;
                        switch (_selectedFilter) {
                          case 'Unread':
                            categoryMatch = !isRead;
                            break;
                          case 'Materials':
                            categoryMatch = reqType.contains('material');
                            break;
                          case 'Tools':
                            categoryMatch = reqType.contains('tool');
                            break;
                          case 'Payments':
                            categoryMatch = reqType.contains('payment');
                            break;
                          case 'Workforce':
                            categoryMatch = reqType.contains('work') ||
                                reqType.contains('sched');
                            break;
                          case 'Sites':
                            categoryMatch = reqType.contains('site');
                            break;
                          default:
                            categoryMatch = true;
                        }

                        if (!categoryMatch) return false;

                        // 2. Search Query Match
                        if (_searchQuery.isNotEmpty) {
                          final queryMatch = title.contains(_searchQuery) ||
                              body.contains(_searchQuery) ||
                              siteId.contains(_searchQuery) ||
                              siteName.contains(_searchQuery) ||
                              senderName.contains(_searchQuery) ||
                              reqId.contains(_searchQuery);
                          if (!queryMatch) return false;
                        }

                        return true;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          return _buildNotificationCard(doc.data(), doc.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = label);
        },
        selectedColor: primaryColor.withValues(alpha: 0.15),
        checkmarkColor: primaryColor,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? primaryColor : const Color(0xFF64748B),
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, String docId) {
    final isRead = data['isRead'] == true;
    final title = data['title']?.toString() ?? 'Notification';
    final body = data['body']?.toString() ?? '';
    final reqType = (data['requestType'] ?? '').toString().toLowerCase();
    final siteId = data['siteId']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? '';
    final senderRole = data['senderRole']?.toString() ?? '';
    final createdAt = data['createdAt'];

    String timeStr = '';
    if (createdAt is Timestamp) {
      timeStr =
          DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
    }

    final catColor = _getCategoryColor(reqType);
    final catIcon = _getCategoryIcon(reqType);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
      ),
      onDismissed: (_) => NotificationService.markAsRead(docId),
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? const Color(0xFFE2E8F0)
                : catColor.withValues(alpha: 0.35),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            NotificationService.markAsRead(docId);
            NotificationService.navigateToTarget(context, data);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: catColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Unread Dot + Title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 6),
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Body Text
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tags & Metadata Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (siteId.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.place_rounded,
                                    size: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    siteId,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (senderName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                senderRole.isNotEmpty
                                    ? '$senderRole: $senderName'
                                    : senderName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Bottom Time & Action Link
                      Row(
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
                                'View & Review',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: catColor,
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'No notifications found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching results for "$_searchQuery".'
                : 'Requisitions and site updates will appear here automatically.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String reqType) {
    if (reqType.contains('material')) return const Color(0xFFE11D48); // Rose
    if (reqType.contains('tool')) return const Color(0xFFD97706); // Amber
    if (reqType.contains('payment')) return const Color(0xFF059669); // Emerald
    if (reqType.contains('work') || reqType.contains('sched')) {
      return const Color(0xFF6366F1); // Indigo
    }
    if (reqType.contains('site')) return const Color(0xFF2563EB); // Blue
    if (reqType.contains('sched') || reqType.contains('remind')) {
      return const Color(0xFF9333EA); // Purple
    }
    return primaryColor;
  }

  IconData _getCategoryIcon(String reqType) {
    if (reqType.contains('material')) return Icons.inventory_2_rounded;
    if (reqType.contains('tool')) return Icons.construction_rounded;
    if (reqType.contains('payment')) return Icons.payments_rounded;
    if (reqType.contains('work') || reqType.contains('sched')) {
      return Icons.groups_rounded;
    }
    if (reqType.contains('site')) return Icons.location_city_rounded;
    if (reqType.contains('sched') || reqType.contains('remind')) {
      return Icons.alarm_rounded;
    }
    return Icons.notifications_rounded;
  }
}
