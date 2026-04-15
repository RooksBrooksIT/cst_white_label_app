import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firestore_service.dart';

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
    );

    // Show banner when notification arrives while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && message.notification != null) {
        _showInAppBanner(
          ctx,
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
        );
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('NotificationService: Notification tapped - ${message.data}');
    });
  }

  /// Shows a Material SnackBar as a foreground notification banner.
  static void _showInAppBanner(
      BuildContext context, String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    body,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Save this device's FCM token to Firestore under `fcmTokens/{userId}`.
  /// Call this right after a successful login.
  static Future<void> saveToken({
    required String userId,
    required String userType, // 'supervisor', 'organisation', 'manager', 'config'
    required String userName,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await FirestoreService.getCollection('fcmTokens').doc(userId).set({
        'token': token,
        'userType': userType,
        'userName': userName,
        'orgId': FirestoreService.currentOrgId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('NotificationService: Token saved for $userName ($userType)');
    } catch (e) {
      debugPrint('NotificationService: Failed to save token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE IN-APP NOTIFICATION RECORD
  // ---------------------------------------------------------------------------

  /// Persists a notification record to the global `notifications` Firestore
  /// collection so it can be read inside the app (badge, notification page).
  static Future<void> _writeRecord({
    String? forOrgId,
    String? forSupervisorName,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'forOrgId': forOrgId,
        'forSupervisorName': forSupervisorName,
        'orgId': FirestoreService.currentOrgId,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationService: Failed to write record: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SEND HELPERS
  // ---------------------------------------------------------------------------

  /// Notifies ALL organisation admins/managers when a supervisor submits a request.
  static Future<void> notifyOrganisation({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app record
    await _writeRecord(
      forOrgId: orgId,
      title: title,
      body: body,
      type: 'for_organisation',
      data: data,
    );

    // 2. Send FCM push to all org/manager/config tokens
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['organisation', 'manager', 'config'])
          .where('orgId', isEqualTo: orgId)
          .get();
      for (final doc in snap.docs) {
        final token = doc.data()['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _sendFcmPush(token: token, title: title, body: body);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending org FCM: $e');
    }
  }

  /// Notifies a specific supervisor when their request is approved/rejected.
  static Future<void> notifySupervisor({
    required String supervisorName,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // 1. Write in-app record
    await _writeRecord(
      forSupervisorName: supervisorName,
      title: title,
      body: body,
      type: 'for_supervisor',
      data: data,
    );

    // 2. Look up supervisor's FCM token and push
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userName', isEqualTo: supervisorName)
          .where('userType', isEqualTo: 'supervisor')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final token = snap.docs.first.data()['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _sendFcmPush(token: token, title: title, body: body);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending supervisor FCM: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FCM PUSH (via FCM Legacy HTTP API)
  // Note: The server key is stored in Firestore at
  //   organisation/{orgId}/admin/fcmConfig  →  field: "serverKey"
  // Set it once from the Firebase Console → Project Settings → Cloud Messaging.
  // ---------------------------------------------------------------------------
  static Future<void> _sendFcmPush({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final orgId = FirestoreService.currentOrgId;
      final configSnap = await FirebaseFirestore.instance
          .doc('organisation/$orgId/admin/fcmConfig')
          .get();
      final serverKey = configSnap.data()?['serverKey']?.toString();
      if (serverKey == null || serverKey.isEmpty) {
        debugPrint(
            'NotificationService: FCM server key not set. '
            'Add it to Firestore at organisation/$orgId/admin/fcmConfig → serverKey');
        return;
      }

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'priority': 'high',
        }),
      );
    } catch (e) {
      debugPrint('NotificationService: FCM send failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // STREAMS FOR IN-APP NOTIFICATION PAGES
  // ---------------------------------------------------------------------------

  /// Live stream of all notifications for a supervisor (newest first).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForSupervisor(
      String supervisorName) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('forSupervisorName', isEqualTo: supervisorName)
        .where('orgId', isEqualTo: FirestoreService.currentOrgId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Live stream of all notifications for the current organisation.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForOrganisation() {
    final orgId = FirestoreService.currentOrgId;
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('forOrgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Live count of unread notifications for a supervisor (used for badge).
  static Stream<int> unreadCountForSupervisor(String supervisorName) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('forSupervisorName', isEqualTo: supervisorName)
        .where('orgId', isEqualTo: FirestoreService.currentOrgId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Live count of unread notifications for the organisation.
  static Stream<int> unreadCountForOrganisation() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('forOrgId', isEqualTo: FirestoreService.currentOrgId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark a notification as read.
  static Future<void> markAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('NotificationService: markAsRead failed: $e');
    }
  }

  /// Mark all supervisor notifications as read at once.
  static Future<void> markAllReadForSupervisor(String supervisorName) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('forSupervisorName', isEqualTo: supervisorName)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService: markAllReadForSupervisor failed: $e');
    }
  }

  /// Mark all organisation notifications as read at once.
  static Future<void> markAllReadForOrganisation() async {
    try {
      final orgId = FirestoreService.currentOrgId;
      if (orgId.isEmpty) return;

      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('forOrgId', isEqualTo: orgId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService: markAllReadForOrganisation failed: $e');
    }
  }
}
