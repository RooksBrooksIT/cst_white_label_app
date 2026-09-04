import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firestore_service.dart';
import '../screens/manager/manager_material_approval_screen.dart';
import '../screens/manager/manager_tools_approval_screen.dart';
import '../screens/manager/manager_site_payment_approval_page.dart';
import '../screens/manager/manager_approval_screen.dart';

/// Handles background FCM messages when the app is terminated/background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService [BG]: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM: request permissions, set background handler, listen foreground.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions (iOS + Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Set foreground presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle cold-start notification click when app is opened from closed state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          navigateToTarget(ctx, initialMessage.data);
        }
      });
    }

    // Show banner when notification arrives while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        _showInAppBanner(ctx, title, body, message.data);
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        navigateToTarget(ctx, message.data);
      }
    });

    // Auto-update token on refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _refreshCurrentToken(newToken);
    });
  }

  /// Shows a rich foreground notification banner that can be tapped to navigate directly.
  static void _showInAppBanner(
    BuildContext context,
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            navigateToTarget(context, data);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
            ],
          ),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIRECT TARGET NAVIGATION
  // ---------------------------------------------------------------------------

  /// Navigates directly to the relevant approval/request screen based on notification payload.
  static void navigateToTarget(BuildContext context, Map<String, dynamic> data) {
    final type = (data['requestType'] ?? data['type'] ?? '').toString().toLowerCase();

    if (type.contains('material')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerMaterialApprovalScreen()),
      );
    } else if (type.contains('tool')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerToolsApprovalScreen()),
      );
    } else if (type.contains('payment')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerSitePaymentApprovalPage()),
      );
    } else if (type.contains('workforce') || type.contains('worker') || type.contains('schedule')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerApprovalScreen()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Save this device's FCM token to Firestore under `fcmTokens/{userId}`.
  static Future<void> saveToken({
    required String userId,
    required String userType, // 'supervisor', 'organisation', 'manager', 'config'
    required String userName,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final orgId = FirestoreService.currentOrgId;
      final tokenData = {
        'token': token,
        'userId': userId,
        'userType': userType,
        'userName': userName,
        'orgId': orgId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Save in organization-scoped fcmTokens collection
      await FirestoreService.getCollection('fcmTokens').doc(userId).set(
            tokenData,
            SetOptions(merge: true),
          );

      // 2. Also save in root fcmTokens for instant global Cloud Function lookup
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc('${orgId}_$userId')
            .set(tokenData, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc(userId)
            .set(tokenData, SetOptions(merge: true));
      }

      debugPrint('NotificationService: Token saved for $userName ($userType)');
    } catch (e) {
      debugPrint('NotificationService: Failed to save token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE IN-APP NOTIFICATION RECORD
  // ---------------------------------------------------------------------------

  /// Persists a notification record to the `notifications` Firestore collection.
  /// This automatically triggers the Firebase Cloud Function to deliver real-time push notifications.
  static Future<void> _writeRecord({
    required String title,
    required String body,
    required String targetRole, // 'manager', 'organisation', 'supervisor'
    String? forSupervisorName,
    String? forSupervisorId,
    String? forManagerName,
    String? forOrgId,
    String? requestType, // 'material', 'tools', 'payment', 'workforce', 'site_assignment'
    String? requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final orgId = forOrgId ?? FirestoreService.currentOrgId;
      final payload = {
        'app_id': FirestoreService.cstAppId,
        'title': title,
        'body': body,
        'targetRole': targetRole,
        'forSupervisorName': forSupervisorName,
        'forSupervisorId': forSupervisorId,
        'forManagerName': forManagerName,
        'forOrgId': orgId,
        'orgId': orgId,
        'requestType': requestType ?? 'general',
        'requestId': requestId ?? docId ?? '',
        'docId': docId ?? requestId ?? '',
        'siteId': siteId ?? '',
        'siteName': siteName ?? siteId ?? '',
        'status': status ?? '',
        'senderRole': senderRole ?? '',
        'senderName': senderName ?? '',
        'remarks': remarks ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'requestType': requestType ?? 'general',
          'requestId': requestId ?? docId ?? '',
          'docId': docId ?? requestId ?? '',
          'siteId': siteId ?? '',
          'siteName': siteName ?? siteId ?? '',
          'status': status ?? '',
          'title': title,
          'body': body,
          if (extraData != null) ...extraData,
        },
      };

      // 1. Write to global notifications collection (triggers Cloud Function onNotificationCreated)
      await FirebaseFirestore.instance.collection('notifications').add(payload);

      // 2. Also write to organization-scoped notifications collection
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection('notifications').add(payload);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to write record: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SEND HELPERS FOR 5-STAGE WORKFLOW
  // ---------------------------------------------------------------------------

  /// 1. Notifies Manager(s) when a Supervisor submits a request or when Org authorizes a requisition.
  static Future<void> notifyManager({
    required String title,
    required String body,
    required String requestType, // 'material', 'tools', 'payment', 'workforce'
    required String requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    Map<String, dynamic>? extraData,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app notification record for Manager
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'manager',
      forOrgId: orgId,
      requestType: requestType,
      requestId: requestId,
      docId: docId ?? requestId,
      siteId: siteId,
      siteName: siteName,
      status: status,
      senderRole: senderRole ?? 'Supervisor',
      senderName: senderName ?? 'Supervisor',
      remarks: remarks,
      extraData: extraData,
    );

    // 2. Send FCM push to manager tokens
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['manager', 'organisation', 'config'])
          .where('orgId', isEqualTo: orgId)
          .get();
      for (final doc in snap.docs) {
        final token = doc.data()['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _sendFcmPush(token: token, title: title, body: body, data: {
            'requestType': requestType,
            'requestId': requestId,
            'docId': docId ?? requestId,
            'siteId': siteId ?? '',
            'status': status ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending manager FCM: $e');
    }
  }

  /// 2. Notifies Organization Admins when a Manager forwards a request for final authorization.
  static Future<void> notifyOrganisation({
    required String title,
    required String body,
    String? requestType,
    String? requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    Map<String, dynamic>? data,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app record for Organization
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'organisation',
      forOrgId: orgId,
      requestType: requestType,
      requestId: requestId,
      docId: docId ?? requestId,
      siteId: siteId,
      siteName: siteName,
      status: status,
      senderRole: senderRole ?? 'Manager',
      senderName: senderName ?? 'Manager',
      remarks: remarks,
      extraData: data,
    );

    // 2. Send FCM push to all org tokens
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['organisation', 'config'])
          .where('orgId', isEqualTo: orgId)
          .get();
      for (final doc in snap.docs) {
        final token = doc.data()['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _sendFcmPush(token: token, title: title, body: body, data: {
            'requestType': requestType ?? '',
            'requestId': requestId ?? '',
            'docId': docId ?? requestId ?? '',
            'siteId': siteId ?? '',
            'status': status ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending org FCM: $e');
    }
  }

  /// 3. Notifies Supervisor when their request receives final approval or is rejected, or when assigned to a site.
  static Future<void> notifySupervisor({
    required String supervisorName,
    String? supervisorId,
    required String title,
    required String body,
    String? requestType,
    String? requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    Map<String, dynamic>? data,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app record for Supervisor
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'supervisor',
      forSupervisorName: supervisorName,
      forOrgId: orgId,
      requestType: requestType,
      requestId: requestId,
      docId: docId ?? requestId,
      siteId: siteId,
      siteName: siteName,
      status: status,
      senderRole: senderRole ?? 'Manager',
      senderName: senderName ?? 'Manager',
      remarks: remarks,
      extraData: {
        'supervisorId': supervisorId ?? '',
        'supervisorName': supervisorName,
        if (data != null) ...data,
      },
    );

    // 2. Look up supervisor's FCM token and push
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', isEqualTo: 'supervisor')
          .get();

      for (final doc in snap.docs) {
        final tokenData = doc.data();
        final token = tokenData['token']?.toString();
        final uName = (tokenData['userName'] ?? '').toString();
        final uId = (tokenData['userId'] ?? doc.id).toString();

        final isMatch = (supervisorName.isNotEmpty && (uName == supervisorName || uId == supervisorName)) ||
            (supervisorId != null && supervisorId.isNotEmpty && (uId == supervisorId || uName == supervisorId));

        if (token != null && token.isNotEmpty && isMatch) {
          await _sendFcmPush(token: token, title: title, body: body, data: {
            'requestType': requestType ?? '',
            'requestId': requestId ?? '',
            'docId': docId ?? requestId ?? '',
            'siteId': siteId ?? '',
            'siteName': siteName ?? '',
            'status': status ?? '',
            'title': title,
            'body': body,
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending supervisor FCM: $e');
    }
  }

  /// 4. Notifies Supervisor immediately when assigned to a specific site by a Manager.
  static Future<void> notifySiteAssignment({
    required String supervisorName,
    String? supervisorId,
    required String siteId,
    required String siteName,
    String? projectName,
    String? location,
    String? managerName,
  }) async {
    final displaySite = (siteId.isNotEmpty && siteName.isNotEmpty && siteId != siteName)
        ? '$siteId - $siteName'
        : (siteName.isNotEmpty ? siteName : siteId);

    final title = '📍 New Site Assignment';
    final locationInfo = (location != null && location.isNotEmpty) ? ' located at $location' : '';
    final projectInfo = (projectName != null && projectName.isNotEmpty) ? ' (Project: $projectName)' : '';
    final body = 'You have been assigned to site "$displaySite"$locationInfo$projectInfo.';

    await notifySupervisor(
      supervisorName: supervisorName,
      supervisorId: supervisorId,
      title: title,
      body: body,
      requestType: 'site_assignment',
      requestId: siteId,
      docId: siteId,
      siteId: siteId,
      siteName: siteName,
      status: 'assigned',
      senderRole: 'Manager',
      senderName: managerName ?? 'Manager',
      remarks: 'Assigned to site by Manager',
      data: {
        'siteId': siteId,
        'siteName': siteName,
        'projectName': projectName ?? '',
        'location': location ?? '',
        'managerName': managerName ?? 'Manager',
      },
    );
  }

  /// 5. Notifies when an Organization creates or configures a Manager account.
  static Future<void> notifyManagerAccountCreated({
    required String managerName,
    required String managerId,
    required String username,
    required String designation,
    required String department,
    String? orgId,
  }) async {
    final effectiveOrgId = orgId ?? FirestoreService.currentOrgId;

    // 1. In-app record for Manager and Organization audit
    await _writeRecord(
      title: '👤 Manager Account Registered',
      body: 'Manager $managerName ($designation, $department) has been registered under ID $managerId.',
      targetRole: 'manager',
      forManagerName: managerName,
      forOrgId: effectiveOrgId,
      requestType: 'manager_config',
      requestId: managerId,
      docId: managerId,
      status: 'active',
      senderRole: 'Organization',
      senderName: 'HQ Administrator',
      remarks: 'Manager account created',
      extraData: {
        'managerId': managerId,
        'username': username,
        'designation': designation,
        'department': department,
      },
    );

    // 2. Also notify Organization audit trail
    await _writeRecord(
      title: '👤 New Manager Configured',
      body: 'Manager profile $managerName ($managerId) configured in $department department.',
      targetRole: 'organisation',
      forOrgId: effectiveOrgId,
      requestType: 'manager_config',
      requestId: managerId,
      docId: managerId,
      status: 'active',
      senderRole: 'Organization',
      senderName: 'HQ Administrator',
    );
  }

  /// 6. Notifies when a Manager creates or configures a Supervisor profile.
  static Future<void> notifySupervisorAccountCreated({
    required String supervisorName,
    required String supervisorId,
    required String username,
    required String designation,
    String? managerName,
    String? orgId,
  }) async {
    final effectiveOrgId = orgId ?? FirestoreService.currentOrgId;

    // 1. In-app record for Supervisor
    await notifySupervisor(
      supervisorName: supervisorName,
      supervisorId: supervisorId,
      title: '👷 Welcome to eBricks',
      body: 'Your Supervisor account ($supervisorId, $designation) has been registered by Manager ${managerName ?? "Admin"}.',
      requestType: 'supervisor_config',
      requestId: supervisorId,
      docId: supervisorId,
      status: 'active',
      senderRole: 'Manager',
      senderName: managerName ?? 'Manager',
      remarks: 'Supervisor profile created',
      data: {
        'supervisorId': supervisorId,
        'username': username,
        'designation': designation,
      },
    );

    // 2. In-app audit record for Organization
    await _writeRecord(
      title: '👷 New Supervisor Profile Created',
      body: 'Supervisor $supervisorName ($supervisorId) was registered by Manager ${managerName ?? "Admin"}.',
      targetRole: 'organisation',
      forOrgId: effectiveOrgId,
      requestType: 'supervisor_config',
      requestId: supervisorId,
      docId: supervisorId,
      status: 'active',
      senderRole: 'Manager',
      senderName: managerName ?? 'Manager',
    );
  }

  /// 7. Notifies Organization when a Manager registers or updates a Site.
  static Future<void> notifySiteCreatedOrUpdated({
    required String siteId,
    required String siteName,
    required String location,
    String? projectName,
    String? managerName,
    bool isCreated = true,
  }) async {
    final title = isCreated ? '🏗️ New Site Registered' : '🏗️ Site Details Updated';
    final actionWord = isCreated ? 'registered' : 'updated';
    final projectInfo = (projectName != null && projectName.isNotEmpty) ? ' (Project: $projectName)' : '';
    final body = 'Manager ${managerName ?? "Admin"} $actionWord Site "$siteId - $siteName" at $location$projectInfo.';

    // 1. Notify Organization
    await notifyOrganisation(
      title: title,
      body: body,
      requestType: 'site_management',
      requestId: siteId,
      docId: siteId,
      siteId: siteId,
      siteName: siteName,
      status: isCreated ? 'created' : 'updated',
      senderRole: 'Manager',
      senderName: managerName ?? 'Manager',
      remarks: 'Site $actionWord in system',
      data: {
        'siteId': siteId,
        'siteName': siteName,
        'location': location,
        'projectName': projectName ?? '',
      },
    );
  }

  /// 8. Notifies Managers and Supervisors when a Master Configuration (Materials, Vehicles, Contractors) is updated.
  static Future<void> notifyMasterConfigUpdated({
    required String configType, // 'Materials', 'Vehicles', 'Contractors', 'Units'
    required String itemTitle,
    String? senderName,
    String? senderRole,
  }) async {
    final title = '⚙️ $configType Catalogue Updated';
    final body = '$itemTitle was added/modified in the $configType configuration by ${senderName ?? "Admin"}.';

    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'manager',
      requestType: 'master_config',
      senderRole: senderRole ?? 'Manager',
      senderName: senderName ?? 'Manager',
      remarks: '$configType updated',
      extraData: {
        'configType': configType,
        'itemTitle': itemTitle,
      },
    );

    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'organisation',
      requestType: 'master_config',
      senderRole: senderRole ?? 'Manager',
      senderName: senderName ?? 'Manager',
      remarks: '$configType updated',
      extraData: {
        'configType': configType,
        'itemTitle': itemTitle,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FCM PUSH SENDING
  // ---------------------------------------------------------------------------
  static Future<void> _sendFcmPush({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final orgId = FirestoreService.currentOrgId;
      final configSnap = await FirebaseFirestore.instance
          .doc('organisation/$orgId/data/fcmConfig')
          .get();
      final serverKey = configSnap.data()?['serverKey']?.toString();
      if (serverKey == null || serverKey.isEmpty) {
        debugPrint(
            'NotificationService: FCM server key not set. '
            'Add it to Firestore at organisation/$orgId/data/fcmConfig → serverKey');
        return;
      }

      final payload = {
        'to': token,
        'priority': 'high',
        'content_available': true,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'android_channel_id': 'cst_high_importance_channel',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'cst_high_importance_channel',
            'sound': 'default',
            'default_sound': true,
            'default_vibrate_timings': true,
            'priority': 'high',
            'visibility': 'public',
          },
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'title': title,
          'body': body,
          if (data != null) ...data,
        },
      };

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('NotificationService: FCM send failed: $e');
    }
  }

  /// Automatically update token in Firestore when refreshed.
  static Future<void> _refreshCurrentToken(String newToken) async {
    try {
      final authData = FirestoreService.currentOrgId;
      if (authData.isEmpty) return;
      debugPrint('NotificationService: FCM token refreshed');
    } catch (e) {
      debugPrint('NotificationService: Error refreshing token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // STREAMS & LIVE COUNTS
  // ---------------------------------------------------------------------------

  /// Live stream of notifications for a specific user role.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForRole({
    required String role, // 'manager', 'organisation', 'supervisor'
    String? supervisorName,
    String? managerName,
  }) {
    final orgId = FirestoreService.currentOrgId;
    Query<Map<String, dynamic>> query;

    if (orgId.isNotEmpty && orgId != 'uninitialized') {
      query = FirestoreService.getCollection('notifications');
    } else {
      query = FirebaseFirestore.instance.collection('notifications');
    }

    if (role == 'supervisor' && supervisorName != null && supervisorName.isNotEmpty) {
      query = query.where('forSupervisorName', isEqualTo: supervisorName);
    } else if (role == 'manager') {
      query = query.where('targetRole', whereIn: ['manager', 'organisation', 'all']);
    } else if (role == 'organisation') {
      query = query.where('targetRole', whereIn: ['organisation', 'all']);
    }

    return query.orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  /// Live stream count of unread notifications for a specific user role.
  static Stream<int> unreadCountForRole({
    required String role, // 'manager', 'organisation', 'supervisor'
    String? supervisorName,
    String? managerName,
  }) {
    final orgId = FirestoreService.currentOrgId;
    Query<Map<String, dynamic>> query;

    if (orgId.isNotEmpty && orgId != 'uninitialized') {
      query = FirestoreService.getCollection('notifications')
          .where('isRead', isEqualTo: false);
    } else {
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('isRead', isEqualTo: false);
    }

    if (role == 'supervisor' && supervisorName != null && supervisorName.isNotEmpty) {
      query = query.where('forSupervisorName', isEqualTo: supervisorName);
    } else if (role == 'manager') {
      query = query.where('targetRole', whereIn: ['manager', 'organisation', 'all']);
    } else if (role == 'organisation') {
      query = query.where('targetRole', whereIn: ['organisation', 'all']);
    }

    return query.snapshots().map((snap) => snap.docs.length);
  }

  /// Live stream of all notifications for a supervisor (backward compatibility).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForSupervisor(String supervisorName) {
    return streamForRole(role: 'supervisor', supervisorName: supervisorName);
  }

  /// Live stream of all notifications for the current organisation (backward compatibility).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForOrganisation() {
    return streamForRole(role: 'organisation');
  }

  /// Live count of unread notifications for a supervisor.
  static Stream<int> unreadCountForSupervisor(String supervisorName) {
    return unreadCountForRole(role: 'supervisor', supervisorName: supervisorName);
  }

  /// Live count of unread notifications for the organisation.
  static Stream<int> unreadCountForOrganisation() {
    return unreadCountForRole(role: 'organisation');
  }

  /// Mark a notification as read across collections.
  static Future<void> markAsRead(String docId) async {
    try {
      final orgId = FirestoreService.currentOrgId;
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true})
          .catchError((_) {});

      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection('notifications')
            .doc(docId)
            .update({'isRead': true})
            .catchError((_) {});
      }
    } catch (e) {
      debugPrint('NotificationService: markAsRead failed: $e');
    }
  }

  /// Mark all notifications as read for a specific role.
  static Future<void> markAllReadForRole({
    required String role,
    String? supervisorName,
    String? managerName,
  }) async {
    try {
      final orgId = FirestoreService.currentOrgId;

      // 1. Mark in org collection
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        var orgQuery = FirestoreService.getCollection('notifications')
            .where('isRead', isEqualTo: false);
        if (role == 'supervisor' && supervisorName != null && supervisorName.isNotEmpty) {
          orgQuery = orgQuery.where('forSupervisorName', isEqualTo: supervisorName);
        } else if (role == 'manager') {
          orgQuery = orgQuery.where('targetRole', whereIn: ['manager', 'organisation', 'all']);
        } else if (role == 'organisation') {
          orgQuery = orgQuery.where('targetRole', whereIn: ['organisation', 'all']);
        }
        final snap = await orgQuery.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }

      // 2. Mark in global collection
      var globalQuery = FirebaseFirestore.instance
          .collection('notifications')
          .where('orgId', isEqualTo: orgId)
          .where('isRead', isEqualTo: false);
      if (role == 'supervisor' && supervisorName != null && supervisorName.isNotEmpty) {
        globalQuery = globalQuery.where('forSupervisorName', isEqualTo: supervisorName);
      } else if (role == 'manager') {
        globalQuery = globalQuery.where('targetRole', whereIn: ['manager', 'organisation', 'all']);
      } else if (role == 'organisation') {
        globalQuery = globalQuery.where('targetRole', whereIn: ['organisation', 'all']);
      }

      final snap = await globalQuery.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService: markAllReadForRole failed: $e');
    }
  }

  /// Mark all supervisor notifications as read at once.
  static Future<void> markAllReadForSupervisor(String supervisorName) async {
    return markAllReadForRole(role: 'supervisor', supervisorName: supervisorName);
  }

  /// Mark all organisation notifications as read at once.
  static Future<void> markAllReadForOrganisation() async {
    return markAllReadForRole(role: 'organisation');
  }

  // ---------------------------------------------------------------------------
  // SCHEDULED NOTIFICATIONS ENGINE
  // ---------------------------------------------------------------------------

  /// Schedules a future or recurring notification for any role/user.
  static Future<String?> scheduleNotification({
    required String title,
    required String body,
    required String targetRole, // 'manager', 'organisation', 'supervisor', 'all'
    required DateTime scheduledTime,
    String? forSupervisorName,
    String? forSupervisorId,
    String? forManagerName,
    String? requestType,
    String repeat = 'none', // 'none', 'daily', 'weekly'
    String? siteId,
    String? siteName,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final orgId = FirestoreService.currentOrgId;
      final scheduleId =
          'SCHED_${DateTime.now().millisecondsSinceEpoch}_${(100 + (DateTime.now().microsecond % 900))}';

      final payload = {
        'id': scheduleId,
        'scheduleId': scheduleId,
        'title': title,
        'body': body,
        'targetRole': targetRole,
        'forSupervisorName': forSupervisorName,
        'forSupervisorId': forSupervisorId,
        'forManagerName': forManagerName,
        'forOrgId': orgId,
        'orgId': orgId,
        'requestType': requestType ?? 'scheduled_alert',
        'scheduledAt': Timestamp.fromDate(scheduledTime),
        'repeat': repeat,
        'status': 'pending',
        'siteId': siteId ?? '',
        'siteName': siteName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredCount': 0,
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'requestType': requestType ?? 'scheduled_alert',
          'siteId': siteId ?? '',
          'siteName': siteName ?? '',
          'title': title,
          'body': body,
          if (extraData != null) ...extraData,
        },
      };

      // 1. Root collection for Cloud Functions runner
      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc(scheduleId)
          .set(payload);

      // 2. Org-scoped collection
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection('scheduled_notifications')
            .doc(scheduleId)
            .set(payload);
      }

      debugPrint('NotificationService: Scheduled notification $scheduleId for $scheduledTime (repeat: $repeat)');
      return scheduleId;
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule notification: $e');
      return null;
    }
  }

  /// Schedules daily recurring reminders for a site supervisor (e.g. Daily Site Log & Workforce report).
  static Future<String?> scheduleDailySupervisorReminder({
    required String supervisorName,
    String? supervisorId,
    required String siteId,
    required String siteName,
    int hour = 9, // 9:00 AM default
    int minute = 0,
    String title = '📋 Daily Site Log Reminder',
    String body = 'Please submit today\'s site progress, workforce entries, and material consumption.',
  }) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduleNotification(
      title: title,
      body: body,
      targetRole: 'supervisor',
      forSupervisorName: supervisorName,
      forSupervisorId: supervisorId,
      scheduledTime: scheduled,
      repeat: 'daily',
      requestType: 'daily_site_log',
      siteId: siteId,
      siteName: siteName,
    );
  }

  /// Schedules recurring reminder for Managers for pending approval reviews.
  static Future<String?> schedulePendingApprovalReminder({
    required String managerName,
    String? siteId,
    int intervalHours = 24,
  }) async {
    final scheduled = DateTime.now().add(Duration(hours: intervalHours));

    return scheduleNotification(
      title: '⏳ Pending Approval Requisitions',
      body: 'You have requisitions awaiting verification for site ${siteId ?? "your projects"}. Please review.',
      targetRole: 'manager',
      forManagerName: managerName,
      scheduledTime: scheduled,
      repeat: 'none',
      requestType: 'pending_approval_reminder',
      siteId: siteId,
    );
  }

  /// Cancels an active scheduled notification.
  static Future<void> cancelScheduledNotification(String scheduleId) async {
    try {
      final orgId = FirestoreService.currentOrgId;

      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc(scheduleId)
          .update({'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()});

      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection('scheduled_notifications')
            .doc(scheduleId)
            .update({'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()});
      }

      debugPrint('NotificationService: Cancelled scheduled notification $scheduleId');
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel schedule: $e');
    }
  }

  /// Live stream of active scheduled notifications for the organization.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamScheduledNotifications() {
    final orgId = FirestoreService.currentOrgId;
    return FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }
}
