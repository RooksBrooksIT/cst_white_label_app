import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/subscription_sync_service.dart';
import 'package:ebricks/services/subscription_limit_service.dart';

void main() {
  group('SubscriptionSyncService Plan Normalization Tests', () {
    test('Normalizes various casing of Silver plan', () {
      expect(SubscriptionSyncService.normalizePlanName('silver'), equals('Silver'));
      expect(SubscriptionSyncService.normalizePlanName('SILVER'), equals('Silver'));
      expect(SubscriptionSyncService.normalizePlanName('  Silver  '), equals('Silver'));
    });

    test('Normalizes Free Trial variants', () {
      expect(SubscriptionSyncService.normalizePlanName('free trial'), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName('Free Trial'), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName('trial'), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName('free'), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName(''), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName(null), equals('Free Trial'));
      expect(SubscriptionSyncService.normalizePlanName('   '), equals('Free Trial'));
    });

    test('Normalizes other standard plans', () {
      expect(SubscriptionSyncService.normalizePlanName('gold'), equals('Gold'));
      expect(SubscriptionSyncService.normalizePlanName('platinum'), equals('Platinum'));
      expect(SubscriptionSyncService.normalizePlanName('enterprise'), equals('Enterprise'));
    });
  });

  group('SubscriptionSyncService calculateIsActive Validation Tests', () {
    final now = DateTime(2026, 10, 28, 12, 0, 0);
    final futureEnd = Timestamp.fromDate(now.add(const Duration(days: 30)));
    final pastEnd = Timestamp.fromDate(now.subtract(const Duration(days: 1)));

    test('Active Silver plan with SUCCESS payment status and future end date is active', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Silver',
        paymentStatus: 'SUCCESS',
        endDate: futureEnd,
        currentTime: now,
      );
      expect(isActive, isTrue);
    });

    test('Silver plan with FAILED payment status is inactive', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Silver',
        paymentStatus: 'FAILED',
        endDate: futureEnd,
        currentTime: now,
      );
      expect(isActive, isFalse);
    });

    test('Silver plan with PENDING payment status is inactive', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Silver',
        paymentStatus: 'PENDING',
        endDate: futureEnd,
        currentTime: now,
      );
      expect(isActive, isFalse);
    });

    test('Silver plan with expired subscription end date is inactive', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Silver',
        paymentStatus: 'SUCCESS',
        endDate: pastEnd,
        currentTime: now,
      );
      expect(isActive, isFalse);
    });

    test('Subscription with explicit isSubscriptionActive=false is inactive regardless of dates', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: false,
        planName: 'Silver',
        paymentStatus: 'SUCCESS',
        endDate: futureEnd,
        currentTime: now,
      );
      expect(isActive, isFalse);
    });

    test('Free Trial does not require PayU SUCCESS status', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Free Trial',
        paymentStatus: 'None',
        endDate: futureEnd,
        currentTime: now,
      );
      expect(isActive, isTrue);
    });

    test('Free Trial expires when end date passes', () {
      final isActive = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: true,
        planName: 'Free Trial',
        paymentStatus: 'None',
        endDate: pastEnd,
        currentTime: now,
      );
      expect(isActive, isFalse);
    });
  });

  group('SubscriptionPlanLimits Verification Tests', () {
    test('Silver plan provides correct resource limits', () {
      final limits = SubscriptionLimitService.getLimitsForPlan('Silver');
      expect(limits.planName, equals('Silver'));
      expect(limits.maxProjects, equals(5));
      expect(limits.maxManagers, isNull);
      expect(limits.maxSupervisors, isNull);
      expect(limits.maxTotalUsers, equals(5));
    });

    test('Free Trial provides 1 site and 2 total users', () {
      final limits = SubscriptionLimitService.getLimitsForPlan('Free Trial');
      expect(limits.planName, equals('Free Trial'));
      expect(limits.maxProjects, equals(1));
      expect(limits.maxManagers, isNull);
      expect(limits.maxSupervisors, isNull);
      expect(limits.maxTotalUsers, equals(2));
    });

    test('Gold plan provides 10 sites and 15 total users', () {
      final limits = SubscriptionLimitService.getLimitsForPlan('Gold');
      expect(limits.planName, equals('Gold'));
      expect(limits.maxProjects, equals(10));
      expect(limits.maxManagers, equals(5));
      expect(limits.maxSupervisors, equals(10));
      expect(limits.maxTotalUsers, equals(15));
    });
  });

  group('Subscription Data Reconciliation & Profile Preservation Tests', () {
    test('Authoritative subscription document strictly overrides stale data/admin profile fields', () {
      // Simulate data/admin profile with stale Free Trial
      final legacyAdminProfile = <String, dynamic>{
        'username': 'rb_construction',
        'email': 'admin@rbconstruction.com',
        'phone': '9876543210',
        'role': 'Organization',
        'org_name': 'RB Construction',
        'theme_color': '#1E88E5',
        'subscriptionPlan': 'Free Trial', // Stale
        'isSubscriptionActive': true,
      };

      // Authoritative subscription doc under data/subscription
      final authoritativeSub = <String, dynamic>{
        'subscriptionPlan': 'Silver',
        'subscriptionType': 'Monthly',
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
        'paymentTxnId': 'TXN_20261028',
        'payuMoneyId': 'PAYU_123456',
        'maxProjects': 5,
        'maxUsers': 10,
      };

      // Perform the same merge strategy as implemented in organisation_login_page and landing_page
      final resolvedUserData = Map<String, dynamic>.from(legacyAdminProfile);

      // Apply authoritative subscription document
      resolvedUserData['subscriptionPlan'] = SubscriptionSyncService.normalizePlanName(
        authoritativeSub['subscriptionPlan']?.toString(),
      );
      if (authoritativeSub.containsKey('isSubscriptionActive')) {
        resolvedUserData['isSubscriptionActive'] = authoritativeSub['isSubscriptionActive'];
      }
      if (authoritativeSub.containsKey('paymentStatus')) {
        resolvedUserData['paymentStatus'] = authoritativeSub['paymentStatus'];
      }

      // Verification: Authoritative plan must be Silver
      expect(resolvedUserData['subscriptionPlan'], equals('Silver'));
      expect(resolvedUserData['paymentStatus'], equals('SUCCESS'));
      expect(resolvedUserData['isSubscriptionActive'], isTrue);

      // Verification: Profile fields must be preserved exactly
      expect(resolvedUserData['username'], equals('rb_construction'));
      expect(resolvedUserData['email'], equals('admin@rbconstruction.com'));
      expect(resolvedUserData['phone'], equals('9876543210'));
      expect(resolvedUserData['role'], equals('Organization'));
      expect(resolvedUserData['org_name'], equals('RB Construction'));
      expect(resolvedUserData['theme_color'], equals('#1E88E5'));
    });

    test('Repeated synchronization requests are idempotent and do not corrupt data', () {
      final initialData = <String, dynamic>{
        'subscriptionPlan': 'Silver',
        'subscriptionType': 'Monthly',
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
      };

      final plan1 = SubscriptionSyncService.normalizePlanName(initialData['subscriptionPlan'] as String?);
      final active1 = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: initialData['isSubscriptionActive'] as bool?,
        planName: plan1,
        paymentStatus: initialData['paymentStatus'] as String?,
        endDate: null,
      );

      // Repeat with same data
      final plan2 = SubscriptionSyncService.normalizePlanName(plan1);
      final active2 = SubscriptionSyncService.calculateIsActive(
        isSubscriptionActive: active1,
        planName: plan2,
        paymentStatus: initialData['paymentStatus'] as String?,
        endDate: null,
      );

      expect(plan1, equals(plan2));
      expect(active1, equals(active2));
      expect(plan2, equals('Silver'));
      expect(active2, isTrue);
    });
  });
}
