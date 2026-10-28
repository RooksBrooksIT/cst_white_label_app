import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

/// Service responsible for establishing `/organisation/{orgId}/data/subscription`
/// as the single authoritative source of truth for organization subscriptions,
/// and synchronizing legacy fields across related documents atomically and idempotently.
class SubscriptionSyncService {
  static const String authoritativeSubDocName = 'subscription';

  /// Standardizes plan names (e.g., "silver" -> "Silver", "free trial" -> "Free Trial")
  static String normalizePlanName(String? rawPlan) {
    if (rawPlan == null || rawPlan.trim().isEmpty) return 'Free Trial';
    final trimmed = rawPlan.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'free trial' || lower == 'trial' || lower == 'free') {
      return 'Free Trial';
    }
    if (lower == 'silver') return 'Silver';
    if (lower == 'gold') return 'Gold';
    if (lower == 'platinum') return 'Platinum';
    if (lower == 'enterprise') return 'Enterprise';
    // Capitalize first letter of each word if custom
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Calculates whether a subscription is currently active based on authoritative rules:
  /// 1. If explicit `isSubscriptionActive` is false -> false
  /// 2. If paid plan (not Free Trial), `paymentStatus` must be SUCCESS
  /// 3. If `subscriptionEndDate` is set, it must not be expired
  static bool calculateIsActive({
    required bool? isSubscriptionActive,
    required String? planName,
    required String? paymentStatus,
    required Timestamp? endDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final normalizedPlan = normalizePlanName(planName);
    final isTrial = normalizedPlan == 'Free Trial';

    // 1. If explicitly deactivated
    if (isSubscriptionActive == false) {
      return false;
    }

    // 2. Paid plans require verified successful payment
    if (!isTrial) {
      final statusUpper = (paymentStatus ?? '').trim().toUpperCase();
      if (statusUpper.isNotEmpty && statusUpper != 'SUCCESS') {
        return false;
      }
    }

    // 3. Expiry check
    if (endDate != null) {
      if (endDate.toDate().isBefore(now)) {
        return false;
      }
    }

    // Default to true if active flag is not explicitly false and not expired
    return isSubscriptionActive ?? true;
  }

  /// Synchronizes subscription state across all organization documents:
  /// - Authoritative: `/organisation/{orgId}/data/subscription`
  /// - Root: `/organisation/{orgId}`
  /// - Canonical Admin Profile: `/organisation/{orgId}/data/admin`
  /// - Legacy duplicate doc (if exists): `/organisation/{orgId}/admin/data`
  /// - Legacy duplicate doc (if exists): `/organisation/{orgId}/data/data`
  /// - Alternate namespace doc (if exists): prefixed or unprefixed counterpart
  ///
  /// Non-subscription profile fields (username, email, phone, role, password, org_name, etc.)
  /// are strictly preserved.
  static Future<Map<String, dynamic>> syncOrganizationSubscription(
    String orgId, {
    Map<String, dynamic>? authoritativeOverride,
    bool updateAuthService = true,
    FirebaseFirestore? firestoreInstance,
  }) async {
    final db = firestoreInstance ?? FirebaseFirestore.instance;
    final cleanOrgId = orgId.trim();

    if (cleanOrgId.isEmpty || cleanOrgId == 'uninitialized') {
      debugPrint('[SubscriptionSync] Invalid orgId: $cleanOrgId. Skipping sync.');
      return {};
    }

    try {
      final orgDocRef = db.collection('organisation').doc(cleanOrgId);
      final subDocRef = orgDocRef.collection('data').doc(authoritativeSubDocName);
      final adminDocRef = orgDocRef.collection('data').doc('admin');
      final legacyAdminDataRef = orgDocRef.collection('admin').doc('data');
      final legacyDataDataRef = orgDocRef.collection('data').doc('data');

      final altOrgId = cleanOrgId.startsWith(FirestoreService.cstNamespacePrefix)
          ? cleanOrgId.substring(FirestoreService.cstNamespacePrefix.length)
          : '${FirestoreService.cstNamespacePrefix}$cleanOrgId';
      final altDocRef = db.collection('organisation').doc(altOrgId);

      // Fetch existing documents in parallel
      final futures = await Future.wait([
        subDocRef.get().catchError((e) => null as dynamic),
        orgDocRef.get().catchError((e) => null as dynamic),
        adminDocRef.get().catchError((e) => null as dynamic),
        legacyAdminDataRef.get().catchError((e) => null as dynamic),
        legacyDataDataRef.get().catchError((e) => null as dynamic),
        altDocRef.get().catchError((e) => null as dynamic),
      ]);

      final subSnap = futures[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final rootSnap = futures[1] as DocumentSnapshot<Map<String, dynamic>>?;
      final adminSnap = futures[2] as DocumentSnapshot<Map<String, dynamic>>?;
      final legacyAdminDataSnap = futures[3] as DocumentSnapshot<Map<String, dynamic>>?;
      final legacyDataDataSnap = futures[4] as DocumentSnapshot<Map<String, dynamic>>?;
      final altDocSnap = futures[5] as DocumentSnapshot<Map<String, dynamic>>?;

      // 1. Establish Authoritative Subscription Data
      Map<String, dynamic> authData = {};

      if (authoritativeOverride != null && authoritativeOverride.isNotEmpty) {
        authData = Map<String, dynamic>.from(authoritativeOverride);
      } else if (subSnap != null && subSnap.exists && subSnap.data() != null) {
        authData = Map<String, dynamic>.from(subSnap.data()!);
      } else if (rootSnap != null && rootSnap.exists && rootSnap.data() != null) {
        // Fallback: migrate legacy subscription info from root doc
        final rData = rootSnap.data()!;
        if (rData.containsKey('subscriptionPlan') || rData.containsKey('isSubscriptionActive')) {
          authData = {
            'subscriptionPlan': rData['subscriptionPlan'] ?? 'Free Trial',
            'subscriptionType': rData['subscriptionType'] ?? 'Monthly',
            'subscriptionStartDate': rData['subscriptionStartDate'],
            'subscriptionEndDate': rData['subscriptionEndDate'],
            'isSubscriptionActive': rData['isSubscriptionActive'] ?? true,
            'paymentStatus': rData['paymentStatus'] ?? 'SUCCESS',
            'paymentTxnId': rData['paymentTxnId'] ?? '',
            'payuMoneyId': rData['payuMoneyId'] ?? '',
            'paymentAmount': rData['paymentAmount'] ?? 0,
            'maxProjects': rData['maxProjects'],
            'maxUsers': rData['maxUsers'],
            'maxManagers': rData['maxManagers'],
            'maxSupervisors': rData['maxSupervisors'],
          };
        }
      } else if (adminSnap != null && adminSnap.exists && adminSnap.data() != null) {
        // Fallback: migrate legacy subscription info from data/admin doc
        final aData = adminSnap.data()!;
        authData = {
          'subscriptionPlan': aData['subscriptionPlan'] ?? 'Free Trial',
          'isSubscriptionActive': aData['isSubscriptionActive'] ?? true,
          'paymentStatus': aData['paymentStatus'] ?? 'SUCCESS',
        };
      }

      // If no subscription record found anywhere, default to Free Trial
      if (authData.isEmpty) {
        final now = DateTime.now();
        authData = {
          'subscriptionPlan': 'Free Trial',
          'subscriptionType': 'Free Trial',
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 14))),
          'isSubscriptionActive': true,
          'paymentStatus': 'SUCCESS',
          'paymentGateway': 'None',
        };
      }

      // 2. Check for queued upgrade activation
      final now = DateTime.now();
      final isQueued = authData['isUpgradeQueued'] as bool? ?? false;
      final queuedPlan = authData['queuedPlan'] as String?;
      final queuedStart = (authData['queuedStartDate'] as Timestamp?)?.toDate();

      if (isQueued && queuedPlan != null && queuedStart != null && !now.isBefore(queuedStart)) {
        authData['subscriptionPlan'] = queuedPlan;
        authData['subscriptionType'] = authData['queuedPlanType'] ?? 'Monthly';
        authData['subscriptionStartDate'] = Timestamp.fromDate(queuedStart);
        authData['subscriptionEndDate'] = authData['queuedEndDate'] ??
            Timestamp.fromDate(queuedStart.add(const Duration(days: 30)));
        authData['isSubscriptionActive'] = true;
        authData['isUpgradeQueued'] = false;
        authData['paymentStatus'] = authData['queuedPaymentStatus'] ?? 'SUCCESS';
        authData['paymentTxnId'] = authData['queuedPaymentTxnId'] ?? '';
        authData['payuMoneyId'] = authData['queuedPayuMoneyId'] ?? '';
        if (authData['queuedMaxProjects'] != null) {
          authData['maxProjects'] = authData['queuedMaxProjects'];
        }
        if (authData['queuedMaxUsers'] != null) {
          authData['maxUsers'] = authData['queuedMaxUsers'];
        }
        if (authData['queuedMaxManagers'] != null) {
          authData['maxManagers'] = authData['queuedMaxManagers'];
        }
        if (authData['queuedMaxSupervisors'] != null) {
          authData['maxSupervisors'] = authData['queuedMaxSupervisors'];
        }
      }

      // 3. Resolve authoritative fields
      final normalizedPlan = normalizePlanName(authData['subscriptionPlan'] as String?);
      final endDateTs = authData['subscriptionEndDate'] as Timestamp?;
      final paymentStatus = (authData['paymentStatus'] as String? ?? 'SUCCESS').toUpperCase();
      final rawIsActive = authData['isSubscriptionActive'] as bool? ?? true;

      final bool resolvedIsActive = calculateIsActive(
        isSubscriptionActive: rawIsActive,
        planName: normalizedPlan,
        paymentStatus: paymentStatus,
        endDate: endDateTs,
        currentTime: now,
      );

      // Build authoritative subscription document payload
      final authoritativeSubPayload = <String, dynamic>{
        ...authData,
        'subscriptionPlan': normalizedPlan,
        'paymentStatus': paymentStatus,
        'isSubscriptionActive': resolvedIsActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!resolvedIsActive && rawIsActive) {
        authoritativeSubPayload['deactivatedReason'] = 'EXPIRED_OR_UNPAID';
      }

      // Build synchronized payload for root document
      final rootSyncPayload = <String, dynamic>{
        'subscriptionPlan': normalizedPlan,
        'isSubscriptionActive': resolvedIsActive,
        'paymentStatus': paymentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (authoritativeSubPayload['subscriptionType'] != null) {
        rootSyncPayload['subscriptionType'] = authoritativeSubPayload['subscriptionType'];
      }
      if (authoritativeSubPayload['subscriptionStartDate'] != null) {
        rootSyncPayload['subscriptionStartDate'] = authoritativeSubPayload['subscriptionStartDate'];
      }
      if (authoritativeSubPayload['subscriptionEndDate'] != null) {
        rootSyncPayload['subscriptionEndDate'] = authoritativeSubPayload['subscriptionEndDate'];
      }
      if (authoritativeSubPayload['paymentTxnId'] != null) {
        rootSyncPayload['paymentTxnId'] = authoritativeSubPayload['paymentTxnId'];
      }
      if (authoritativeSubPayload['payuMoneyId'] != null) {
        rootSyncPayload['payuMoneyId'] = authoritativeSubPayload['payuMoneyId'];
      }
      if (authoritativeSubPayload['paymentAmount'] != null) {
        rootSyncPayload['paymentAmount'] = authoritativeSubPayload['paymentAmount'];
      }
      if (authoritativeSubPayload['maxProjects'] != null) {
        rootSyncPayload['maxProjects'] = authoritativeSubPayload['maxProjects'];
      }
      if (authoritativeSubPayload['maxUsers'] != null) {
        rootSyncPayload['maxUsers'] = authoritativeSubPayload['maxUsers'];
      }
      if (authoritativeSubPayload['maxManagers'] != null) {
        rootSyncPayload['maxManagers'] = authoritativeSubPayload['maxManagers'];
      }
      if (authoritativeSubPayload['maxSupervisors'] != null) {
        rootSyncPayload['maxSupervisors'] = authoritativeSubPayload['maxSupervisors'];
      }

      // Build synchronized payload for canonical data/admin doc (preserves profile data via merge)
      final adminSyncPayload = <String, dynamic>{
        'subscriptionPlan': normalizedPlan,
        'isSubscriptionActive': resolvedIsActive,
        'paymentStatus': paymentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // 4. Atomic Batched Write
      final batch = db.batch();

      // (a) Authoritative subscription doc
      batch.set(subDocRef, authoritativeSubPayload, SetOptions(merge: true));

      // (b) Root org doc
      batch.set(orgDocRef, rootSyncPayload, SetOptions(merge: true));

      // (c) Canonical admin doc (data/admin)
      batch.set(adminDocRef, adminSyncPayload, SetOptions(merge: true));

      // (d) Synchronize legacy duplicate admin/data doc if and only if it exists
      if (legacyAdminDataSnap != null && legacyAdminDataSnap.exists) {
        batch.set(legacyAdminDataRef, adminSyncPayload, SetOptions(merge: true));
      }

      // (e) Synchronize legacy duplicate data/data doc if and only if it exists
      if (legacyDataDataSnap != null && legacyDataDataSnap.exists) {
        batch.set(legacyDataDataRef, adminSyncPayload, SetOptions(merge: true));
      }

      // (f) Synchronize alternate namespace doc if it exists
      if (altDocSnap != null && altDocSnap.exists) {
        batch.set(altDocRef, rootSyncPayload, SetOptions(merge: true));
        batch.set(altDocRef.collection('data').doc(authoritativeSubDocName),
            authoritativeSubPayload, SetOptions(merge: true));
        batch.set(altDocRef.collection('data').doc('admin'), adminSyncPayload,
            SetOptions(merge: true));
      }

      await batch.commit();

      debugPrint(
        '[SubscriptionSync] Successfully synchronized org $cleanOrgId: plan=$normalizedPlan, active=$resolvedIsActive, status=$paymentStatus',
      );

      // 5. Update local session state if requested and current user is organization
      if (updateAuthService) {
        try {
          final auth = AuthService();
          if (auth.isLoggedIn && auth.userRole == UserRole.organization) {
            await auth.updateUserData({
              'subscriptionPlan': normalizedPlan,
              'isSubscriptionActive': resolvedIsActive,
              'paymentStatus': paymentStatus,
              if (authoritativeSubPayload['subscriptionType'] != null)
                'subscriptionType': authoritativeSubPayload['subscriptionType'],
              if (authoritativeSubPayload['subscriptionStartDate'] != null)
                'subscriptionStartDate': authoritativeSubPayload['subscriptionStartDate'],
              if (authoritativeSubPayload['subscriptionEndDate'] != null)
                'subscriptionEndDate': authoritativeSubPayload['subscriptionEndDate'],
            });
          }
        } catch (authErr) {
          debugPrint('[SubscriptionSync] AuthService update note: $authErr');
        }
      }

      return authoritativeSubPayload;
    } catch (e, stack) {
      debugPrint('[SubscriptionSync] Error synchronizing subscription for $cleanOrgId: $e\n$stack');
      return {};
    }
  }

  /// Fetches authoritative subscription details for an organization,
  /// falling back safely if the subscription document has not yet been initialized.
  static Future<Map<String, dynamic>> getAuthoritativeSubscription(
    String orgId, {
    FirebaseFirestore? firestoreInstance,
  }) async {
    final db = firestoreInstance ?? FirebaseFirestore.instance;
    final cleanOrgId = orgId.trim();
    if (cleanOrgId.isEmpty || cleanOrgId == 'uninitialized') return {};

    try {
      final subRef = db
          .collection('organisation')
          .doc(cleanOrgId)
          .collection('data')
          .doc(authoritativeSubDocName);

      var snap = await subRef.get();
      if (snap.exists && snap.data() != null) {
        return snap.data()!;
      }

      // Fallback 1: Root org doc
      final rootSnap = await db.collection('organisation').doc(cleanOrgId).get();
      if (rootSnap.exists && rootSnap.data() != null) {
        final data = rootSnap.data()!;
        if (data.containsKey('subscriptionPlan')) {
          return data;
        }
      }

      // Fallback 2: data/admin
      final adminSnap = await db
          .collection('organisation')
          .doc(cleanOrgId)
          .collection('data')
          .doc('admin')
          .get();
      if (adminSnap.exists && adminSnap.data() != null) {
        return adminSnap.data()!;
      }
    } catch (e) {
      debugPrint('[SubscriptionSync] Error fetching authoritative subscription: $e');
    }

    return {};
  }
}
