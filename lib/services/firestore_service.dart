import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class OrganizationValidationResult {
  final bool isValid;
  final String? errorMessage;
  final bool isOrgNameDuplicate;
  final bool isEmailDuplicate;
  final bool isPhoneDuplicate;
  final bool isUsernameDuplicate;
  final Map<String, dynamic>? pendingData;
  final String? pendingOrgId;

  const OrganizationValidationResult({
    required this.isValid,
    this.errorMessage,
    this.isOrgNameDuplicate = false,
    this.isEmailDuplicate = false,
    this.isPhoneDuplicate = false,
    this.isUsernameDuplicate = false,
    this.pendingData,
    this.pendingOrgId,
  });
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static String? _cachedDynamicPath;

  /// Application identifier for strict cross-application data isolation in shared Firebase project
  static const String cstAppId = 'cst_white_label';
  static const String cstNamespacePrefix = 'cst_';

  /// Checks if an organization ID belongs to the CST White Label application namespace.
  static bool isCstOrgId(String orgId) {
    if (orgId.isEmpty || orgId == 'uninitialized') return false;
    return orgId.startsWith(cstNamespacePrefix) || orgId.contains('cst');
  }

  /// Returns true if the service has a valid organization path cached.
  static bool get isReady =>
      _cachedDynamicPath != null && _cachedDynamicPath!.isNotEmpty;

  /// Initializes the service by loading the dynamic path from SharedPreferences.
  /// Should be called after login or at app startup.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Prioritize the unified key first
    String? path = prefs.getString('org_dynamic_path');

    if (path == null || path.isEmpty) {
      // If unified key is missing, check which role was last logged in
      final roleStr = prefs.getString('auth_user_role');
      if (roleStr != null) {
        if (roleStr.contains('manager')) {
          path = prefs.getString('config_org_path');
        } else if (roleStr.contains('supervisor')) {
          path = prefs.getString('sup_org_path');
        } else if (roleStr.contains('customer')) {
          path = prefs.getString('cust_org_path');
        }
      }
    }

    // Last resort fallbacks
    path ??=
        prefs.getString('org_dynamic_path') ??
        prefs.getString('config_org_path') ??
        prefs.getString('sup_org_path') ??
        prefs.getString('cust_org_path');

    _cachedDynamicPath = path;
    debugPrint(
      'FirestoreService: Initialized with OrgPath: $_cachedDynamicPath',
    );
  }

  /// Explicitly sets the organization path, bypassing SharedPreferences.
  /// Useful for immediate initialization during login or registration.
  static void setOrgPath(String path) {
    _cachedDynamicPath = path;
    // Persist to SharedPreferences so it's available after app restart
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('org_dynamic_path', path);
    });
  }

  /// Gets a collection that is nested under the organization's data root.
  /// Resulting Path: /organisation/{OrgID}/data/{collectionName}
  /// This method is synchronous to support UI StreamBuilders.
  static CollectionReference<Map<String, dynamic>> getCollection(
    String collectionName,
  ) {
    final orgId = _getOrgIdFromPath();

    debugPrint(
      'FirestoreService: Accessing collection "$collectionName" for OrgID: $orgId',
    );

    if (orgId == 'uninitialized') {
      // Fallback if not initialized or logged out
      return FirebaseFirestore.instance.collection(collectionName);
    }

    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection(collectionName);
  }

  /// Internal helper to extract OrgID robustly from cached path
  static String _getOrgIdFromPath() {
    if (_cachedDynamicPath == null || _cachedDynamicPath!.isEmpty) {
      debugPrint(
        'FirestoreService: Accessing org-specific data before login/initialization.',
      );
      return 'uninitialized';
    }
    String orgId = _cachedDynamicPath!;
    if (orgId.contains('/')) {
      final parts = orgId.split('/');
      if (parts[0] == 'organisation' && parts.length > 1) {
        return parts[1];
      }
      return parts[0];
    }
    return orgId;
  }

  /// Gets the current organization ID.
  static String get currentOrgId => _getOrgIdFromPath();

  /// Gets the root organization document (legacy location for branding/subscription).
  static DocumentReference<Map<String, dynamic>> get rootOrgDoc {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance.collection('organisation').doc(orgId);
  }

  /// Gets the organization's core data document.
  static DocumentReference<Map<String, dynamic>> get orgDataDoc {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc('admin');
  }

  static DocumentReference<Map<String, dynamic>> get brandingDoc {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc('branding');
  }

  /// Gets the branding configuration for a specific organization.
  static DocumentReference<Map<String, dynamic>> brandingDocWithId(
    String orgId,
  ) {
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc('branding');
  }

  /// Gets the organization's referral codes.
  static DocumentReference<Map<String, dynamic>> get referralDoc {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc('referralCode');
  }

  /// Gets the organization's subscription status.
  static DocumentReference<Map<String, dynamic>> get subscriptionDoc {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc('subscription');
  }

  /// Gets the collection of organization users for the current organization.
  static CollectionReference<Map<String, dynamic>> get organizationUsers {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('organizationUser');
  }

  /// Gets the collection of referral codes for the current organization.
  static CollectionReference<Map<String, dynamic>>
  get organizationReferralCodes {
    final orgId = _getOrgIdFromPath();
    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('referralCodes');
  }

  /// Gets a specific document reference inside an organization collection.
  static DocumentReference<Map<String, dynamic>> getDoc(
    String collectionName,
    String docId,
  ) {
    return getCollection(collectionName).doc(docId);
  }

  /// Runs a Firestore transaction.
  static Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return FirebaseFirestore.instance.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
    );
  }


  // Legacy async support wrappers
  static Future<DocumentReference<Map<String, dynamic>>>
  getOrgDataRoot() async {
    if (_cachedDynamicPath == null) await initialize();
    final orgId = _getOrgIdFromPath();
    if (orgId == 'uninitialized') {
      return FirebaseFirestore.instance
          .collection('organisation')
          .doc('uninitialized')
          .collection('admin')
          .doc('data');
    }

    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('data')
        .doc(
          'admin',
        ); // 'admin' is the document containing organization details
  }

  static Future<CollectionReference<Map<String, dynamic>>> getOrgCollection(
    String name,
  ) async {
    final root = await getOrgDataRoot();
    return root.collection(name);
  }

  // Common collection getters (Now synchronous)
  static CollectionReference<Map<String, dynamic>> get projects =>
      getCollection('projects');
  static CollectionReference<Map<String, dynamic>> get sites =>
      getCollection('Site');
  static CollectionReference<Map<String, dynamic>> get supervisors =>
      getCollection('supervisor');
  static CollectionReference<Map<String, dynamic>> get supervisorDesignation =>
      getCollection('supervisorDesignation');
  static CollectionReference<Map<String, dynamic>> get projectCategories =>
      getCollection('projectCategories');
  static CollectionReference<Map<String, dynamic>> get projectStatus =>
      getCollection('projectStatus');
  static CollectionReference<Map<String, dynamic>> get siteSupervisorMap =>
      getCollection('siteSupervisorMap');
  static CollectionReference<Map<String, dynamic>>
  get totalSiteExpensesPerDay => getCollection('totalSiteExpensesPerDay');
  static CollectionReference<Map<String, dynamic>> get labours =>
      getCollection('labours');
  static CollectionReference<Map<String, dynamic>> get materials =>
      getCollection('materials');
  static CollectionReference<Map<String, dynamic>> get contractors =>
      getCollection('contractors');
  static CollectionReference<Map<String, dynamic>> get materialCategories =>
      getCollection('materialCategories');
  static CollectionReference<Map<String, dynamic>> get materialUnits =>
      getCollection('materialUnits');
  static CollectionReference<Map<String, dynamic>> get materialSubCategories =>
      getCollection('materialSubCategories');
  static CollectionReference<Map<String, dynamic>> get projectSubCategories =>
      getCollection('projectSubCategories');
  static CollectionReference<Map<String, dynamic>> get configUsers =>
      getCollection('manager');

  // Additional business collections
  static CollectionReference<Map<String, dynamic>> get siteSupervisorEntries =>
      getCollection('siteSupervisorEntries');
  static CollectionReference<Map<String, dynamic>> get managerEntries =>
      getCollection('managerEntries');
  static CollectionReference<Map<String, dynamic>> get managerExpenses =>
      getCollection('managerExpenses');
  static CollectionReference<Map<String, dynamic>> get managerExpenseSummary =>
      getCollection('managerExpenseSummary');
  static CollectionReference<Map<String, dynamic>>
  get organizationExpenseSummary => getCollection('organizationExpenseSummary');
  static CollectionReference<Map<String, dynamic>> get organizationEntries =>
      getCollection('organizationEntries');
  static CollectionReference<Map<String, dynamic>> get contractorEntries =>
      getCollection('contractorEntries');
  static CollectionReference<Map<String, dynamic>>
  get siteSupervisorIncentives => getCollection('siteSupervisorIncentives');
  static CollectionReference<Map<String, dynamic>> get siteDrawings =>
      getCollection('siteDrawings');
  static CollectionReference<Map<String, dynamic>> get constructionDrawings =>
      getCollection('siteDrawings');
  static CollectionReference<Map<String, dynamic>> get siteMaterialsRequest =>
      getCollection('siteMaterialsRequest');
  static CollectionReference<Map<String, dynamic>> get projectStages =>
      getCollection('projectStages');
  static CollectionReference<Map<String, dynamic>> get siteSupervisorPayments =>
      getCollection('siteSupervisorPayments');
  static CollectionReference<Map<String, dynamic>>
  get siteSupervisorProjectStageSchedule =>
      getCollection('siteSupervisorProjectStageSchedule');
  static CollectionReference<Map<String, dynamic>>
  get siteSupervisorProjectStageActual =>
      getCollection('siteSupervisorProjectStageActual');

  // Universal Material Allocation & Consumption Collections
  static CollectionReference<Map<String, dynamic>>
  get siteMaterialAllocations => getCollection('siteMaterialAllocations');
  static CollectionReference<Map<String, dynamic>>
  get siteMaterialPool => getCollection('siteMaterialPool');
  static CollectionReference<Map<String, dynamic>>
  get materialTransactions => getCollection('materialTransactions');
  static CollectionReference<Map<String, dynamic>>
  get dailyMaterialConsumptions => getCollection('dailyMaterialConsumptions');

  /// Generates a unique 6-digit alphanumeric referral code.
  static Future<String> generateUniqueReferralCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String? code;
    bool isUnique = false;

    while (!isUnique) {
      code = List.generate(
        6,
        (index) => chars[random.nextInt(chars.length)],
      ).join();

      // Check if this code already exists in any /organisation/{id}/admin/referal document
      try {
        final isUniqueCode = await isReferralCodeUnique(code);
        if (isUniqueCode) {
          isUnique = true;
        }
      } catch (e) {
        debugPrint('Referral code check error: $e');
        rethrow;
      }
    }

    return code!;
  }

  /// Finds the Organization ID (document ID in /organisation collection) by search across
  /// all admin documents in the 'data' collection group for a matching referralCode
  /// strictly belonging to the CST application.
  static Future<String?> findOrgIdByReferralCode(String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('referralCode', isEqualTo: code)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final appId = (data['app_id'] ?? data['appId'] ?? '').toString();
        final orgDocId = doc.reference.parent.parent?.id ?? '';

        // Strictly verify that the document belongs to CST and ignore other applications (e.g., abc_academy_...)
        if (appId == cstAppId || isCstOrgId(orgDocId) || data['is_cst_app'] == true) {
          return orgDocId;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error searching referral code: $e');
      rethrow;
    }
  }

  /// Checks if a referral code is unique across all CST organizations.
  static Future<bool> isReferralCodeUnique(String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('referralCode', isEqualTo: code)
          .get();

      final cstMatches = snapshot.docs.where((doc) {
        final data = doc.data();
        final appId = (data['app_id'] ?? data['appId'] ?? '').toString();
        final orgDocId = doc.reference.parent.parent?.id ?? '';
        return appId == cstAppId || isCstOrgId(orgDocId) || data['is_cst_app'] == true;
      });

      return cstMatches.isEmpty;
    } catch (e) {
      debugPrint('Error checking referral code uniqueness: $e');
      rethrow;
    }
  }

  /// Checks if an organization name is unique across all CST organizations.
  static Future<bool> isOrgNameUnique(String orgName) async {
    final clean = orgName.trim();
    if (clean.isEmpty) return true;
    final cleanLower = clean.toLowerCase();
    final cleanNoSpace = cleanLower.replaceAll(' ', '');

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docOrgName = (data['org_name'] ?? data['orgName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final docOrgNoSpace = docOrgName.replaceAll(' ', '');
        final docId = doc.id.toLowerCase();

        if (docOrgName == cleanLower ||
            docOrgNoSpace == cleanNoSpace ||
            docId.startsWith('cst_${cleanNoSpace}_') ||
            docId == 'cst_$cleanNoSpace') {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('isOrgNameUnique error: $e');
      return true;
    }
  }

  /// Checks if an email is unique across all CST organizations.
  static Future<bool> isEmailUnique(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return true;

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docEmail =
            (data['email'] ?? '').toString().trim().toLowerCase();
        if (docEmail == clean) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('isEmailUnique error: $e');
      return true;
    }
  }

  /// Checks if a phone number is unique across all CST organizations.
  static Future<bool> isPhoneUnique(String phone) async {
    final clean = phone.trim();
    if (clean.isEmpty) return true;

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docPhone = (data['phone'] ??
                data['phoneNumber'] ??
                data['mobile'] ??
                '')
            .toString()
            .trim();
        if (docPhone == clean) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('isPhoneUnique error: $e');
      return true;
    }
  }

  /// Checks if a username is unique across all CST organizations.
  static Future<bool> isUsernameUnique(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return true;

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docUsername =
            (data['username'] ?? '').toString().trim().toLowerCase();
        if (docUsername == clean) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('isUsernameUnique error: $e');
      return true;
    }
  }

  /// Validates all 4 organization registration fields simultaneously.
  static Future<OrganizationValidationResult> validateOrganizationRegistration({
    required String orgName,
    required String email,
    required String phone,
    required String username,
  }) async {
    final cleanOrgName = orgName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanUsername = username.trim().toLowerCase();

    final results = await Future.wait([
      isOrgNameUnique(cleanOrgName),
      isEmailUnique(cleanEmail),
      isPhoneUnique(cleanPhone),
      isUsernameUnique(cleanUsername),
    ]);

    final bool isOrgNameUniqueVal = results[0];
    final bool isEmailUniqueVal = results[1];
    final bool isPhoneUniqueVal = results[2];
    final bool isUsernameUniqueVal = results[3];

    if (!isOrgNameUniqueVal ||
        !isEmailUniqueVal ||
        !isPhoneUniqueVal ||
        !isUsernameUniqueVal) {
      String errorMessage = '';
      if (!isOrgNameUniqueVal) {
        errorMessage =
            'Organization Name "$cleanOrgName" already exists. Please choose a different name.';
      } else if (!isEmailUniqueVal) {
        errorMessage =
            'Email Address "$cleanEmail" is already registered. Please use a different email or log in.';
      } else if (!isPhoneUniqueVal) {
        errorMessage =
            'Mobile Number "$cleanPhone" is already registered. Please use a different mobile number.';
      } else if (!isUsernameUniqueVal) {
        errorMessage =
            'Admin Username "$cleanUsername" is already taken. Please choose a different username.';
      }

      return OrganizationValidationResult(
        isValid: false,
        errorMessage: errorMessage,
        isOrgNameDuplicate: !isOrgNameUniqueVal,
        isEmailDuplicate: !isEmailUniqueVal,
        isPhoneDuplicate: !isPhoneUniqueVal,
        isUsernameDuplicate: !isUsernameUniqueVal,
      );
    }

    return const OrganizationValidationResult(isValid: true);
  }

  /// Persist initial organization registration details immediately into Firestore
  /// with dedicated CST namespace and strict application tagging.
  static Future<String> createPendingOrganizationRegistration({
    required String orgName,
    required String appName,
    required Color selectedColor,
    required String email,
    required String phone,
    required String username,
    required String password,
    required String dateStr,
  }) async {
    final cleanOrgName = orgName.replaceAll(' ', '');
    // Ensure all new CST organizations are prefixed with cst_ namespace
    final orgId = '$cstNamespacePrefix${cleanOrgName}_$dateStr';
    final orgConfigDocPath = 'organisation/$orgId';
    final themeHex =
        '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    final batch = FirebaseFirestore.instance.batch();

    // Generate unique referral code for organization
    String referralCode = '';
    try {
      referralCode = await generateUniqueReferralCode();
    } catch (_) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      referralCode = List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
    }

    final rootDocPayload = {
      'app_id': cstAppId,
      'app_type': cstAppId,
      'is_cst_app': true,
      'org_name': orgName,
      'app_name': appName,
      'theme_color': themeHex,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password,
      'role': 'Organization',
      'registrationStatus': 'COMPLETED',
      'onboardingStep': 'PAYMENT_PENDING',
      'isSubscriptionActive': false,
      'paymentStatus': 'PENDING',
      'referralCode': referralCode,
      'orgReferralCode': referralCode,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // 1. Root Org Document
    final rootRef = FirebaseFirestore.instance.doc(orgConfigDocPath);
    batch.set(rootRef, rootDocPayload, SetOptions(merge: true));

    // 2. Data / admin doc
    final dataAdminRef = rootRef.collection('data').doc('admin');
    batch.set(
      dataAdminRef,
      {
        'app_id': cstAppId,
        'app_type': cstAppId,
        'is_cst_app': true,
        'org_name': orgName,
        'app_name': appName,
        'theme_color': themeHex,
        'email': email,
        'phone': phone,
        'username': username,
        'password': password,
        'role': 'Organization',
        'registrationStatus': 'COMPLETED',
        'onboardingStep': 'PAYMENT_PENDING',
        'isSubscriptionActive': false,
        'paymentStatus': 'PENDING',
        'referralCode': referralCode,
        'orgReferralCode': referralCode,
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 3. Data / branding doc
    final dataBrandingRef = rootRef.collection('data').doc('branding');
    batch.set(
      dataBrandingRef,
      {
        'app_id': cstAppId,
        'is_cst_app': true,
        'appName': appName,
        'app_name': appName,
        'primaryColor': themeHex,
        'theme_color': themeHex,
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 4. Data / referralCode doc
    final dataReferralRef = rootRef.collection('data').doc('referralCode');
    batch.set(
      dataReferralRef,
      {
        'app_id': cstAppId,
        'is_cst_app': true,
        'referralCode': referralCode,
        'orgReferralCode': referralCode,
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 5. Initial Pending Subscription doc in data/subscription
    final initialSubData = {
      'app_id': cstAppId,
      'is_cst_app': true,
      'isSubscriptionActive': false,
      'paymentStatus': 'PENDING',
      'onboardingStep': 'PAYMENT_PENDING',
      'subscriptionPlan': 'Pending Selection',
      'subscriptionType': 'Pending',
      'created_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(
      rootRef.collection('data').doc('subscription'),
      initialSubData,
      SetOptions(merge: true),
    );

    // 6. Organization User doc (keyed uniquely by username)
    final userPayload = {
      'app_id': cstAppId,
      'is_cst_app': true,
      'org_name': orgName,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password,
      'role': 'Organization',
      'created_at': FieldValue.serverTimestamp(),
    };

    final userDocId = username.isNotEmpty ? username : (phone.isNotEmpty ? phone : 'admin');
    batch.set(
      rootRef.collection('organizationUser').doc(userDocId),
      userPayload,
      SetOptions(merge: true),
    );

    await batch.commit();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('referral_code', referralCode);
    } catch (_) {}

    return orgId;
  }
}
