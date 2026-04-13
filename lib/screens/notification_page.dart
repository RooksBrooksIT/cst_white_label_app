import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  final String supervisorName;
  const NotificationPage({super.key, required this.supervisorName});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Mark all as read when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.markAllReadForSupervisor(widget.supervisorName);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Approval Updates'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovalNotifications(primary),
          _buildMaterialRequestsList(primary),
        ],
      ),
    );
  }

  // TAB 1 — Approval/rejection notifications from the notifications collection
  Widget _buildApprovalNotifications(Color primary) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationService.streamForSupervisor(widget.supervisorName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty('No notifications yet',
              'Approvals and rejections will appear here.');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final docId = docs[index].id;
            final isRead = data['isRead'] == true;
            final title = data['title']?.toString() ?? '';
            final body = data['body']?.toString() ?? '';
            final createdAt = data['createdAt'];
            String dateStr = '';
            if (createdAt is Timestamp) {
              dateStr = DateFormat('MMM dd, yyyy • hh:mm a')
                  .format(createdAt.toDate());
            }

            final isApproval = title.contains('Approved') ||
                title.contains('✅');
            final isRejection = title.contains('Rejected') ||
                title.contains('❌');

            final statusColor = isApproval
                ? Colors.green
                : isRejection
                    ? Colors.red
                    : Colors.orange;
            final statusIcon = isApproval
                ? Icons.check_circle_rounded
                : isRejection
                    ? Icons.cancel_rounded
                    : Icons.notifications_rounded;

            return Dismissible(
              key: Key(docId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red.shade700),
              ),
              onDismissed: (_) =>
                  NotificationService.markAsRead(docId),
              child: GestureDetector(
                onTap: () => NotificationService.markAsRead(docId),
                child: Container(
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white
                        : statusColor.withOpacity(0.06),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : statusColor.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(body,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(dateStr,
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11)),
                        ],
                      ],
                    ),
                    trailing: !isRead
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
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
    );
  }

  // TAB 2 — Material requests submitted by this supervisor
  Widget _buildMaterialRequestsList(Color primary) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('siteMaterialsRequest')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty('No requests submitted',
              'Your material requests will appear here.');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String date = 'N/A';
            if (data['date'] != null) {
              if (data['date'] is Timestamp) {
                date = DateFormat('MMM dd, yyyy - hh:mm a')
                    .format((data['date'] as Timestamp).toDate());
              } else if (data['date'] is String) {
                date = data['date'];
              }
            }
            final status = data['status'] ?? 'Processing';
            final statusColor = _statusColor(status);

            return Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(status),
                        color: statusColor, size: 20),
                  ),
                  title: Text(
                    'Request #${data['matReqId'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Site: ${data['siteId'] ?? 'N/A'}  •  ${data['projectName'] ?? ''}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: _statusChip(status, statusColor),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(Icons.calendar_today_outlined, date),
                          _detailRow(Icons.person_outline,
                              data['supervisorName'] ?? 'N/A'),
                          const Divider(height: 20),
                          const Text('Materials:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          if (data['materials'] is List)
                            ...List<Widget>.from(
                              (data['materials'] as List).map((mat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.arrow_right,
                                            color: primary, size: 18),
                                        Expanded(
                                          child: Text(
                                            '${mat['materialName']}  •  '
                                            '${mat['materialQty']} ${mat['materialUnit']}',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13))),
      ]),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'delivered':
        return Colors.teal;
      default:
        return Colors.grey;
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
        return Icons.notifications_rounded;
    }
  }
}