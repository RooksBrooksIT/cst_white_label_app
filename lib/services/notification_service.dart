import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firestore_service.dart';
import 'notification_router.dart';
import 'auth_service.dart';

/// Handles background FCM messages when the app is terminated/background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService [BG]: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _androidChannelId = 'cst_high_importance_channel';
  static const String _androidChannelName = 'High Importance Notifications';
  static const String _androidChannelDescription =
      'Important notifications that require immediate attention';

  static StreamSubscription? _realtimeNotifSub;
  static final Set<String> _processedNotifIds = {};
  static bool _isLocalNotificationsInitialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Normalizes role string to canonical form ('organisation', 'manager', 'supervisor').
  /// Handles American vs British spelling ('organization' -> 'organisation') and aliases.
  static String normalizeRole(String? role) {
    final r = (role ?? '').toLowerCase().trim();
    if (r == 'organisation' || r == 'organization' || r == 'org') {
      return 'organisation';
    }
    if (r == 'config' || r == 'admin') {
      return 'organisation';
    }
    return r;
  }

  /// Safely converts Timestamps, DateTimes, and non-JSON-encodable values to ISO strings
  /// to ensure jsonEncode never fails when preparing notification payloads.
  static Map<String, dynamic> _sanitizeDataForPayload(Map<String, dynamic> raw) {
    final clean = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value is Timestamp) {
        clean[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        clean[key] = value.toIso8601String();
      } else if (value is Map) {
        clean[key] = _sanitizeDataForPayload(Map<String, dynamic>.from(value));
      } else if (value is List) {
        clean[key] = value.map((item) {
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is DateTime) return item.toIso8601String();
          if (item is Map) {
            return _sanitizeDataForPayload(Map<String, dynamic>.from(item));
          }
          return item?.toString();
        }).toList();
      } else {
        clean[key] = value;
      }
    });
    return clean;
  }

  /// Initializes flutter_local_notifications and creates the Android notification channel.
  /// This is required to show heads-up notifications when the app is in the foreground,
  /// and to ensure sound/vibration/icon work correctly on Android 8.0+.
  static Future<void> _initializeLocalNotifications() async {
    if (_isLocalNotificationsInitialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              jsonDecode(response.payload!),
            );
            final ctx = _navigatorKey?.currentContext ?? NotificationService._lastContext;
            if (ctx != null && ctx.mounted) {
              navigateToTarget(ctx, data);
            }
          } catch (_) {}
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          enableLights: true,
        ),
      );
      // Explicitly request Android 13+ runtime POST_NOTIFICATIONS permission
      await androidPlugin.requestNotificationsPermission();
    }
    _isLocalNotificationsInitialized = true;
  }

  static BuildContext? _lastContext;

  /// Explicitly requests notification permission from the operating system.
  /// Uses Permission.notification for Android 13+ (POST_NOTIFICATIONS) runtime dialog
  /// and FirebaseMessaging for iOS/Android FCM notification settings.
  static Future<bool> requestNotificationPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        'NotificationService: FCM permission status: ${settings.authorizationStatus}',
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint(
        'NotificationService: Error requesting notification permission: $e',
      );
      return false;
    }
  }

  /// Initialize FCM: request permissions, set background handler, listen foreground.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground heads-up alerts
    await _initializeLocalNotifications();

    // Request permissions before setting presentation options
    await requestNotificationPermission();

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
      final title =
          message.notification?.title ??
          message.data['title'] ??
          'New Notification';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      final ctx = navigatorKey.currentContext;
      _lastContext = ctx;

      final notifDocId = (message.data['idempotencyKey'] ??
              message.data['notificationId'] ??
              message.data['id'] ??
              message.data['docId'] ??
              message.data['requestId'] ??
              '$title|$body')
          .toString();

      // Skip if this event was already delivered by the real-time bridge
      if (_processedNotifIds.contains(notifDocId)) {
        return;
      }
      _processedNotifIds.add(notifDocId);

      final deterministicId = notifDocId.hashCode.abs().remainder(100000);

      // 1. Show Android system tray / iOS heads-up notification via flutter_local_notifications
      _showForegroundSystemNotification(
        id: deterministicId,
        title: title,
        body: body,
        data: message.data,
      );

      // 2. Show in-app SnackBar banner (existing behaviour)
      if (ctx != null && ctx.mounted) {
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

  static final Map<String, int> _recentShownNotifs = {};

  /// Public interface to show a system notification in the mobile's notification tray.
  static Future<void> showSystemTrayNotification({
    required String title,
    required String body,
    int? id,
    Map<String, dynamic>? data,
  }) async {
    await _showForegroundSystemNotification(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      data: data,
    );
  }

  /// Displays an actual Android system tray / iOS heads-up notification when the
  /// app is in the foreground. Firebase Messaging does NOT automatically show a
  /// system notification while the app is open — we must use flutter_local_notifications.
  static Future<void> _showForegroundSystemNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _initializeLocalNotifications();

      final now = DateTime.now().millisecondsSinceEpoch;
      final notifDocId = (data?['idempotencyKey'] ??
              data?['notificationId'] ??
              data?['id'] ??
              data?['docId'] ??
              data?['requestId'] ??
              '')
          .toString();
      final dedupKey = notifDocId.isNotEmpty ? notifDocId : '$title|$body';

      // Prevent duplicate system tray alert if shown in the last 15 seconds
      if (_recentShownNotifs.containsKey(dedupKey)) {
        final lastTime = _recentShownNotifs[dedupKey]!;
        if (now - lastTime < 15000) {
          return;
        }
      }
      _recentShownNotifs[dedupKey] = now;
      if (notifDocId.isNotEmpty) {
        _recentShownNotifs[notifDocId] = now;
        _processedNotifIds.add(notifDocId);
      }
      if (_recentShownNotifs.length > 100) {
        _recentShownNotifs.removeWhere((_, time) => now - time > 45000);
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: 'eBricks',
            ),
            showWhen: true,
            autoCancel: true,
            enableVibration: true,
            playSound: true,
            visibility: NotificationVisibility.public,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final cleanData = data != null
          ? _sanitizeDataForPayload(Map<String, dynamic>.from(data))
          : null;
      final payload = cleanData != null ? jsonEncode(cleanData) : null;

      await _localNotifications.show(
        id,
        title,
        body,
        notifDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
        'NotificationService: Failed to show system tray notification: $e',
      );
    }
  }

  /// Public method to ensure the realtime notification bridge is active
  /// for the current role session (e.g. when OrganizationDashboard mounts).
  static void ensureRealtimeBridgeActive({
    required String role,
    String? userName,
    String? userId,
  }) {
    startRealtimeNotificationBridge(
      role: role,
      userName: userName,
      userId: userId,
    );
  }

  /// Starts the real-time live notification bridge for the current user/role session.
  /// Guarantees that any new notification document created in Firestore triggers
  /// an immediate heads-up push in the device's system notification tray.
  static void startRealtimeNotificationBridge({
    required String role,
    String? userName,
    String? userId,
  }) {
    final canonicalRole = normalizeRole(role);
    _realtimeNotifSub?.cancel();
    final orgId = FirestoreService.currentOrgId;
    if (orgId.isEmpty || orgId == 'uninitialized') return;

    try {
      final collection = FirestoreService.getCollection('notifications');
      // Look back 2 minutes to eliminate any device-server clock skew differences,
      // while relying on _processedNotifIds to prevent replay of past alerts.
      final windowStart = DateTime.now().subtract(const Duration(minutes: 2));

      _realtimeNotifSub = collection
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final data = change.doc.data();
            if (data == null) continue;

            final docId = change.doc.id;
            final notifDocId = (data['idempotencyKey'] ??
                    data['notificationId'] ??
                    data['id'] ??
                    data['docId'] ??
                    data['requestId'] ??
                    docId)
                .toString();

            // Skip if this specific notification was already delivered locally in this session
            if (_processedNotifIds.contains(notifDocId) ||
                _processedNotifIds.contains(docId) ||
                (data['idempotencyKey'] != null &&
                    _processedNotifIds.contains(data['idempotencyKey'].toString()))) {
              continue;
            }

            final senderName =
                (data['senderName'] ?? '').toString().toLowerCase().trim();
            final senderRole =
                (data['senderRole'] ?? '').toString().toLowerCase().trim();
            final currentUserName = (userName ?? '').toLowerCase().trim();
            final currentUserId = (userId ?? '').toLowerCase().trim();
            final currentRole = canonicalRole;

            // Only suppress self-actions if the sender is strictly the same user AND same role.
            // Do NOT suppress if sender is Manager (e.g. 'admin') and recipient is Organization (also 'admin').
            if (currentUserName.isNotEmpty && senderName == currentUserName) {
              final normSenderRole = normalizeRole(senderRole);
              if (normSenderRole.isNotEmpty && normSenderRole == currentRole) {
                _processedNotifIds.add(notifDocId);
                _processedNotifIds.add(docId);
                continue;
              }
            }

            final targetRole = normalizeRole((data['targetRole'] ?? '').toString());
            final rawTargetRoleStr =
                (data['targetRole'] ?? '').toString().toLowerCase().trim();
            final rawTargetRoles = (data['targetRoles'] as List?)
                    ?.map((e) => e.toString().toLowerCase().trim())
                    .toList() ??
                [];
            final normalizedTargetRoles =
                rawTargetRoles.map((e) => normalizeRole(e)).toList();

            final forSupervisorName = (data['forSupervisorName'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            final forManagerName =
                (data['forManagerName'] ?? '').toString().toLowerCase().trim();
            final recipientId =
                (data['recipientId'] ?? '').toString().toLowerCase().trim();

            bool isRecipient = false;

            if (recipientId == 'all' ||
                (currentUserId.isNotEmpty && recipientId == currentUserId) ||
                (orgId.toLowerCase().trim() == recipientId)) {
              isRecipient = true;
            } else if (rawTargetRoles.contains('all') ||
                targetRole == 'all' ||
                normalizedTargetRoles.contains('all')) {
              isRecipient = true;
            } else if (currentRole == 'organisation') {
              isRecipient = targetRole == 'organisation' ||
                  rawTargetRoleStr == 'manager_and_organisation' ||
                  rawTargetRoleStr == 'manager_and_organization' ||
                  normalizedTargetRoles.contains('organisation') ||
                  rawTargetRoles.contains('organisation') ||
                  rawTargetRoles.contains('organization') ||
                  rawTargetRoles.contains('manager_and_organisation') ||
                  rawTargetRoles.contains('manager_and_organization');
            } else if (currentRole == 'manager') {
              isRecipient = targetRole == 'manager' ||
                  rawTargetRoleStr == 'manager_and_organisation' ||
                  rawTargetRoleStr == 'manager_and_organization' ||
                  normalizedTargetRoles.contains('manager') ||
                  rawTargetRoles.contains('manager') ||
                  rawTargetRoles.contains('manager_and_organisation') ||
                  rawTargetRoles.contains('manager_and_organization');
              if (forManagerName.isNotEmpty &&
                  currentUserName.isNotEmpty &&
                  forManagerName != currentUserName) {
                isRecipient = false;
              }
            } else if (currentRole == 'supervisor') {
              isRecipient = targetRole == 'supervisor' ||
                  normalizedTargetRoles.contains('supervisor') ||
                  rawTargetRoles.contains('supervisor');
              if (forSupervisorName.isNotEmpty &&
                  currentUserName.isNotEmpty &&
                  forSupervisorName != currentUserName) {
                isRecipient = false;
              }
            }

            if (isRecipient) {
              _processedNotifIds.add(notifDocId);
              _processedNotifIds.add(docId);
              if (data['idempotencyKey'] != null) {
                _processedNotifIds.add(data['idempotencyKey'].toString());
              }
              if (_processedNotifIds.length > 300) {
                _processedNotifIds.remove(_processedNotifIds.first);
              }

              final title = data['title']?.toString() ?? 'New Notification';
              final body = data['body']?.toString() ??
                  data['message']?.toString() ??
                  '';
              final deterministicId =
                  notifDocId.hashCode.abs().remainder(100000);

              final rawDataMap = data['data'] is Map ? data['data'] : data;
              final cleanPayload = _sanitizeDataForPayload(
                  Map<String, dynamic>.from(rawDataMap as Map));

              _showForegroundSystemNotification(
                id: deterministicId,
                title: title,
                body: body,
                data: cleanPayload,
              );

              final ctx =
                  _navigatorKey?.currentContext ?? NotificationService._lastContext;
              if (ctx != null && ctx.mounted) {
                _showInAppBanner(ctx, title, body, cleanPayload);
              }
            }
          }
        }
      }, onError: (e) {
        debugPrint('NotificationService: Realtime bridge stream error: $e');
      });

      debugPrint(
          'NotificationService: Real-time notification tray bridge active for $canonicalRole ($userName)');
    } catch (e) {
      debugPrint(
          'NotificationService: Failed to initialize realtime bridge: $e');
    }
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
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 20,
              ),
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
  static void navigateToTarget(
    BuildContext context,
    dynamic data,
  ) {
    NotificationRouter.navigate(context, data);
  }

  // ---------------------------------------------------------------------------
  // TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Save this device's FCM token to Firestore under `fcmTokens/{userId}` and root `fcmTokens`.
  static Future<void> saveToken({
    required String userId,
    required String
    userType, // 'supervisor', 'organisation', 'manager', 'config'
    required String userName,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final orgId = FirestoreService.currentOrgId;
      final cleanUserId = userId.trim();
      final cleanUserType = normalizeRole(userType);
      final cleanUserName = userName.trim();
      final cleanOrgId = orgId.trim();

      final tokenData = {
        'token': token,
        'userId': cleanUserId,
        'userType': cleanUserType,
        'userName': cleanUserName,
        'orgId': cleanOrgId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Save in organization-scoped fcmTokens collection under canonical key
      if (cleanOrgId.isNotEmpty && cleanOrgId != 'uninitialized') {
        final orgTokens = FirestoreService.getCollection('fcmTokens');
        await orgTokens.doc('${cleanUserType}_$cleanUserId').set(tokenData, SetOptions(merge: true));
        // Prune legacy duplicate doc to prevent multiple dispatches to the same token
        await orgTokens.doc(cleanUserId).delete().catchError((_) {});
      }

      // 2. Also save in root fcmTokens for instant global Cloud Function lookup
      if (cleanOrgId.isNotEmpty && cleanOrgId != 'uninitialized') {
        final rootTokens = FirebaseFirestore.instance.collection('fcmTokens');
        await rootTokens.doc('${cleanOrgId}_${cleanUserType}_$cleanUserId').set(tokenData, SetOptions(merge: true));
        await rootTokens.doc('${cleanOrgId}_$cleanUserId').delete().catchError((_) {});
      } else {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc('${cleanUserType}_$cleanUserId')
            .set(tokenData, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc(cleanUserId)
            .delete()
            .catchError((_) {});
      }

      // 3. Subscribe to org and role topics for broadcast push delivery
      if (cleanOrgId.isNotEmpty && cleanOrgId != 'uninitialized') {
        final sanitizedOrgId = cleanOrgId.replaceAll(RegExp(r'\W'), '_');
        await _messaging.subscribeToTopic('org_$sanitizedOrgId');
        await _messaging.subscribeToTopic('org_${sanitizedOrgId}_$cleanUserType');
        if (cleanUserType == 'organisation' || cleanUserType == 'organization' || cleanUserType == 'config') {
          await _messaging.subscribeToTopic('org_${sanitizedOrgId}_organisation');
          await _messaging.subscribeToTopic('org_${sanitizedOrgId}_organization');
        }
        if (cleanUserType == 'config') {
          await _messaging.subscribeToTopic('org_${sanitizedOrgId}_manager');
        }
      }

      // 4. Activate the realtime notification tray bridge
      startRealtimeNotificationBridge(
        role: cleanUserType,
        userName: cleanUserName,
        userId: cleanUserId,
      );

      debugPrint(
        'NotificationService: Token, topics & notification tray bridge saved for $cleanUserName ($cleanUserType)',
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to save token/topics: $e');
    }
  }

  /// Removes this device's FCM token document and unsubscribes from topics on logout.
  static Future<void> deleteToken({
    required String userId,
    required String userType,
  }) async {
    try {
      _realtimeNotifSub?.cancel();
      final orgId = FirestoreService.currentOrgId;
      final cleanUserId = userId.trim();
      final cleanUserType = userType.trim().toLowerCase();
      final cleanOrgId = orgId.trim();

      if (cleanOrgId.isNotEmpty && cleanOrgId != 'uninitialized') {
        final sanitizedOrgId = cleanOrgId.replaceAll(RegExp(r'\W'), '_');
        await _messaging
            .unsubscribeFromTopic('org_$sanitizedOrgId')
            .catchError((_) {});
        await _messaging
            .unsubscribeFromTopic('org_${sanitizedOrgId}_$cleanUserType')
            .catchError((_) {});
        if (cleanUserType == 'config' || cleanUserType == 'organisation' || cleanUserType == 'organization') {
          await _messaging
              .unsubscribeFromTopic('org_${sanitizedOrgId}_organisation')
              .catchError((_) {});
          await _messaging
              .unsubscribeFromTopic('org_${sanitizedOrgId}_organization')
              .catchError((_) {});
          await _messaging
              .unsubscribeFromTopic('org_${sanitizedOrgId}_manager')
              .catchError((_) {});
        }

        // Delete from org subcollection (both role-isolated and generic key)
        final orgTokens = FirestoreService.getCollection('fcmTokens');
        await orgTokens.doc('${cleanUserType}_$cleanUserId').delete().catchError((_) {});
        await orgTokens.doc(cleanUserId).delete().catchError((_) {});

        // Delete from global root collection
        final rootTokens = FirebaseFirestore.instance.collection('fcmTokens');
        await rootTokens.doc('${cleanOrgId}_${cleanUserType}_$cleanUserId').delete().catchError((_) {});
        await rootTokens.doc('${cleanOrgId}_$cleanUserId').delete().catchError((_) {});
      } else {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc('${cleanUserType}_$cleanUserId')
            .delete()
            .catchError((_) {});
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc(cleanUserId)
            .delete()
            .catchError((_) {});
      }

      debugPrint(
        'NotificationService: Successfully pruned FCM token for user $cleanUserId ($cleanUserType)',
      );
    } catch (e) {
      debugPrint('NotificationService: Error deleting token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE IN-APP NOTIFICATION RECORD
  // ---------------------------------------------------------------------------

  /// Persists a notification record to the `notifications` Firestore collection.
  static Future<void> _writeRecord({
    required String title,
    required String body,
    required String
    targetRole, // 'manager', 'organisation', 'supervisor', 'manager_and_organisation'
    List<String>? targetRoles,
    String? recipientId,
    String? forSupervisorName,
    String? forSupervisorId,
    String? forManagerName,
    String? forManagerId,
    String? forOrgId,
    String?
    requestType, // 'material', 'tools', 'payment', 'workforce', 'site_assignment', 'petty_cash', 'site_management'
    String? requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    String? requiredAction,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final orgId = forOrgId ?? FirestoreService.currentOrgId;
      final effectiveType = requestType ?? 'general';
      final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
      final targetEntity = siteId ?? requestId ?? docId ?? 'global';
      final defaultIdempotencyKey = 'evt_${orgId}_${effectiveType}_${targetEntity}_$timeBucket';
      final idempotencyKey = (extraData?['idempotencyKey'] ?? defaultIdempotencyKey).toString();
      final notifId = docId ?? requestId ?? idempotencyKey;

      final payload = {
        'app_id': FirestoreService.cstAppId,
        'idempotencyKey': idempotencyKey,
        'notificationId': notifId,
        'id': notifId,
        'title': title,
        'body': body,
        'message': body,
        'type': effectiveType,
        'requestType': effectiveType,
        'targetRole': targetRole,
        'recipientRole': targetRole,
        'targetRoles':
            targetRoles ??
            (targetRole == 'manager_and_organisation'
                ? ['manager', 'organisation']
                : [targetRole]),
        'recipientId': recipientId ?? forSupervisorId ?? forManagerId ?? 'all',
        'forSupervisorName': forSupervisorName,
        'forSupervisorId': forSupervisorId,
        'forManagerName': forManagerName,
        'forOrgId': orgId,
        'orgId': orgId,
        'tenantId': orgId,
        'requestId': requestId ?? docId ?? notifId,
        'docId': docId ?? requestId ?? notifId,
        'siteId': siteId ?? '',
        'siteName': siteName ?? siteId ?? '',
        'status': status ?? '',
        'senderRole': senderRole ?? '',
        'senderName': senderName ?? '',
        'senderId': senderName ?? '',
        'remarks': remarks ?? '',
        'requiredAction': requiredAction ?? '',
        'priority': 'high',
        'actionRoute': '/$effectiveType',
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'actionData': {
          'idempotencyKey': idempotencyKey,
          'notificationId': notifId,
          'requestType': effectiveType,
          'requestId': requestId ?? docId ?? notifId,
          'docId': docId ?? requestId ?? notifId,
          'siteId': siteId ?? '',
          'siteName': siteName ?? siteId ?? '',
          'status': status ?? '',
          'requiredAction': requiredAction ?? '',
          'title': title,
          'body': body,
          'orgId': orgId,
          if (extraData != null) ...extraData,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'idempotencyKey': idempotencyKey,
          'notificationId': notifId,
          'actionRoute': '/$effectiveType',
          'type': effectiveType,
          'requestType': effectiveType,
          'requestId': requestId ?? docId ?? notifId,
          'docId': docId ?? requestId ?? notifId,
          'siteId': siteId ?? '',
          'siteName': siteName ?? siteId ?? '',
          'status': status ?? '',
          'requiredAction': requiredAction ?? '',
          'title': title,
          'body': body,
          'orgId': orgId,
          'tenantId': orgId,
          if (extraData != null) ...extraData,
        },
      };

      // Write to organization-scoped notifications collection
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection('notifications').add(payload);
      } else {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add(payload);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to write record: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SEND HELPERS FOR ROLE-BASED NOTIFICATIONS
  // ---------------------------------------------------------------------------

  /// 1. Dual-Target: Notifies BOTH Manager and Organization simultaneously.
  /// Used when a Supervisor submits a request, requires approval, or confirms physical arrival.
  static Future<void> notifyManagerAndOrganisation({
    required String title,
    required String body,
    required String requestType,
    required String requestId,
    String? docId,
    String? siteId,
    String? siteName,
    String? status,
    String? senderRole,
    String? senderName,
    String? remarks,
    String? requiredAction,
    String? forSupervisorName,
    String? forSupervisorId,
    String? forManagerName,
    String? forManagerId,
    Map<String, dynamic>? extraData,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Save single unified record with dual target roles (prevents duplicates)
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'manager_and_organisation',
      targetRoles: ['manager', 'organisation'],
      forOrgId: orgId,
      forSupervisorName: forSupervisorName,
      forSupervisorId: forSupervisorId,
      forManagerName: forManagerName,
      requestType: requestType,
      requestId: requestId,
      docId: docId ?? requestId,
      siteId: siteId,
      siteName: siteName,
      status: status,
      senderRole: senderRole ?? 'Supervisor',
      senderName: senderName ?? 'Supervisor',
      remarks: remarks,
      requiredAction: requiredAction ?? 'Action Required: Review & Approve',
      extraData: extraData,
    );

    // 2. Send FCM push to BOTH manager and organization tokens
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['manager', 'organisation', 'config'])
          .where('orgId', isEqualTo: orgId)
          .get();
      final uniqueTokens = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final token = data['token']?.toString();
        final uName = data['userName']?.toString();
        if (token != null && token.isNotEmpty && uName != senderName) {
          uniqueTokens.add(token);
        }
      }
      final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
      final targetEntity = siteId ?? requestId;
      final effectiveType = requestType;
      final idempotencyKey = extraData?['idempotencyKey'] ??
          'evt_${orgId}_${effectiveType}_${targetEntity}_$timeBucket';

      for (final token in uniqueTokens) {
        await _sendFcmPush(
          token: token,
          title: title,
          body: body,
          data: {
            'idempotencyKey': idempotencyKey,
            'requestType': requestType,
            'requestId': requestId,
            'docId': docId ?? requestId,
            'siteId': siteId ?? '',
            'status': status ?? '',
            'requiredAction': requiredAction ?? '',
          },
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending dual-target FCM: $e');
    }
  }

  /// 2. Notifies Manager(s) only.
  /// Used when Organization creates an action, authorizations, or directives for Manager.
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
    String? requiredAction,
    String? forManagerName,
    String? forManagerId,
    Map<String, dynamic>? extraData,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app notification record for Manager only
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'manager',
      targetRoles: ['manager'],
      forManagerName: forManagerName,
      forOrgId: orgId,
      requestType: requestType,
      requestId: requestId,
      docId: docId ?? requestId,
      siteId: siteId,
      siteName: siteName,
      status: status,
      senderRole: senderRole ?? 'Organization',
      senderName: senderName ?? 'Organization HQ',
      remarks: remarks,
      requiredAction: requiredAction,
      extraData: extraData,
    );

    // 2. Send FCM push strictly to Manager tokens (NOT organization)
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', isEqualTo: 'manager')
          .where('orgId', isEqualTo: orgId)
          .get();
      final uniqueTokens = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final token = data['token']?.toString();
        final uName = data['userName']?.toString() ?? '';
        final uId = data['userId']?.toString() ?? '';

        if (forManagerName != null && forManagerName.isNotEmpty) {
          if (uName != forManagerName && uId != forManagerName) continue;
        }

        if (token != null && token.isNotEmpty && uName != senderName) {
          uniqueTokens.add(token);
        }
      }
      final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
      final targetEntity = siteId ?? requestId;
      final effectiveType = requestType;
      final idempotencyKey = extraData?['idempotencyKey'] ??
          'evt_${orgId}_${effectiveType}_${targetEntity}_$timeBucket';

      for (final token in uniqueTokens) {
        await _sendFcmPush(
          token: token,
          title: title,
          body: body,
          data: {
            'idempotencyKey': idempotencyKey,
            'requestType': requestType,
            'requestId': requestId,
            'docId': docId ?? requestId,
            'siteId': siteId ?? '',
            'status': status ?? '',
            'requiredAction': requiredAction ?? '',
          },
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending manager FCM: $e');
    }
  }

  /// 3. Notifies Organization Admins only.
  /// Used when Manager creates a site, forwards a request to HQ, or records manager expenses.
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
    String? requiredAction,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extraData,
  }) async {
    final orgId = FirestoreService.currentOrgId;

    // 1. Write in-app record strictly for Organization
    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'organisation',
      targetRoles: ['organisation'],
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
      requiredAction: requiredAction,
      extraData: extraData ?? data,
    );

    // 2. Send FCM push strictly to Organization / HQ tokens (NOT managers)
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['organisation', 'organization', 'config', 'admin'])
          .where('orgId', isEqualTo: orgId)
          .get();
      final uniqueTokens = <String>{};
      for (final doc in snap.docs) {
        final tokenData = doc.data();
        final token = tokenData['token']?.toString();
        final uName = tokenData['userName']?.toString();
        if (token != null && token.isNotEmpty && uName != senderName) {
          uniqueTokens.add(token);
        }
      }
      final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
      final targetEntity = siteId ?? requestId ?? docId ?? 'global';
      final effectiveType = requestType ?? 'general';
      final idempotencyKey = extraData?['idempotencyKey'] ??
          data?['idempotencyKey'] ??
          'evt_${orgId}_${effectiveType}_${targetEntity}_$timeBucket';

      for (final token in uniqueTokens) {
        await _sendFcmPush(
          token: token,
          title: title,
          body: body,
          data: {
            'idempotencyKey': idempotencyKey,
            'requestType': requestType ?? '',
            'requestId': requestId ?? '',
            'docId': docId ?? requestId ?? '',
            'siteId': siteId ?? '',
            'status': status ?? '',
            'requiredAction': requiredAction ?? '',
            if (data != null) ...data,
            if (extraData != null) ...extraData,
          },
        );
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
    String? requiredAction,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extraData,
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
      requiredAction: requiredAction,
      extraData: {
        'supervisorId': supervisorId ?? '',
        'supervisorName': supervisorName,
        if (data != null) ...data,
        if (extraData != null) ...extraData,
      },
    );

    // 2. Look up supervisor's FCM token and push
    try {
      final snap = await FirestoreService.getCollection(
        'fcmTokens',
      ).where('userType', isEqualTo: 'supervisor').get();

      final uniqueTokens = <String>{};
      for (final doc in snap.docs) {
        final tokenData = doc.data();
        final token = tokenData['token']?.toString();
        final uName = (tokenData['userName'] ?? '').toString();
        final uId = (tokenData['userId'] ?? doc.id).toString();

        final isMatch =
            (supervisorName.isNotEmpty &&
                (uName == supervisorName || uId == supervisorName)) ||
            (supervisorId != null &&
                supervisorId.isNotEmpty &&
                (uId == supervisorId || uName == supervisorId));

        if (token != null && token.isNotEmpty && isMatch) {
          uniqueTokens.add(token);
        }
      }

      final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
      final targetEntity = supervisorId ?? supervisorName;
      final effectiveType = requestType ?? 'supervisor_alert';
      final idempotencyKey = extraData?['idempotencyKey'] ??
          data?['idempotencyKey'] ??
          'evt_${orgId}_${effectiveType}_${targetEntity}_$timeBucket';

      for (final token in uniqueTokens) {
        await _sendFcmPush(
          token: token,
          title: title,
          body: body,
          data: {
            'idempotencyKey': idempotencyKey,
            'requestType': requestType ?? '',
            'requestId': requestId ?? '',
            'docId': docId ?? requestId ?? '',
            'siteId': siteId ?? '',
            'siteName': siteName ?? '',
            'status': status ?? '',
            'title': title,
            'body': body,
            if (data != null) ...data,
            if (extraData != null) ...extraData,
          },
        );
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
    final displaySite =
        (siteId.isNotEmpty && siteName.isNotEmpty && siteId != siteName)
        ? '$siteId - $siteName'
        : (siteName.isNotEmpty ? siteName : siteId);

    final title = '📍 New Site Assignment';
    final locationInfo = (location != null && location.isNotEmpty)
        ? ' located at $location'
        : '';
    final projectInfo = (projectName != null && projectName.isNotEmpty)
        ? ' (Project: $projectName)'
        : '';
    final body =
        'You have been assigned to site "$displaySite"$locationInfo$projectInfo.';

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
    final title = '👤 Manager Account Registered';
    final body =
        'Manager $managerName ($designation, $department) has been registered under ID $managerId.';

    // 1. In-app record for Manager and Organization audit
    await _writeRecord(
      title: title,
      body: body,
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
      body:
          'Manager profile $managerName ($managerId) configured in $department department.',
      targetRole: 'organisation',
      forOrgId: effectiveOrgId,
      requestType: 'manager_config',
      requestId: managerId,
      docId: managerId,
      status: 'active',
      senderRole: 'Organization',
      senderName: 'HQ Administrator',
    );

    // 3. Send FCM push to the specific Manager token
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', isEqualTo: 'manager')
          .where('orgId', isEqualTo: effectiveOrgId)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final token = d['token']?.toString();
        final uName = (d['userName'] ?? '').toString();
        final uId = (d['userId'] ?? doc.id).toString();
        final isMatch =
            uName == managerName || uId == managerId || uId == managerName;
        if (token != null && token.isNotEmpty && isMatch) {
          await _sendFcmPush(
            token: token,
            title: title,
            body: body,
            data: {
              'requestType': 'manager_config',
              'requestId': managerId,
              'docId': managerId,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending manager account FCM: $e');
    }
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
      body:
          'Your Supervisor account ($supervisorId, $designation) has been registered by Manager ${managerName ?? "Admin"}.',
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
      body:
          'Supervisor $supervisorName ($supervisorId) was registered by Manager ${managerName ?? "Admin"}.',
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
    final title = isCreated
        ? '🏗️ New Site Registered'
        : '🏗️ Site Details Updated';
    final actionWord = isCreated ? 'registered' : 'updated';
    final projectInfo = (projectName != null && projectName.isNotEmpty)
        ? ' (Project: $projectName)'
        : '';
    final body =
        'Manager ${managerName ?? "Admin"} $actionWord Site "$siteId - $siteName" at $location$projectInfo.';

    final orgId = FirestoreService.currentOrgId;
    final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
    final idempotencyKey = 'site_mgmt_${orgId}_${siteId}_$timeBucket';

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
      extraData: {
        'idempotencyKey': idempotencyKey,
        'siteId': siteId,
        'siteName': siteName,
        'location': location,
        'projectName': projectName ?? '',
      },
    );
  }

  /// 7a. Notifies Organization when a Manager creates or updates a Project.
  static Future<void> notifyProjectCreatedOrUpdated({
    required String projectId,
    required String projectName,
    required String siteId,
    required String siteName,
    String? location,
    String? managerName,
    bool isCreated = true,
  }) async {
    final title = isCreated ? 'New Project Created' : 'Project Updated';
    final actionWord = isCreated ? 'created a new' : 'updated the';
    final body =
        'Manager ${managerName ?? "Admin"} has $actionWord project: $projectName';

    final orgId = FirestoreService.currentOrgId;
    final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
    final reqType = isCreated ? 'project_created' : 'project_updated';
    final idempotencyKey = '${reqType}_${orgId}_${projectId}_$timeBucket';

    // 1. Notify Organization
    await notifyOrganisation(
      title: title,
      body: body,
      requestType: reqType,
      requestId: projectId,
      docId: projectId,
      siteId: siteId,
      siteName: siteName,
      status: isCreated ? 'created' : 'updated',
      senderRole: 'Manager',
      senderName: managerName ?? 'Manager',
      remarks: 'Project $actionWord in system',
      extraData: {
        'idempotencyKey': idempotencyKey,
        'projectId': projectId,
        'projectName': projectName,
        'siteId': siteId,
        'siteName': siteName,
        'location': location ?? '',
        'type': reqType,
        'actionRoute': '/project_details',
      },
    );
  }

  /// 8. Notifies Managers and Organization when a Master Configuration is updated.
  static Future<void> notifyMasterConfigUpdated({
    required String
    configType, // 'Materials', 'Vehicles', 'Contractors', 'Units'
    required String itemTitle,
    String? senderName,
    String? senderRole,
  }) async {
    final title = '⚙️ $configType Catalogue Updated';
    final body =
        '$itemTitle was added/modified in the $configType configuration by ${senderName ?? "Admin"}.';
    final orgId = FirestoreService.currentOrgId;
    final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ 25000;
    final idempotencyKey = 'master_cfg_${orgId}_${configType.toLowerCase()}_$timeBucket';

    await _writeRecord(
      title: title,
      body: body,
      targetRole: 'manager_and_organisation',
      targetRoles: ['manager', 'organisation'],
      forOrgId: orgId,
      requestType: 'master_config',
      senderRole: senderRole ?? 'Manager',
      senderName: senderName ?? 'Manager',
      remarks: '$configType updated',
      requiredAction: 'Catalog updated',
      extraData: {
        'idempotencyKey': idempotencyKey,
        'configType': configType,
        'itemTitle': itemTitle,
      },
    );

    // Also send FCM push to BOTH managers and organization admins
    try {
      final snap = await FirestoreService.getCollection('fcmTokens')
          .where('userType', whereIn: ['manager', 'organisation', 'config'])
          .where('orgId', isEqualTo: orgId)
          .get();
      final uniqueTokens = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final token = d['token']?.toString();
        final uName = d['userName']?.toString();
        if (token != null && token.isNotEmpty && uName != senderName) {
          uniqueTokens.add(token);
        }
      }
      for (final token in uniqueTokens) {
        await _sendFcmPush(
          token: token,
          title: title,
          body: body,
          data: {
            'idempotencyKey': idempotencyKey,
            'requestType': 'master_config',
            'configType': configType,
            'itemTitle': itemTitle,
          },
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending master_config FCM: $e');
    }
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
      final payload = {
        'token': token,
        'title': title,
        'body': body,
        'orgId': orgId,
        'idempotencyKey': data?['idempotencyKey'],
        'data': data ?? {},
      };

      // Call Cloud Function to dispatch push via Firebase Admin SDK
      await http.post(
        Uri.parse(
          'https://us-central1-cst-whitelabel-app.cloudfunctions.net/sendPushNotification',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': payload}),
      );
    } catch (e) {
      debugPrint(
        'NotificationService: Cloud Function FCM bridge call error: $e',
      );
    }
  }

  /// Automatically update token in Firestore when refreshed.
  static Future<void> _refreshCurrentToken(String newToken) async {
    try {
      final userData = AuthService().userData;
      final userId =
          (userData['uid'] ??
                  userData['username'] ??
                  userData['UserName'] ??
                  userData['Supervisor ID'] ??
                  userData['supervisorId'] ??
                  '')
              .toString();
      final userType = (userData['role'] ?? userData['userRole'] ?? '')
          .toString();
      final userName =
          (userData['FullName'] ??
                  userData['fullName'] ??
                  userData['username'] ??
                  userData['UserName'] ??
                  'User')
              .toString();

      if (userId.isNotEmpty) {
        await saveToken(userId: userId, userType: userType, userName: userName);
      }
      debugPrint(
        'NotificationService: FCM token refreshed & saved successfully',
      );
    } catch (e) {
      debugPrint('NotificationService: Error refreshing token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // STREAMS & LIVE COUNTS
  // ---------------------------------------------------------------------------

  /// Live stream of notifications for a specific user role.
  /// Strictly filters so:
  /// - Manager only receives Manager and dual-target Supervisor submissions.
  /// - Organization only receives Organization and dual-target Supervisor submissions.
  /// - Supervisor only receives notifications specifically addressed to them.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForRole({
    required String role, // 'manager', 'organisation', 'organization', 'supervisor'
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

    final canonicalRole = normalizeRole(role);
    if (canonicalRole == 'supervisor') {
      query = query.where('targetRole', isEqualTo: 'supervisor');
      if (supervisorName != null && supervisorName.isNotEmpty) {
        query = query.where('forSupervisorName', isEqualTo: supervisorName);
      }
    } else if (canonicalRole == 'manager') {
      query = query.where(
        'targetRole',
        whereIn: [
          'manager',
          'manager_and_organisation',
          'manager_and_organization',
        ],
      );
    } else if (canonicalRole == 'organisation') {
      query = query.where(
        'targetRole',
        whereIn: [
          'organisation',
          'organization',
          'manager_and_organisation',
          'manager_and_organization',
        ],
      );
    }

    return query.orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  /// Live stream count of unread notifications for a specific user role.
  static Stream<int> unreadCountForRole({
    required String role, // 'manager', 'organisation', 'organization', 'supervisor'
    String? supervisorName,
    String? managerName,
  }) {
    final orgId = FirestoreService.currentOrgId;
    Query<Map<String, dynamic>> query;

    if (orgId.isNotEmpty && orgId != 'uninitialized') {
      query = FirestoreService.getCollection(
        'notifications',
      ).where('isRead', isEqualTo: false);
    } else {
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('isRead', isEqualTo: false);
    }

    final canonicalRole = normalizeRole(role);
    if (canonicalRole == 'supervisor') {
      query = query.where('targetRole', isEqualTo: 'supervisor');
      if (supervisorName != null && supervisorName.isNotEmpty) {
        query = query.where('forSupervisorName', isEqualTo: supervisorName);
      }
    } else if (canonicalRole == 'manager') {
      query = query.where(
        'targetRole',
        whereIn: [
          'manager',
          'manager_and_organisation',
          'manager_and_organization',
        ],
      );
    } else if (canonicalRole == 'organisation') {
      query = query.where(
        'targetRole',
        whereIn: [
          'organisation',
          'organization',
          'manager_and_organisation',
          'manager_and_organization',
        ],
      );
    }

    return query.snapshots().map((snap) => snap.docs.length);
  }

  /// Live stream of all notifications for a supervisor (backward compatibility).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForSupervisor(
    String supervisorName,
  ) {
    return streamForRole(role: 'supervisor', supervisorName: supervisorName);
  }

  /// Live stream of all notifications for the current organisation (backward compatibility).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForOrganisation() {
    return streamForRole(role: 'organisation');
  }

  /// Live count of unread notifications for a supervisor.
  static Stream<int> unreadCountForSupervisor(String supervisorName) {
    return unreadCountForRole(
      role: 'supervisor',
      supervisorName: supervisorName,
    );
  }

  /// Live count of unread notifications for the organisation.
  static Stream<int> unreadCountForOrganisation() {
    return unreadCountForRole(role: 'organisation');
  }

  /// Mark a notification as read across collections.
  static Future<void> markAsRead(String docId) async {
    try {
      final orgId = FirestoreService.currentOrgId;
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        final orgDocRef = FirestoreService.getCollection(
          'notifications',
        ).doc(docId);
        final orgDoc = await orgDocRef.get();
        if (orgDoc.exists) {
          await orgDocRef.update({'isRead': true});
          return;
        }
      }

      final rootDocRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId);
      final rootDoc = await rootDocRef.get();
      if (rootDoc.exists) {
        await rootDocRef.update({'isRead': true});
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
      final canonicalRole = normalizeRole(role);

      // 1. Mark in org collection
      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        var orgQuery = FirestoreService.getCollection(
          'notifications',
        ).where('isRead', isEqualTo: false);
        if (canonicalRole == 'supervisor') {
          orgQuery = orgQuery.where('targetRole', isEqualTo: 'supervisor');
          if (supervisorName != null && supervisorName.isNotEmpty) {
            orgQuery = orgQuery.where(
              'forSupervisorName',
              isEqualTo: supervisorName,
            );
          }
        } else if (canonicalRole == 'manager') {
          orgQuery = orgQuery.where(
            'targetRole',
            whereIn: [
              'manager',
              'manager_and_organisation',
              'manager_and_organization',
            ],
          );
        } else if (canonicalRole == 'organisation') {
          orgQuery = orgQuery.where(
            'targetRole',
            whereIn: [
              'organisation',
              'organization',
              'manager_and_organisation',
              'manager_and_organization',
            ],
          );
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
      if (canonicalRole == 'supervisor') {
        globalQuery = globalQuery.where('targetRole', isEqualTo: 'supervisor');
        if (supervisorName != null && supervisorName.isNotEmpty) {
          globalQuery = globalQuery.where(
            'forSupervisorName',
            isEqualTo: supervisorName,
          );
        }
      } else if (canonicalRole == 'manager') {
        globalQuery = globalQuery.where(
          'targetRole',
          whereIn: [
            'manager',
            'manager_and_organisation',
            'manager_and_organization',
          ],
        );
      } else if (canonicalRole == 'organisation') {
        globalQuery = globalQuery.where(
          'targetRole',
          whereIn: [
            'organisation',
            'organization',
            'manager_and_organisation',
            'manager_and_organization',
          ],
        );
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
    return markAllReadForRole(
      role: 'supervisor',
      supervisorName: supervisorName,
    );
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
    required String
    targetRole, // 'manager', 'organisation', 'supervisor', 'all'
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
        await FirestoreService.getCollection(
          'scheduled_notifications',
        ).doc(scheduleId).set(payload);
      }

      debugPrint(
        'NotificationService: Scheduled notification $scheduleId for $scheduledTime (repeat: $repeat)',
      );
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
    String body =
        'Please submit today\'s site progress, workforce entries, and material consumption.',
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
      body:
          'You have requisitions awaiting verification for site ${siteId ?? "your projects"}. Please review.',
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
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

      if (orgId.isNotEmpty && orgId != 'uninitialized') {
        await FirestoreService.getCollection(
          'scheduled_notifications',
        ).doc(scheduleId).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint(
        'NotificationService: Cancelled scheduled notification $scheduleId',
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel schedule: $e');
    }
  }

  /// Live stream of active scheduled notifications for the organization.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  streamScheduledNotifications() {
    final orgId = FirestoreService.currentOrgId;
    return FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }
}
