import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class OrgNotificationPage extends StatefulWidget {
  const OrgNotificationPage({super.key});

  @override
  State<OrgNotificationPage> createState() => _OrgNotificationPageState();
}

class _OrgNotificationPageState extends State<OrgNotificationPage> {
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Materials', 'Tools', 'Payments', 'Workforce'

  UserRole get _userRole => AuthService().userRole;

  String get _roleString {
    if (_userRole == UserRole.manager) return 'manager';
    return 'organisation';
  }

  Color get primaryColor => Theme.of(context).colorScheme.primary;

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
        title: Text(
          _userRole == UserRole.manager ? 'Manager Notifications' : 'Organization Notifications',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 16),
            label: const Text(
              'Read All',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await NotificationService.markAllReadForRole(role: _roleString);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800.0 : (isTablet ? 640.0 : double.infinity),
            ),
            child: Column(
              children: [
                // Filter Chips Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Unread'),
                        _buildFilterChip('Materials'),
                        _buildFilterChip('Tools'),
                        _buildFilterChip('Payments'),
                        _buildFilterChip('Workforce'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Notifications Stream List
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: NotificationService.streamForRole(role: _roleString),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final filteredDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final isRead = data['isRead'] == true;
                        final reqType = (data['requestType'] ?? '').toString().toLowerCase();

                        switch (_selectedFilter) {
                          case 'Unread':
                            return !isRead;
                          case 'Materials':
                            return reqType.contains('material');
                          case 'Tools':
                            return reqType.contains('tool');
                          case 'Payments':
                            return reqType.contains('payment');
                          case 'Workforce':
                            return reqType.contains('work') || reqType.contains('sched');
                          default:
                            return true;
                        }
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
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
            color: isSelected ? primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
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
    final createdAt = data['createdAt'];

    String timeStr = '';
    if (createdAt is Timestamp) {
      timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
      ),
      onDismissed: (_) => NotificationService.markAsRead(docId),
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : catColor.withValues(alpha: 0.35),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 6,
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                'View Details',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: catColor),
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
          Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No notifications in this filter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Workflow updates will appear here automatically.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String reqType) {
    if (reqType.contains('material')) return const Color(0xFFE11D48); // Rose
    if (reqType.contains('tool')) return const Color(0xFFD97706); // Amber
    if (reqType.contains('payment')) return const Color(0xFF059669); // Emerald
    if (reqType.contains('work') || reqType.contains('sched')) return const Color(0xFF6366F1); // Indigo
    return primaryColor;
  }

  IconData _getCategoryIcon(String reqType) {
    if (reqType.contains('material')) return Icons.inventory_2_rounded;
    if (reqType.contains('tool')) return Icons.construction_rounded;
    if (reqType.contains('payment')) return Icons.payments_rounded;
    if (reqType.contains('work') || reqType.contains('sched')) return Icons.groups_rounded;
    return Icons.notifications_rounded;
  }
}
