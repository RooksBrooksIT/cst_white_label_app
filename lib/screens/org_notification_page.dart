import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../widgets/glass_scaffold.dart';

class OrgNotificationPage extends StatefulWidget {
  const OrgNotificationPage({super.key});

  @override
  State<OrgNotificationPage> createState() => _OrgNotificationPageState();
}

class _OrgNotificationPageState extends State<OrgNotificationPage> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.markAllReadForOrganisation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: 'Organization Notifications',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: NotificationService.streamForOrganisation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmpty(cs);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              final isRead = data['isRead'] == true;
              final title = data['title']?.toString() ?? 'Notification';
              final body = data['body']?.toString() ?? '';
              final createdAt = data['createdAt'];
              final type = data['type']?.toString() ?? '';
              
              String dateStr = '';
              if (createdAt is Timestamp) {
                dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
              }

              IconData icon = Icons.notifications_rounded;
              Color iconColor = cs.primary;

              if (type == 'material_request') {
                icon = Icons.inventory_2_rounded;
                iconColor = Colors.orange;
              } else if (type == 'work_schedule') {
                icon = Icons.event_available_rounded;
                iconColor = Colors.green;
              } else if (type == 'site_entry') {
                icon = Icons.description_rounded;
                iconColor = Colors.blue;
              } else if (type == 'tools_return') {
                icon = Icons.handyman_rounded;
                iconColor = Colors.purple;
              } else if (type == 'material_arrival') {
                icon = Icons.check_circle_rounded;
                iconColor = Colors.teal;
              }

              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: cs.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.delete_outline, color: cs.error),
                ),
                onDismissed: (_) => NotificationService.markAsRead(docId),
                child: GestureDetector(
                  onTap: () => NotificationService.markAsRead(docId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isRead ? cs.surface.withOpacity(0.7) : iconColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRead ? cs.outlineVariant.withOpacity(0.5) : iconColor.withOpacity(0.3),
                        width: isRead ? 1 : 1.5,
                      ),
                      boxShadow: [
                        if (!isRead)
                          BoxShadow(
                            color: iconColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: cs.onSurfaceVariant.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: !isRead
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: cs.primary.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests from supervisors will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
