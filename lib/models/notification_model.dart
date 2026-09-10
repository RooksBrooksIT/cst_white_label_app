import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorizes all domain notification events across the CST White Label (eBricks) platform.
enum NotificationType {
  materialRequisition,
  toolsRequisition,
  paymentRequisition,
  workforceSchedule,
  pettyCashRequest,
  pettyCashTopup,
  pettyCashDispatched,
  organizationExpense,
  managerExpense,
  siteAssignment,
  siteCreated,
  managerAccountCreated,
  supervisorAccountCreated,
  toolMovement,
  dailyWorkSchedule,
  scheduledReminder,
  subscriptionExpiry,
  general,
}

/// Authoritative Notification Data Model matching the 4-tier reactive notification architecture.
/// Encapsulates all metadata required by both Firestore in-app feeds and FCM device push delivery.
class NotificationModel {
  final String notificationId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final String recipientId;
  final String? recipientRole;
  final String? senderId;
  final String? senderName;
  final String? senderRole;
  final String? siteId;
  final String? siteName;
  final String? requestId;
  final String? docId;
  final String? status;
  final String? remarks;
  final String? requiredAction;
  final Timestamp createdAt;
  final Timestamp? readAt;
  final String priority; // 'normal' | 'high' | 'urgent'
  final String? actionRoute;
  final Map<String, dynamic>? actionData;
  final String? tenantId;
  final String? orgId;

  NotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    this.type = NotificationType.general,
    this.isRead = false,
    this.recipientId = 'all',
    this.recipientRole,
    this.senderId,
    this.senderName,
    this.senderRole,
    this.siteId,
    this.siteName,
    this.requestId,
    this.docId,
    this.status,
    this.remarks,
    this.requiredAction,
    Timestamp? createdAt,
    this.readAt,
    this.priority = 'normal',
    this.actionRoute,
    this.actionData,
    this.tenantId,
    this.orgId,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = (docId ??
            map['notificationId'] ??
            map['id'] ??
            map['requestId'] ??
            map['docId'] ??
            '')
        .toString();

    final typeStr =
        (map['type'] ?? map['requestType'] ?? '').toString().toLowerCase();

    NotificationType parsedType = NotificationType.general;
    if (typeStr.contains('material')) {
      parsedType = NotificationType.materialRequisition;
    } else if (typeStr.contains('tool_movement') ||
        typeStr.contains('toolmovement')) {
      parsedType = NotificationType.toolMovement;
    } else if (typeStr.contains('tool')) {
      parsedType = NotificationType.toolsRequisition;
    } else if (typeStr.contains('payment')) {
      parsedType = NotificationType.paymentRequisition;
    } else if (typeStr.contains('petty_cash') || typeStr.contains('petty')) {
      parsedType = NotificationType.pettyCashRequest;
    } else if (typeStr.contains('org_expense') ||
        typeStr.contains('organization_expense')) {
      parsedType = NotificationType.organizationExpense;
    } else if (typeStr.contains('manager_expense')) {
      parsedType = NotificationType.managerExpense;
    } else if (typeStr.contains('site_assignment') ||
        typeStr.contains('supervisor_entry')) {
      parsedType = NotificationType.siteAssignment;
    } else if (typeStr.contains('workforce') ||
        typeStr.contains('worker') ||
        typeStr.contains('schedule')) {
      parsedType = NotificationType.workforceSchedule;
    } else if (typeStr.contains('site_created') ||
        typeStr.contains('site_management')) {
      parsedType = NotificationType.siteCreated;
    } else if (typeStr.contains('manager_account') ||
        typeStr.contains('manager_config')) {
      parsedType = NotificationType.managerAccountCreated;
    } else if (typeStr.contains('supervisor_account') ||
        typeStr.contains('supervisor_config')) {
      parsedType = NotificationType.supervisorAccountCreated;
    } else if (typeStr.contains('scheduled') ||
        typeStr.contains('reminder')) {
      parsedType = NotificationType.scheduledReminder;
    } else if (typeStr.contains('subscription')) {
      parsedType = NotificationType.subscriptionExpiry;
    }

    Timestamp parsedCreatedAt = Timestamp.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = map['createdAt'];
    } else if (map['createdAt'] is String) {
      try {
        parsedCreatedAt = Timestamp.fromDate(DateTime.parse(map['createdAt']));
      } catch (_) {}
    }

    Timestamp? parsedReadAt;
    if (map['readAt'] is Timestamp) {
      parsedReadAt = map['readAt'];
    }

    final effectiveOrgId =
        (map['orgId'] ?? map['forOrgId'] ?? map['tenantId'] ?? '').toString();

    return NotificationModel(
      notificationId: id,
      title: (map['title'] ?? 'New Notification').toString(),
      message: (map['message'] ?? map['body'] ?? '').toString(),
      type: parsedType,
      isRead: map['isRead'] == true,
      recipientId: (map['recipientId'] ??
              map['forSupervisorId'] ??
              map['forManagerId'] ??
              map['userId'] ??
              'all')
          .toString(),
      recipientRole:
          (map['recipientRole'] ?? map['targetRole'] ?? '').toString(),
      senderId: map['senderId']?.toString(),
      senderName: (map['senderName'] ?? '').toString(),
      senderRole: map['senderRole']?.toString(),
      siteId: (map['siteId'] ?? '').toString(),
      siteName: (map['siteName'] ?? '').toString(),
      requestId: map['requestId']?.toString(),
      docId: map['docId']?.toString(),
      status: map['status']?.toString(),
      remarks: map['remarks']?.toString(),
      requiredAction: map['requiredAction']?.toString(),
      createdAt: parsedCreatedAt,
      readAt: parsedReadAt,
      priority: (map['priority'] ?? 'normal').toString(),
      actionRoute: map['actionRoute']?.toString(),
      actionData: map['actionData'] is Map
          ? Map<String, dynamic>.from(map['actionData'])
          : (map['data'] is Map
              ? Map<String, dynamic>.from(map['data'])
              : null),
      tenantId: effectiveOrgId,
      orgId: effectiveOrgId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'id': notificationId,
      'title': title,
      'body': message,
      'message': message,
      'type': type.name,
      'requestType': type.name,
      'isRead': isRead,
      'recipientId': recipientId,
      'recipientRole': recipientRole ?? '',
      'targetRole': recipientRole ?? '',
      'senderId': senderId ?? '',
      'senderName': senderName ?? '',
      'senderRole': senderRole ?? '',
      'siteId': siteId ?? '',
      'siteName': siteName ?? '',
      'requestId': requestId ?? docId ?? notificationId,
      'docId': docId ?? requestId ?? notificationId,
      'status': status ?? '',
      'remarks': remarks ?? '',
      'requiredAction': requiredAction ?? '',
      'createdAt': createdAt,
      'readAt': readAt,
      'priority': priority,
      'actionRoute': actionRoute ?? '',
      'actionData': actionData ?? {},
      'data': {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'notificationId': notificationId,
        'actionRoute': actionRoute ?? '',
        'type': type.name,
        'requestType': type.name,
        'requestId': requestId ?? docId ?? notificationId,
        'docId': docId ?? requestId ?? notificationId,
        'siteId': siteId ?? '',
        'siteName': siteName ?? '',
        'status': status ?? '',
        'title': title,
        'body': message,
        'orgId': orgId ?? tenantId ?? '',
        if (actionData != null) ...actionData!,
      },
      'tenantId': tenantId ?? orgId ?? '',
      'orgId': orgId ?? tenantId ?? '',
      'forOrgId': orgId ?? tenantId ?? '',
    };
  }
}
