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
  static String? _cachedOrgId;
  static final Set<String> _migratedOrgs = {};

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
    _cachedOrgId = _computeOrgId(path);
    debugPrint(
      'FirestoreService: Initialized with OrgPath: $_cachedDynamicPath (OrgID: $_cachedOrgId)',
    );
    // Automatically trigger migration in background when org path is ready
    if (_cachedOrgId != null && _cachedOrgId != 'uninitialized' && !_migratedOrgs.contains(_cachedOrgId)) {
      Future.microtask(() => migrateSitesIntoProjects());
    }
  }

  /// Explicitly sets the organization path, bypassing SharedPreferences.
  /// Useful for immediate initialization during login or registration.
  static void setOrgPath(String path) {
    _cachedDynamicPath = path;
    _cachedOrgId = _computeOrgId(path);
    // Persist to SharedPreferences so it's available after app restart
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('org_dynamic_path', path);
    });
    // Trigger migration for the newly set organization if not already completed
    if (_cachedOrgId != null && _cachedOrgId != 'uninitialized' && !_migratedOrgs.contains(_cachedOrgId)) {
      Future.microtask(() => migrateSitesIntoProjects());
    }
  }

  /// Gets a collection that is nested under the organization's data root.
  /// Resulting Path: /organisation/{OrgID}/data/{collectionName}
  /// Note: 'Site' and 'sites' are automatically redirected to 'projects' as the single source of truth.
  /// This method is synchronous to support UI StreamBuilders.
  static CollectionReference<Map<String, dynamic>> getCollection(
    String collectionName,
  ) {
    final effectiveCollection = (collectionName == 'Site' || collectionName == 'sites')
        ? 'projects'
        : collectionName;

    final orgId = _getOrgIdFromPath();

    if (orgId == 'uninitialized') {
      // Fallback if not initialized or logged out
      return FirebaseFirestore.instance.collection(effectiveCollection);
    }

    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection(effectiveCollection);
  }

  /// Computes OrgID from a given path string
  static String _computeOrgId(String? path) {
    if (path == null || path.isEmpty) return 'uninitialized';
    if (path.contains('/')) {
      final parts = path.split('/');
      if (parts[0] == 'organisation' && parts.length > 1) {
        return parts[1];
      }
      return parts[0];
    }
    return path;
  }

  /// Internal helper to extract OrgID robustly from cached path
  static String _getOrgIdFromPath() {
    if (_cachedOrgId != null) return _cachedOrgId!;
    _cachedOrgId = _computeOrgId(_cachedDynamicPath);
    return _cachedOrgId!;
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
  static CollectionReference<Map<String, dynamic>> get materialsAvailability =>
      getCollection('materialsAvailability');
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

  // Universal Petty Cash Collections
  static CollectionReference<Map<String, dynamic>>
  get pettyCashAccounts => getCollection('pettyCashAccounts');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashRequests => getCollection('pettyCashRequests');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashTransactions => getCollection('pettyCashTransactions');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashExpenses => getCollection('pettyCashExpenses');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashReconciliations => getCollection('pettyCashReconciliations');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashReturns => getCollection('pettyCashReturns');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashIdempotency => getCollection('pettyCashIdempotency');
  static CollectionReference<Map<String, dynamic>>
  get sitePaymentClaims => getCollection('sitePaymentClaims');
  static CollectionReference<Map<String, dynamic>>
  get pettyCashAuditLogs => getCollection('pettyCashAuditLogs');

  // Universal Tools & Equipment Collections
  static CollectionReference<Map<String, dynamic>> get tools =>
      getCollection('tools');
  static CollectionReference<Map<String, dynamic>> get toolsAtCompany =>
      getCollection('toolsAtCompany');
  static CollectionReference<Map<String, dynamic>> get toolsAtSite =>
      getCollection('toolsAtSite');
  static CollectionReference<Map<String, dynamic>> get toolsInventory =>
      getCollection('toolsInventory');
  static CollectionReference<Map<String, dynamic>> get toolsMovement =>
      getCollection('toolsMovement');
  static CollectionReference<Map<String, dynamic>> get toolsReturn =>
      getCollection('toolsReturn');
  static CollectionReference<Map<String, dynamic>> get siteToolsRequest =>
      getCollection('siteToolsRequest');

  // Universal Workers & Attendance Collections
  static CollectionReference<Map<String, dynamic>> get workerSiteMapping =>
      getCollection('workerSiteMapping');
  static CollectionReference<Map<String, dynamic>> get workerSiteMap =>
      getCollection('workerSiteMap');
  static CollectionReference<Map<String, dynamic>> get workersAttendance =>
      getCollection('workersAttendance');
  static CollectionReference<Map<String, dynamic>> get workersConfig =>
      getCollection('workersConfig');

  // Universal Vehicles & Drivers Collections
  static CollectionReference<Map<String, dynamic>> get drivers =>
      getCollection('drivers');
  static CollectionReference<Map<String, dynamic>> get vehicleDetails =>
      getCollection('vehicleDetails');
  static CollectionReference<Map<String, dynamic>> get vehicleMovements =>
      getCollection('vehicleMovements');
  static CollectionReference<Map<String, dynamic>> get vehicleAssignments =>
      getCollection('vehicle_assignments');

  // Usage & Subscription Metrics Collections
  static CollectionReference<Map<String, dynamic>> get siteDrawingsUsage =>
      getCollection('siteDrawingsUsage');

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

  /// Checks if an email is unique globally across organisations, managers, supervisors, and users.
  static Future<bool> isGlobalEmailUnique(String email, {String? excludeDocId}) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return true;

    try {
      // 1. Check root organisation collection
      final orgSnap = await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in orgSnap.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final docEmail = (data['email'] ?? data['Email'] ?? '').toString().trim().toLowerCase();
        if (docEmail.isNotEmpty && docEmail == clean) return false;
      }

      // 2. Parallel collectionGroup lookups
      final futures = [
        FirebaseFirestore.instance.collectionGroup('manager').where('email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('Email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('Email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('Email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('Email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('configUsers').where('email', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('configUsers').where('Email', isEqualTo: clean).get(),
      ];

      final results = await Future.wait(futures);
      for (var snap in results) {
        for (var doc in snap.docs) {
          if (excludeDocId != null &&
              (doc.id == excludeDocId || doc.reference.parent.parent?.id == excludeDocId)) {
            continue;
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('isGlobalEmailUnique error: $e');
      return true;
    }
  }

  /// Checks if a phone number is unique globally across organisations, managers, supervisors, users, and customers.
  static Future<bool> isGlobalPhoneUnique(String phone, {String? excludeDocId}) async {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return true;

    try {
      // 1. Check root organisation collection
      final orgSnap = await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in orgSnap.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final docPhone = (data['phone'] ??
                data['phoneNumber'] ??
                data['mobile'] ??
                data['contactNo'] ??
                data['ContactNo'] ??
                '')
            .toString()
            .trim()
            .replaceAll(RegExp(r'\D'), '');
        if (docPhone.isNotEmpty && docPhone == clean) return false;
      }

      // 2. Parallel collectionGroup lookups
      final futures = [
        FirebaseFirestore.instance.collectionGroup('manager').where('ContactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('contactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('MobileNumber', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('ContactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('contactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('MobileNumber', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('ContactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('contactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('ContactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('contactNo', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('configUsers').where('MobileNumber', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('customers').where('ownerPhoneNumber', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('customers').where('phone', isEqualTo: clean).get(),
      ];

      final results = await Future.wait(futures);
      for (var snap in results) {
        for (var doc in snap.docs) {
          if (excludeDocId != null &&
              (doc.id == excludeDocId || doc.reference.parent.parent?.id == excludeDocId)) {
            continue;
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('isGlobalPhoneUnique error: $e');
      return true;
    }
  }

  /// Checks if a username is unique globally across organisations, organizationUsers, and managers.
  static Future<bool> isGlobalUsernameUnique(String username, {String? excludeDocId}) async {
    final clean = username.trim();
    if (clean.isEmpty) return true;
    final cleanLower = clean.toLowerCase();

    try {
      // 1. Check root organisation collection
      final orgSnap = await FirebaseFirestore.instance.collection('organisation').get();
      for (var doc in orgSnap.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final docUsername = (data['username'] ??
                data['UserName'] ??
                data['adminUsername'] ??
                data['admin_username'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        if (docUsername.isNotEmpty && (docUsername == cleanLower || docUsername == clean)) {
          return false;
        }
      }

      // 2. Parallel collectionGroup lookups
      final futures = [
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('username', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('username', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('organizationUser').where('UserName', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('UserName', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('username', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('UserName', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('manager').where('username', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('configUsers').where('UserName', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('configUsers').where('username', isEqualTo: clean).get(),
      ];

      final results = await Future.wait(futures);
      for (var snap in results) {
        for (var doc in snap.docs) {
          if (excludeDocId != null &&
              (doc.id == excludeDocId || doc.reference.parent.parent?.id == excludeDocId)) {
            continue;
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('isGlobalUsernameUnique error: $e');
      return true;
    }
  }

  /// Checks if a supervisor username is unique globally across supervisor accounts.
  static Future<bool> isGlobalSupervisorUsernameUnique(String username, {String? excludeDocId}) async {
    final clean = username.trim();
    if (clean.isEmpty) return true;
    final cleanLower = clean.toLowerCase();

    try {
      final futures = [
        FirebaseFirestore.instance.collectionGroup('supervisor').where('UserName', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('username', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('UserName', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('supervisor').where('username', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('UserName', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('username', isEqualTo: clean).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('UserName', isEqualTo: cleanLower).get(),
        FirebaseFirestore.instance.collectionGroup('supervisors').where('username', isEqualTo: cleanLower).get(),
      ];

      final results = await Future.wait(futures);
      for (var snap in results) {
        for (var doc in snap.docs) {
          if (excludeDocId != null &&
              (doc.id == excludeDocId || doc.reference.parent.parent?.id == excludeDocId)) {
            continue;
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('isGlobalSupervisorUsernameUnique error: $e');
      return true;
    }
  }

  /// Alias for backward compatibility
  static Future<bool> isEmailUnique(String email, {String? excludeDocId}) =>
      isGlobalEmailUnique(email, excludeDocId: excludeDocId);

  /// Alias for backward compatibility
  static Future<bool> isPhoneUnique(String phone, {String? excludeDocId}) =>
      isGlobalPhoneUnique(phone, excludeDocId: excludeDocId);

  /// Alias for backward compatibility
  static Future<bool> isUsernameUnique(String username, {String? excludeDocId}) =>
      isGlobalUsernameUnique(username, excludeDocId: excludeDocId);

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

  /// Resolves the exact linked project document reference for a given Site,
  /// accounting for various naming conventions, legacy composite IDs (e.g. ST001_AbineshHouse),
  /// site code, site name, and projectId mappings.
  static Future<DocumentSnapshot<Map<String, dynamic>>?> findLinkedProjectDoc({
    required String siteDocId,
    String? siteCode,
    String? siteName,
    String? projectId,
  }) async {
    try {
      final projectsCol = getCollection('projects');

      // 1. Direct projectId match
      if (projectId != null && projectId.trim().isNotEmpty) {
        final directProj = await projectsCol.doc(projectId.trim()).get();
        if (directProj.exists && directProj.data() != null) {
          return directProj;
        }
        final qProjId = await projectsCol.where('projectId', isEqualTo: projectId.trim()).limit(1).get();
        if (qProjId.docs.isNotEmpty) return qProjId.docs.first;
      }

      // 2. Direct siteDocId match
      if (siteDocId.trim().isNotEmpty) {
        final directSiteDoc = await projectsCol.doc(siteDocId.trim()).get();
        if (directSiteDoc.exists && directSiteDoc.data() != null) {
          return directSiteDoc;
        }

        final qSiteDocId = await projectsCol
            .where('siteId', isEqualTo: siteDocId.trim())
            .limit(1)
            .get();
        if (qSiteDocId.docs.isNotEmpty) {
          return qSiteDocId.docs.first;
        }
      }

      // 3. Check siteCode match (e.g., 'ST001')
      if (siteCode != null && siteCode.trim().isNotEmpty) {
        final qSiteCode = await projectsCol
            .where('siteId', isEqualTo: siteCode.trim())
            .limit(1)
            .get();
        if (qSiteCode.docs.isNotEmpty) {
          return qSiteCode.docs.first;
        }
      }

      // 4. Check composite key formats (e.g., 'ST001_AbineshHouse')
      final candidateCodes = <String>{
        if (siteCode != null && siteCode.trim().isNotEmpty) siteCode.trim(),
        if (siteDocId.trim().isNotEmpty) siteDocId.trim(),
      };
      final candidateNames = <String>{
        if (siteName != null && siteName.trim().isNotEmpty) siteName.trim(),
      };

      for (final code in candidateCodes) {
        for (final name in candidateNames) {
          final sanitizedName = name.replaceAll(' ', '');
          final comp1 = '${code}_$sanitizedName';
          final comp2 = '${code}_$name';

          final q1 = await projectsCol.where('siteId', isEqualTo: comp1).limit(1).get();
          if (q1.docs.isNotEmpty) return q1.docs.first;

          final q2 = await projectsCol.where('siteId', isEqualTo: comp2).limit(1).get();
          if (q2.docs.isNotEmpty) return q2.docs.first;

          final d1 = await projectsCol.doc(comp1).get();
          if (d1.exists && d1.data() != null) return d1;

          final d2 = await projectsCol.doc(comp2).get();
          if (d2.exists && d2.data() != null) return d2;
        }
      }

      // 5. Check siteName & projectName equality
      if (siteName != null && siteName.trim().isNotEmpty) {
        final qSiteName = await projectsCol
            .where('siteName', isEqualTo: siteName.trim())
            .limit(1)
            .get();
        if (qSiteName.docs.isNotEmpty) {
          return qSiteName.docs.first;
        }

        final qProjName = await projectsCol
            .where('projectName', isEqualTo: siteName.trim())
            .limit(1)
            .get();
        if (qProjName.docs.isNotEmpty) {
          return qProjName.docs.first;
        }
      }

      // 6. Broad scan fallback across all projects to catch prefix / substring matches
      final allProjects = await projectsCol.get();
      for (final doc in allProjects.docs) {
        final data = doc.data();
        final pSiteId = (data['siteId'] ?? '').toString().trim();
        final pSiteName = (data['siteName'] ?? '').toString().trim();
        final pProjName = (data['projectName'] ?? '').toString().trim();

        for (final code in candidateCodes) {
          if (pSiteId.startsWith('${code}_') ||
              pSiteId.startsWith(code) ||
              pSiteId == code ||
              doc.id.startsWith('${code}_') ||
              doc.id == code) {
            return doc;
          }
        }

        if (siteName != null && siteName.trim().isNotEmpty) {
          if (pSiteName.toLowerCase() == siteName.trim().toLowerCase() ||
              pProjName.toLowerCase() == siteName.trim().toLowerCase()) {
            return doc;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error finding linked project for site $siteDocId: $e');
      return null;
    }
  }

  /// Resolves the linked Site/Project document reference for a given identifier
  static Future<DocumentSnapshot<Map<String, dynamic>>?> findLinkedSiteDoc({
    required String projectDocId,
    String? siteId,
    String? siteName,
  }) async {
    return findLinkedProjectDoc(
      siteDocId: siteId ?? projectDocId,
      siteCode: siteId,
      siteName: siteName,
      projectId: projectDocId,
    );
  }

  /// Safely and atomically updates a Project/Site document in the single unified projects collection.
  static Future<void> syncSiteAndProject({
    required String siteDocId,
    String? siteCode,
    String? siteName,
    String? projectId,
    required Map<String, dynamic> siteUpdates,
    Map<String, dynamic>? projectExtraUpdates,
  }) async {
    final projectsCol = getCollection('projects');

    // 1. Locate the existing Project document
    final linkedProjectSnap = await findLinkedProjectDoc(
      siteDocId: siteDocId,
      siteCode: siteCode,
      siteName: siteName,
      projectId: projectId,
    );

    final targetDocRef = linkedProjectSnap != null
        ? linkedProjectSnap.reference
        : projectsCol.doc(projectId ?? siteDocId);

    // 2. Prepare combined updates
    final combinedUpdates = <String, dynamic>{
      'siteId': siteDocId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (siteCode != null && siteCode.isNotEmpty) {
      combinedUpdates['siteCode'] = siteCode;
    }
    if (siteName != null && siteName.isNotEmpty) {
      combinedUpdates['siteName'] = siteName;
    }

    // Apply siteUpdates
    combinedUpdates.addAll(siteUpdates);

    // Map any aliases
    if (siteUpdates.containsKey('status') && !combinedUpdates.containsKey('currentStatus')) {
      combinedUpdates['currentStatus'] = siteUpdates['status'];
    }
    if (siteUpdates.containsKey('currentStatus') && !combinedUpdates.containsKey('status')) {
      combinedUpdates['status'] = siteUpdates['currentStatus'];
    }
    if (siteUpdates.containsKey('amountPaid')) {
      combinedUpdates['amountReceived'] = siteUpdates['amountPaid'];
      combinedUpdates['receivedPayments'] = siteUpdates['amountPaid'];
    }
    if (siteUpdates.containsKey('amountSpent')) {
      combinedUpdates['amountSpend'] = siteUpdates['amountSpent'];
    }
    if (siteUpdates.containsKey('amountBalance')) {
      combinedUpdates['balance'] = siteUpdates['amountBalance'];
    }
    if (siteUpdates.containsKey('projectBudget')) {
      combinedUpdates['estimatedBudget'] = siteUpdates['projectBudget'];
    }
    if (siteUpdates.containsKey('projectContract')) {
      combinedUpdates['projectContractType'] = siteUpdates['projectContract'];
    }
    if (siteUpdates.containsKey('projectContractType') && !combinedUpdates.containsKey('projectContract')) {
      combinedUpdates['projectContract'] = siteUpdates['projectContractType'];
    }
    if (siteUpdates.containsKey('projectCategory')) {
      combinedUpdates['projectType'] = siteUpdates['projectCategory'];
    }
    if (siteUpdates.containsKey('ownerName')) {
      combinedUpdates['clientOwnerName'] = siteUpdates['ownerName'];
      combinedUpdates['clientName'] = siteUpdates['ownerName'];
    }
    if (siteUpdates.containsKey('clientOwnerName') && !combinedUpdates.containsKey('ownerName')) {
      combinedUpdates['ownerName'] = siteUpdates['clientOwnerName'];
      combinedUpdates['clientName'] = siteUpdates['clientOwnerName'];
    }
    if (siteUpdates.containsKey('ownerPhoneNumber')) {
      combinedUpdates['clientPhone'] = siteUpdates['ownerPhoneNumber'];
      combinedUpdates['clientPhoneNumber'] = siteUpdates['ownerPhoneNumber'];
    }
    if (siteUpdates.containsKey('clientPhone') && !combinedUpdates.containsKey('ownerPhoneNumber')) {
      combinedUpdates['ownerPhoneNumber'] = siteUpdates['clientPhone'];
      combinedUpdates['clientPhoneNumber'] = siteUpdates['clientPhone'];
    }
    if (siteUpdates.containsKey('actualStartDate')) {
      combinedUpdates['actualStateDate'] = siteUpdates['actualStartDate'];
    }
    if (siteUpdates.containsKey('actualStateDate') && !combinedUpdates.containsKey('actualStartDate')) {
      combinedUpdates['actualStartDate'] = siteUpdates['actualStateDate'];
    }
    if (siteUpdates.containsKey('startDate') && !combinedUpdates.containsKey('plannedStartDate')) {
      combinedUpdates['plannedStartDate'] = siteUpdates['startDate'];
    }
    if (siteUpdates.containsKey('plannedStartDate') && !combinedUpdates.containsKey('startDate')) {
      combinedUpdates['startDate'] = siteUpdates['plannedStartDate'];
    }
    if (siteUpdates.containsKey('endDate') && !combinedUpdates.containsKey('plannedEndDate')) {
      combinedUpdates['plannedEndDate'] = siteUpdates['endDate'];
    }
    if (siteUpdates.containsKey('plannedEndDate') && !combinedUpdates.containsKey('endDate')) {
      combinedUpdates['endDate'] = siteUpdates['plannedEndDate'];
    }

    if (projectExtraUpdates != null) {
      combinedUpdates.addAll(projectExtraUpdates);
    }

    await targetDocRef.set(combinedUpdates, SetOptions(merge: true));
  }

  /// Migrates legacy raw 'Site' documents into the unified 'projects' collection.
  /// Runs safely and idempotently without overwriting valid data.
  static Future<void> migrateSitesIntoProjects() async {
    try {
      final orgId = _getOrgIdFromPath();
      if (orgId == 'uninitialized') return;
      if (_migratedOrgs.contains(orgId)) return;
      _migratedOrgs.add(orgId);

      // Access raw 'Site' subcollection directly (bypassing getCollection redirection)
      final rawSiteCol = FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
          .collection('Site');

      final siteSnap = await rawSiteCol.get();
      if (siteSnap.docs.isEmpty) {
        debugPrint('FirestoreService: No legacy Site documents found to migrate for org: $orgId');
        return;
      }

      final projectsCol = getCollection('projects');
      final existingProjectsSnap = await projectsCol.get();
      final existingProjectDocs = existingProjectsSnap.docs;

      debugPrint('FirestoreService: Migrating ${siteSnap.docs.length} legacy Site documents into projects...');

      for (final siteDoc in siteSnap.docs) {
        final sData = siteDoc.data();
        final sDocId = siteDoc.id;
        final sSiteId = (sData['siteId'] ?? sDocId).toString().trim();
        final sSiteName = (sData['siteName'] ?? sData['name'] ?? '').toString().trim();
        final sProjId = (sData['projectId'] ?? '').toString().trim();

        // Search for matching project document
        QueryDocumentSnapshot<Map<String, dynamic>>? matchedProj;
        for (final pDoc in existingProjectDocs) {
          final pData = pDoc.data();
          final pSiteId = (pData['siteId'] ?? '').toString().trim();
          final pProjIdField = (pData['projectId'] ?? '').toString().trim();
          final pName = (pData['projectName'] ?? pData['siteName'] ?? '').toString().trim();

          if (pDoc.id == sDocId ||
              pDoc.id == sProjId ||
              (sProjId.isNotEmpty && (pDoc.id == sProjId || pProjIdField == sProjId)) ||
              (sSiteId.isNotEmpty && (pDoc.id == sSiteId || pSiteId == sSiteId || pSiteId.startsWith('${sSiteId}_'))) ||
              (sSiteName.isNotEmpty && pName.toLowerCase() == sSiteName.toLowerCase())) {
            matchedProj = pDoc;
            break;
          }
        }

        if (matchedProj != null) {
          // Merge missing/site fields into existing project doc
          final pData = matchedProj.data();
          final mergeUpdates = <String, dynamic>{
            'siteId': pData['siteId'] ?? sSiteId,
            'siteName': pData['siteName'] ?? sSiteName,
            'siteLocation': pData['siteLocation'] ?? sData['location'] ?? sData['siteLocation'] ?? '',
            'latitude': pData['latitude'] ?? sData['latitude'],
            'longitude': pData['longitude'] ?? sData['longitude'],
            'projectCategory': pData['projectCategory'] ?? sData['projectCategory'] ?? '',
            'status': pData['status'] ?? sData['status'] ?? pData['currentStatus'] ?? 'Planning',
            'currentStatus': pData['currentStatus'] ?? sData['status'] ?? sData['status'] ?? 'Planning',
            'startDate': pData['startDate'] ?? sData['startDate'] ?? pData['plannedStartDate'],
            'endDate': pData['endDate'] ?? sData['endDate'] ?? pData['plannedEndDate'],
            'plannedStartDate': pData['plannedStartDate'] ?? sData['startDate'] ?? pData['plannedStartDate'],
            'plannedEndDate': pData['plannedEndDate'] ?? sData['endDate'] ?? pData['plannedEndDate'],
            'actualStartDate': pData['actualStartDate'] ?? sData['actualStartDate'] ?? sData['actualStateDate'],
            'actualStateDate': pData['actualStateDate'] ?? sData['actualStartDate'] ?? sData['actualStateDate'],
            'actualEndDate': pData['actualEndDate'] ?? sData['actualEndDate'],
            'projectBudget': pData['projectBudget'] ?? sData['projectBudget'] ?? 0,
            'amountReceived': pData['amountReceived'] ?? sData['amountReceived'] ?? sData['amountPaid'] ?? 0,
            'amountPaid': pData['amountPaid'] ?? sData['amountPaid'] ?? sData['amountReceived'] ?? 0,
            'amountSpent': pData['amountSpent'] ?? sData['amountSpent'] ?? sData['amountSpend'] ?? 0,
            'amountSpend': pData['amountSpend'] ?? sData['amountSpend'] ?? sData['amountSpent'] ?? 0,
            'amountBalance': pData['amountBalance'] ?? sData['amountBalance'] ?? 0,
            'receivedPayments': pData['receivedPayments'] ?? sData['receivedPayments'] ?? sData['amountReceived'] ?? sData['amountPaid'] ?? 0,
            'isContractWork': pData['isContractWork'] ?? sData['isContractWork'] ?? false,
            'contractorName': pData['contractorName'] ?? sData['contractorName'] ?? '',
            'contractorBudget': pData['contractorBudget'] ?? sData['contractorBudget'] ?? 0,
            'contractStartDate': pData['contractStartDate'] ?? sData['contractStartDate'],
            'contractEndDate': pData['contractEndDate'] ?? sData['contractEndDate'],
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await matchedProj.reference.set(mergeUpdates, SetOptions(merge: true));

          // If the matched project is PR001_ST001_..., delete any duplicate non-PR doc in projects collection
          if (matchedProj.id != sDocId && !sDocId.startsWith('PR')) {
            try {
              final dupDoc = await projectsCol.doc(sDocId).get();
              if (dupDoc.exists) {
                await projectsCol.doc(sDocId).delete();
                debugPrint('FirestoreService: Deleted duplicate legacy project doc $sDocId');
              }
            } catch (_) {}
          }
        } else {
          // Create new project document for this site using format PR001_ST001_<ProjectName>
          final nextPrCode = await getNextProjectCode();
          final cleanSiteCode = sSiteId.split('_').first.replaceAll(' ', '');
          final cleanSiteName = sSiteName.isNotEmpty ? sSiteName.replaceAll(' ', '') : sDocId.replaceAll(' ', '');
          final targetDocId = formatProjectDocId(
            projectCode: nextPrCode,
            siteCode: cleanSiteCode,
            siteName: cleanSiteName,
          );

          final newProjectData = <String, dynamic>{
            'projectId': targetDocId,
            'projectCode': nextPrCode,
            'projectName': sSiteName.isNotEmpty ? sSiteName : sDocId,
            'siteId': sDocId,
            'siteCode': cleanSiteCode,
            'siteName': sSiteName,
            'siteLocation': sData['location'] ?? sData['siteLocation'] ?? '',
            'latitude': sData['latitude'],
            'longitude': sData['longitude'],
            'projectCategory': sData['projectCategory'] ?? '',
            'projectSubCategory': sData['projectSubCategory'] ?? '',
            'projectType': sData['projectType'] ?? '',
            'projectContract': sData['projectContract'] ?? '',
            'projectStage': sData['projectStage'] ?? '',
            'currentStatus': sData['status'] ?? sData['currentStatus'] ?? 'Planning',
            'status': sData['status'] ?? sData['currentStatus'] ?? 'Planning',
            'ownerName': sData['ownerName'] ?? sData['clientName'] ?? '',
            'ownerPhoneNumber': sData['ownerPhoneNumber'] ?? sData['clientPhone'] ?? '',
            'plannedStartDate': sData['startDate'] ?? sData['plannedStartDate'] ?? Timestamp.now(),
            'plannedEndDate': sData['endDate'] ?? sData['plannedEndDate'],
            'startDate': sData['startDate'] ?? sData['plannedStartDate'],
            'endDate': sData['endDate'] ?? sData['plannedEndDate'],
            'actualStartDate': sData['actualStartDate'] ?? sData['actualStateDate'],
            'actualStateDate': sData['actualStartDate'] ?? sData['actualStateDate'],
            'actualEndDate': sData['actualEndDate'],
            'projectBudget': sData['projectBudget'] ?? 0,
            'isContractWork': sData['isContractWork'] ?? false,
            'contractorName': sData['contractorName'] ?? '',
            'contractorBudget': sData['contractorBudget'] ?? 0,
            'contractStartDate': sData['contractStartDate'],
            'contractEndDate': sData['contractEndDate'],
            'amountReceived': sData['amountReceived'] ?? sData['amountPaid'] ?? 0,
            'amountPaid': sData['amountPaid'] ?? sData['amountReceived'] ?? 0,
            'amountSpent': sData['amountSpent'] ?? sData['amountSpend'] ?? 0,
            'amountSpend': sData['amountSpend'] ?? sData['amountSpent'] ?? 0,
            'amountBalance': sData['amountBalance'] ?? 0,
            'receivedPayments': sData['receivedPayments'] ?? sData['amountReceived'] ?? sData['amountPaid'] ?? 0,
            'createdAt': sData['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await projectsCol.doc(targetDocId).set(newProjectData, SetOptions(merge: true));

          // Clean up legacy sDocId if it was in projects collection
          if (sDocId != targetDocId && !sDocId.startsWith('PR')) {
            try {
              final dupDoc = await projectsCol.doc(sDocId).get();
              if (dupDoc.exists) {
                await projectsCol.doc(sDocId).delete();
              }
            } catch (_) {}
          }
        }
      }
      debugPrint('FirestoreService: Successfully finished migrating Site documents into projects.');
    } catch (e) {
      debugPrint('FirestoreService: Error during migrateSitesIntoProjects: $e');
    }
  }

  /// Formats deterministic project document ID: `PR001_{SiteID}_{SiteName}`
  static String formatProjectDocId({
    required String projectCode,
    required String siteCode,
    required String siteName,
  }) {
    final cleanSiteCode = siteCode.replaceAll(' ', '');
    final cleanSiteName = siteName.replaceAll(' ', '');
    return '${projectCode}_${cleanSiteCode}_$cleanSiteName';
  }

  /// Finds the next available sequential project code (e.g., PR001, PR002)
  static Future<String> getNextProjectCode() async {
    try {
      final projectsCol = getCollection('projects');
      final snap = await projectsCol.get();
      int highestSeq = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final pCode = (data['projectCode'] ?? '').toString();
        final docId = doc.id;

        final prMatch = RegExp(r'^PR(\d+)').firstMatch(pCode.isNotEmpty ? pCode : docId);
        if (prMatch != null) {
          final numVal = int.tryParse(prMatch.group(1) ?? '0') ?? 0;
          if (numVal > highestSeq) {
            highestSeq = numVal;
          }
        }
      }

      final nextNum = highestSeq + 1;
      return 'PR${nextNum.toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error getting next project code: $e');
      return 'PR001';
    }
  }

  /// Locates an existing project for a given site by siteId, siteCode, siteName, or location
  static Future<DocumentSnapshot<Map<String, dynamic>>?> findExistingProjectForSite({
    required String siteId,
    required String siteName,
    String? siteLocation,
  }) async {
    final projectsCol = getCollection('projects');
    final cleanSiteId = siteId.trim();
    String cleanSiteCode = cleanSiteId;
    if (cleanSiteCode.contains('_')) {
      cleanSiteCode = cleanSiteCode.split('_').first;
    }
    final cleanSiteName = siteName.trim().toLowerCase();
    final cleanLocation = (siteLocation ?? '').trim().toLowerCase();

    final allProjects = await projectsCol.get();
    for (final doc in allProjects.docs) {
      final data = doc.data();
      final docSiteId = (data['siteId'] ?? '').toString().trim();
      final docSiteCode = (data['siteCode'] ?? '').toString().trim();
      final docSiteName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim().toLowerCase();
      final docLocation = (data['siteLocation'] ?? data['location'] ?? '').toString().trim().toLowerCase();

      if (cleanSiteId.isNotEmpty &&
          (doc.id == cleanSiteId ||
              doc.id.contains('_${cleanSiteId}_') ||
              doc.id.endsWith('_$cleanSiteId') ||
              doc.id.contains('_${cleanSiteCode}_') ||
              doc.id.endsWith('_$cleanSiteCode') ||
              docSiteId == cleanSiteId ||
              docSiteId == cleanSiteCode ||
              docSiteCode == cleanSiteCode)) {
        return doc;
      }

      if (cleanSiteName.isNotEmpty &&
          docSiteName == cleanSiteName &&
          (cleanLocation.isEmpty || docLocation == cleanLocation)) {
        return doc;
      }
    }
    return null;
  }

  /// Deterministically creates or reuses a single project document for a site in `organisation/{orgId}/projects/{docId}`
  /// using format: `PR001_{SiteID}_{SiteName}` (e.g. `PR001_ST001_Testing`).
  /// Enforces database-level uniqueness via Firestore transactions and atomic checks to prevent duplicate records.
  static Future<ProjectCreationResult> createProjectDocumentAtomic({
    required String siteId,
    required String siteName,
    String? siteLocation,
    required Map<String, dynamic> projectData,
  }) async {
    try {
      final projectsCol = getCollection('projects');

      final cleanSiteId = siteId.trim();
      String cleanSiteCode = cleanSiteId;
      if (cleanSiteCode.contains('_')) {
        cleanSiteCode = cleanSiteCode.split('_').first;
      }
      final cleanSiteName = siteName.trim();
      final cleanLocation = (siteLocation ?? '').trim();

      // 1. Check if an existing project already matches this site/project
      final existingDoc = await findExistingProjectForSite(
        siteId: siteId,
        siteName: siteName,
        siteLocation: siteLocation,
      );

      String canonicalDocId;
      String pCode;

      if (existingDoc != null && existingDoc.id.startsWith('PR')) {
        canonicalDocId = existingDoc.id;
        final data = existingDoc.data() ?? {};
        pCode = (data['projectCode'] ?? (RegExp(r'^PR\d+').firstMatch(canonicalDocId)?.group(0)) ?? 'PR001').toString();
      } else {
        final nextPrCode = await getNextProjectCode();
        pCode = nextPrCode;
        canonicalDocId = formatProjectDocId(
          projectCode: nextPrCode,
          siteCode: cleanSiteCode,
          siteName: cleanSiteName,
        );
      }

      final targetDocRef = projectsCol.doc(canonicalDocId);

      // Prepare final normalized data
      final finalData = Map<String, dynamic>.from(projectData);
      finalData['projectId'] = canonicalDocId;
      finalData['projectCode'] = pCode;
      finalData['siteId'] = cleanSiteId;
      finalData['siteCode'] = cleanSiteCode;
      finalData['siteName'] = cleanSiteName;
      finalData['projectName'] = (finalData['projectName'] ?? cleanSiteName).toString().trim();
      if (cleanLocation.isNotEmpty) {
        finalData['siteLocation'] = cleanLocation;
        finalData['location'] = cleanLocation;
      }

      // Comprehensive alias & contract mapping
      if (finalData.containsKey('projectCategory')) {
        finalData['projectType'] = finalData['projectCategory'];
      }
      if (finalData.containsKey('projectContract')) {
        finalData['projectContractType'] = finalData['projectContract'];
      }
      if (finalData.containsKey('projectContractType') && !finalData.containsKey('projectContract')) {
        finalData['projectContract'] = finalData['projectContractType'];
      }
      if (finalData.containsKey('ownerName')) {
        finalData['clientOwnerName'] = finalData['ownerName'];
        finalData['clientName'] = finalData['ownerName'];
      }
      if (finalData.containsKey('clientOwnerName') && !finalData.containsKey('ownerName')) {
        finalData['ownerName'] = finalData['clientOwnerName'];
        finalData['clientName'] = finalData['clientOwnerName'];
      }
      if (finalData.containsKey('ownerPhoneNumber')) {
        finalData['clientPhone'] = finalData['ownerPhoneNumber'];
        finalData['clientPhoneNumber'] = finalData['ownerPhoneNumber'];
      }
      if (finalData.containsKey('clientPhone') && !finalData.containsKey('ownerPhoneNumber')) {
        finalData['ownerPhoneNumber'] = finalData['clientPhone'];
      }
      if (finalData.containsKey('projectBudget')) {
        finalData['estimatedBudget'] = finalData['projectBudget'];
      }
      if (finalData.containsKey('estimatedBudget') && !finalData.containsKey('projectBudget')) {
        finalData['projectBudget'] = finalData['estimatedBudget'];
      }
      if (finalData.containsKey('amountPaid')) {
        finalData['amountReceived'] = finalData['amountPaid'];
        finalData['receivedPayments'] = finalData['amountPaid'];
      }
      if (finalData.containsKey('amountReceived')) {
        finalData['amountPaid'] = finalData['amountReceived'];
        finalData['receivedPayments'] = finalData['amountReceived'];
      }
      if (finalData.containsKey('amountSpent')) {
        finalData['amountSpend'] = finalData['amountSpent'];
      }
      if (finalData.containsKey('amountSpend') && !finalData.containsKey('amountSpent')) {
        finalData['amountSpent'] = finalData['amountSpend'];
      }
      if (finalData.containsKey('amountBalance')) {
        finalData['balance'] = finalData['amountBalance'];
      }
      if (finalData.containsKey('balance') && !finalData.containsKey('amountBalance')) {
        finalData['amountBalance'] = finalData['balance'];
      }
      if (finalData.containsKey('actualStartDate') && !finalData.containsKey('actualStateDate')) {
        finalData['actualStateDate'] = finalData['actualStartDate'];
      }
      if (finalData.containsKey('actualStateDate') && !finalData.containsKey('actualStartDate')) {
        finalData['actualStartDate'] = finalData['actualStateDate'];
      }
      if (finalData.containsKey('plannedStartDate') && !finalData.containsKey('startDate')) {
        finalData['startDate'] = finalData['plannedStartDate'];
      }
      if (finalData.containsKey('startDate') && !finalData.containsKey('plannedStartDate')) {
        finalData['plannedStartDate'] = finalData['startDate'];
      }
      if (finalData.containsKey('plannedEndDate') && !finalData.containsKey('endDate')) {
        finalData['endDate'] = finalData['plannedEndDate'];
      }
      if (finalData.containsKey('endDate') && !finalData.containsKey('plannedEndDate')) {
        finalData['plannedEndDate'] = finalData['endDate'];
      }
      if (finalData.containsKey('status') && !finalData.containsKey('currentStatus')) {
        finalData['currentStatus'] = finalData['status'];
      }
      if (finalData.containsKey('currentStatus') && !finalData.containsKey('status')) {
        finalData['status'] = finalData['currentStatus'];
      }

      finalData['updatedAt'] = FieldValue.serverTimestamp();
      if (!finalData.containsKey('createdAt') || finalData['createdAt'] == null) {
        finalData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Exclusively save the project into the canonical document
      await targetDocRef.set(finalData, SetOptions(merge: true));

      // Clean up any legacy non-PR duplicate documents (e.g., ST001_Testing or cleanSiteId) in projects collection
      final legacyDocId = '${cleanSiteCode}_${cleanSiteName.replaceAll(' ', '')}';
      if (legacyDocId != canonicalDocId) {
        try {
          final legDoc = await projectsCol.doc(legacyDocId).get();
          if (legDoc.exists) {
            await projectsCol.doc(legacyDocId).delete();
            debugPrint('FirestoreService: Cleaned up duplicate legacy project doc $legacyDocId in favor of $canonicalDocId');
          }
        } catch (e) {
          debugPrint('FirestoreService: Note cleaning duplicate legacy project doc: $e');
        }
      }
      if (cleanSiteId != canonicalDocId && cleanSiteId != legacyDocId && !cleanSiteId.startsWith('PR')) {
        try {
          final legDoc2 = await projectsCol.doc(cleanSiteId).get();
          if (legDoc2.exists) {
            await projectsCol.doc(cleanSiteId).delete();
            debugPrint('FirestoreService: Cleaned up duplicate legacy project doc $cleanSiteId in favor of $canonicalDocId');
          }
        } catch (_) {}
      }
      if (existingDoc != null && existingDoc.id != canonicalDocId && !existingDoc.id.startsWith('PR')) {
        try {
          await existingDoc.reference.delete();
          debugPrint('FirestoreService: Deleted duplicate legacy project doc ${existingDoc.id} in favor of $canonicalDocId');
        } catch (_) {}
      }

      return ProjectCreationResult(
        isCreated: existingDoc == null,
        isDuplicate: existingDoc != null,
        projectDocId: canonicalDocId,
        projectCode: pCode,
        projectData: finalData,
        message: 'Project stored exclusively under canonical ID $canonicalDocId.',
      );
    } catch (e) {
      debugPrint('FirestoreService: Error creating project atomically: $e');
      rethrow;
    }
  }
}

class ProjectCreationResult {
  final bool isCreated;
  final bool isDuplicate;
  final String projectDocId;
  final String projectCode;
  final Map<String, dynamic> projectData;
  final String message;

  ProjectCreationResult({
    required this.isCreated,
    required this.isDuplicate,
    required this.projectDocId,
    required this.projectCode,
    required this.projectData,
    required this.message,
  });
}
