import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final cs = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: 'Organization Notifications',
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                separatorBuilder: (_, _) => const SizedBox(height: 12),
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

                  if (type == 'material_request' || type == 'supervisor_request') {
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
                        color: cs.error.withValues(alpha: 0.1),
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
                          color: isRead ? cs.surface.withValues(alpha: 0.7) : iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRead ? cs.outlineVariant.withValues(alpha: 0.5) : iconColor.withValues(alpha: 0.3),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            if (!isRead)
                              BoxShadow(
                                color: iconColor.withValues(alpha: 0.1),
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
                              color: iconColor.withValues(alpha: 0.15),
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
                              if (data['data'] != null && data['data']['requestId'] != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _handleApproveRequest(context, data),
                                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _handleRejectRequest(context, data),
                                      icon: const Icon(Icons.cancel_rounded, size: 14),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
        ),
      ),
    );
  }

  Future<void> _handleApproveRequest(BuildContext context, Map<String, dynamic> notifData) async {
    final reqData = notifData['data'] as Map<String, dynamic>?;
    final requestId = reqData?['requestId']?.toString();
    final supervisorName = reqData?['supervisorName']?.toString() ?? 'Supervisor';
    final title = notifData['title']?.toString() ?? 'Supervisor Request';

    if (requestId == null || requestId.isEmpty) return;

    try {
      await FirestoreService.getCollection('supervisor_requests').doc(requestId).update({
        'status': 'Approved',
        'adminRemark': 'Approved by Organization Admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.notifySupervisor(
        supervisorName: supervisorName,
        title: 'Request Approved ✅',
        body: 'Your request "$title" has been approved by the Organization.',
        data: {'type': 'request_update', 'status': 'Approved'},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Approved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRejectRequest(BuildContext context, Map<String, dynamic> notifData) async {
    final reqData = notifData['data'] as Map<String, dynamic>?;
    final requestId = reqData?['requestId']?.toString();
    final supervisorName = reqData?['supervisorName']?.toString() ?? 'Supervisor';
    final title = notifData['title']?.toString() ?? 'Supervisor Request';
    final remarkController = TextEditingController();

    if (requestId == null || requestId.isEmpty) return;

    showDialog(
      context: context,
      builder: (diagCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Specify reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                hintText: 'e.g., Budget unapproved or material unavailable',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final remark = remarkController.text.trim();
              Navigator.pop(diagCtx);

              try {
                await FirestoreService.getCollection('supervisor_requests').doc(requestId).update({
                  'status': 'Rejected',
                  'adminRemark': remark.isNotEmpty ? remark : 'Rejected by Organization Admin',
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                await NotificationService.notifySupervisor(
                  supervisorName: supervisorName,
                  title: 'Request Rejected ❌',
                  body: 'Your request "$title" was rejected. Reason: ${remark.isNotEmpty ? remark : "Not specified"}',
                  data: {'type': 'request_update', 'status': 'Rejected'},
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request Rejected'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject Request'),
          ),
        ],
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
              color: cs.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: cs.primary.withValues(alpha: 0.2),
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
