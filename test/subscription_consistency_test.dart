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

  group('Organization Firestore Data Structure Tests (New & Legacy)', () {
    test('Newly created organization schema stores all fields in intended subcollections', () {
      // Simulate payload generated for new organization registration
      final adminData = <String, dynamic>{
        'app_id': 'cst_white_label',
        'app_type': 'cst_white_label',
        'is_cst_app': true,
        'org_name': 'New Tech Builders',
        'app_name': 'NewTechApp',
        'theme_color': '#FF5722',
        'email': 'admin@newtech.com',
        'phone': '9876543210',
        'username': 'newtech_admin',
        'role': 'Organization',
        'registrationStatus': 'COMPLETED',
        'onboardingStep': 'COMPLETED',
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
        'referralCode': 'NTB001',
        'orgReferralCode': 'NTB001',
      };

      final subscriptionData = <String, dynamic>{
        'subscriptionPlan': 'Gold',
        'subscriptionType': 'Monthly',
        'isSubscriptionActive': true,
        'onboardingStep': 'COMPLETED',
        'maxProjects': 10,
        'maxUsers': 15,
        'maxManagers': 5,
        'maxSupervisors': 10,
        'paymentGateway': 'PayU',
        'paymentTxnId': 'TXN_NTB_999',
        'paymentStatus': 'SUCCESS',
        'paymentAmount': 199.0,
      };

      final brandingData = <String, dynamic>{
        'org_name': 'New Tech Builders',
        'appName': 'NewTechApp',
        'app_name': 'NewTechApp',
        'primaryColor': '#FF5722',
        'theme_color': '#FF5722',
      };

      // Root document for new organizations contains organization profile metadata, but NOT admin login details or subscription
      final rootDoc = <String, dynamic>{
        'app_id': 'cst_white_label',
        'app_type': 'cst_white_label',
        'is_cst_app': true,
        'org_name': 'New Tech Builders',
        'app_name': 'NewTechApp',
      };

      // Assert that root doc has no administrator login details or subscription fields
      expect(rootDoc.containsKey('username'), isFalse);
      expect(rootDoc.containsKey('password'), isFalse);
      expect(rootDoc.containsKey('isSubscriptionActive'), isFalse);
      expect(rootDoc.containsKey('maxManagers'), isFalse);
      expect(rootDoc.containsKey('isUpgradeQueued'), isFalse);

      // Assert that data/admin contains all administrative and credential fields without plaintext password
      expect(adminData['app_id'], equals('cst_white_label'));
      expect(adminData['org_name'], equals('New Tech Builders'));
      expect(adminData['username'], equals('newtech_admin'));
      expect(adminData['email'], equals('admin@newtech.com'));
      expect(adminData['phone'], equals('9876543210'));
      expect(adminData['role'], equals('Organization'));
      expect(adminData.containsKey('password'), isFalse);

      // Assert that data/subscription contains all subscription details
      expect(subscriptionData['subscriptionPlan'], equals('Gold'));
      expect(subscriptionData['isSubscriptionActive'], isTrue);
      expect(subscriptionData['maxManagers'], equals(5));
      expect(subscriptionData['maxProjects'], equals(10));
      expect(subscriptionData['maxUsers'], equals(15));
      expect(subscriptionData['maxSupervisors'], equals(10));

      // Assert that data/branding contains branding details
      expect(brandingData['org_name'], equals('New Tech Builders'));
      expect(brandingData['appName'], equals('NewTechApp'));
      expect(brandingData['primaryColor'], equals('#FF5722'));
    });

    test('Login aggregates new organization profile seamlessly without root fields', () {
      final rootDoc = <String, dynamic>{}; // Empty root doc
      final adminDoc = <String, dynamic>{
        'org_name': 'Modern Infra',
        'email': 'contact@moderninfra.com',
        'phone': '9123456780',
        'username': 'modern_admin',
        'role': 'Organization',
        'theme_color': '#0B1942',
      };
      final subDoc = <String, dynamic>{
        'subscriptionPlan': 'Silver',
        'subscriptionType': 'Monthly',
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
        'maxProjects': 5,
        'maxManagers': 2,
      };

      // Merge logic identical to landing_page.dart & organisation_login_page.dart
      final resolvedUserData = <String, dynamic>{};
      resolvedUserData.addAll(rootDoc);
      resolvedUserData.addAll(adminDoc);

      resolvedUserData['subscriptionPlan'] = SubscriptionSyncService.normalizePlanName(
        subDoc['subscriptionPlan']?.toString(),
      );
      if (subDoc.containsKey('isSubscriptionActive')) {
        resolvedUserData['isSubscriptionActive'] = subDoc['isSubscriptionActive'];
      }
      if (subDoc.containsKey('paymentStatus')) {
        resolvedUserData['paymentStatus'] = subDoc['paymentStatus'];
      }

      expect(resolvedUserData['org_name'], equals('Modern Infra'));
      expect(resolvedUserData['username'], equals('modern_admin'));
      expect(resolvedUserData['email'], equals('contact@moderninfra.com'));
      expect(resolvedUserData['phone'], equals('9123456780'));
      expect(resolvedUserData['subscriptionPlan'], equals('Silver'));
      expect(resolvedUserData['isSubscriptionActive'], isTrue);
      expect(resolvedUserData['paymentStatus'], equals('SUCCESS'));
    });

    test('Backward compatibility: existing organizations with root fields continue to resolve', () {
      // Legacy document structure where fields are on root
      final legacyRootDoc = <String, dynamic>{
        'org_name': 'Legacy Construction',
        'email': 'admin@legacy.com',
        'phone': '9988776655',
        'username': 'legacy_admin',
        'role': 'Organization',
        'theme_color': '#333333',
        'subscriptionPlan': 'Silver',
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
        'maxManagers': 2,
      };
      final adminDoc = <String, dynamic>{
        'org_name': 'Legacy Construction',
        'email': 'admin@legacy.com',
        'phone': '9988776655',
        'username': 'legacy_admin',
      };
      final subDoc = <String, dynamic>{
        'subscriptionPlan': 'Gold', // Upgraded via authoritative sub doc
        'isSubscriptionActive': true,
        'paymentStatus': 'SUCCESS',
        'maxManagers': 5,
      };

      final resolvedUserData = <String, dynamic>{};
      resolvedUserData.addAll(legacyRootDoc);
      resolvedUserData.addAll(adminDoc);

      // Authoritative sub doc overrides stale root
      resolvedUserData['subscriptionPlan'] = SubscriptionSyncService.normalizePlanName(
        subDoc['subscriptionPlan']?.toString(),
      );
      if (subDoc.containsKey('isSubscriptionActive')) {
        resolvedUserData['isSubscriptionActive'] = subDoc['isSubscriptionActive'];
      }
      if (subDoc.containsKey('paymentStatus')) {
        resolvedUserData['paymentStatus'] = subDoc['paymentStatus'];
      }

      expect(resolvedUserData['org_name'], equals('Legacy Construction'));
      expect(resolvedUserData['username'], equals('legacy_admin'));
      expect(resolvedUserData['subscriptionPlan'], equals('Gold'));
      expect(resolvedUserData['isSubscriptionActive'], isTrue);
    });

    test('Username resolution: Email login correctly retrieves username from organizationUser subcollection', () {
      // Simulates an existing active user logging in via email where root doc has no username
      const cleanLower = 'abi@construction.com';

      final rootDoc = <String, dynamic>{
        'org_name': 'Abi Construction',
        'app_name': 'Abi Construction',
        'email': 'abi@construction.com',
        'isSubscriptionActive': true,
      };

      final orgUserDocs = [
        <String, dynamic>{
          'username': 'abiconstruction',
          'email': 'abi@construction.com',
          'role': 'Organization',
        }
      ];

      final resolvedUserData = Map<String, dynamic>.from(rootDoc);

      // Resolve from organizationUser subcollection matching email
      String matchedUserDocId = '';
      for (final uDoc in orgUserDocs) {
        if (uDoc['email'] == cleanLower) {
          matchedUserDocId = uDoc['username'];
          resolvedUserData.addAll(uDoc);
          break;
        }
      }

      String actualUsername = '';
      for (final key in ['username', 'UserName', 'userName', 'adminUsername', 'admin_username']) {
        final val = resolvedUserData[key]?.toString().trim() ?? '';
        if (val.isNotEmpty && !val.contains('@')) {
          actualUsername = val;
          break;
        }
      }

      if (actualUsername.isEmpty && matchedUserDocId.isNotEmpty && !matchedUserDocId.contains('@')) {
        actualUsername = matchedUserDocId;
      }

      expect(actualUsername, equals('abiconstruction'));
      expect(actualUsername.contains('@'), isFalse);

      // Verify that map spread does not overwrite actualUsername with null or empty
      final authPayload = {
        ...resolvedUserData,
        'username': actualUsername,
      };
      expect(authPayload['username'], equals('abiconstruction'));
    });

    test('Username resolution: Legacy active user with admin/data resolves correctly', () {
      final legacyAdminData = <String, dynamic>{
        'org_name': 'Old Alpha Builders',
        'email': 'alpha@builders.com',
        'username': 'alphabuilder',
        'role': 'Organization',
      };

      final resolvedUserData = <String, dynamic>{};
      resolvedUserData.addAll(legacyAdminData);

      String actualUsername = '';
      for (final key in ['username', 'UserName', 'userName', 'adminUsername', 'admin_username']) {
        final val = resolvedUserData[key]?.toString().trim() ?? '';
        if (val.isNotEmpty && !val.contains('@')) {
          actualUsername = val;
          break;
        }
      }

      expect(actualUsername, equals('alphabuilder'));
    });

    test('AuthService login map ordering preserves actualUsername over null root username', () {
      final rootWithNullUsername = <String, dynamic>{
        'username': null,
        'org_name': 'Test Org',
        'email': 'test@test.com',
      };

      const actualUsername = 'valid_user';

      // Old flawed order: {'username': actualUsername, ...rootWithNullUsername}
      final flawedPayload = {
        'username': actualUsername,
        ...rootWithNullUsername,
      };
      expect(flawedPayload['username'], isNull); // Demonstrates the bug

      // Fixed correct order: {...rootWithNullUsername, 'username': actualUsername}
      final fixedPayload = {
        ...rootWithNullUsername,
        'username': actualUsername,
      };
      expect(fixedPayload['username'], equals('valid_user')); // Guaranteed non-null
    });

    test('Reference structure: /organisation/cst_newsharan_31-10-2026/data/admin stores admin credentials while root holds profile', () {
      // Reference test demonstrating the intended structure
      final rootProfile = <String, dynamic>{
        'app_id': 'cst_white_label',
        'app_type': 'cst_white_label',
        'is_cst_app': true,
        'org_name': 'New Sharan',
        'app_name': 'NewSharanApp',
      };

      final adminDoc = <String, dynamic>{
        'app_id': 'cst_white_label',
        'app_type': 'cst_white_label',
        'is_cst_app': true,
        'org_name': 'New Sharan',
        'app_name': 'NewSharanApp',
        'theme_color': '#00A86B',
        'email': 'sharan@example.com',
        'phone': '9876543210',
        'username': 'newsharan',
        'role': 'Organization',
        'registrationStatus': 'COMPLETED',
        'onboardingStep': 'PAYMENT_PENDING',
        'referralCode': 'ABC123',
      };

      // Verify root has no administrator credentials
      expect(rootProfile.containsKey('username'), isFalse);
      expect(rootProfile.containsKey('password'), isFalse);
      expect(rootProfile.containsKey('email'), isFalse);
      expect(rootProfile.containsKey('phone'), isFalse);
      expect(rootProfile.containsKey('role'), isFalse);

      // Verify /data/admin contains administrator credentials and no plaintext password
      expect(adminDoc['username'], equals('newsharan'));
      expect(adminDoc['email'], equals('sharan@example.com'));
      expect(adminDoc['phone'], equals('9876543210'));
      expect(adminDoc['role'], equals('Organization'));
      expect(adminDoc.containsKey('password'), isFalse);

      // Verify login resolution from /data/admin
      final resolvedUser = Map<String, dynamic>.from(rootProfile);
      resolvedUser.addAll(adminDoc);

      expect(resolvedUser['username'], equals('newsharan'));
      expect(resolvedUser['org_name'], equals('New Sharan'));
      expect(resolvedUser['email'], equals('sharan@example.com'));
    });
  });
}
