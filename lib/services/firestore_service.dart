import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static String? _cachedDynamicPath;

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
        .doc('referral');
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
  /// all admin documents in the 'data' collection group for a matching referralCode.
  static Future<String?> findOrgIdByReferralCode(String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        // The structure is /organisation/{orgId}/data/admin
        // So doc.reference.parent is the 'data' collection, and .parent is the organization document
        return doc.reference.parent.parent?.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error searching referral code: $e');
      rethrow;
    }
  }

  /// Checks if a referral code is unique across all organizations.
  static Future<bool> isReferralCodeUnique(String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking referral code uniqueness: $e');
      rethrow;
    }
  }

  /// Checks if an email is unique across all organizations.
  static Future<bool> isEmailUnique(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking email uniqueness: $e');
      rethrow;
    }
  }

  /// Checks if a phone number is unique across all organizations.
  static Future<bool> isPhoneUnique(String phone) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking phone uniqueness: $e');
      rethrow;
    }
  }

  /// Checks if a username is unique across all organizations.
  static Future<bool> isUsernameUnique(String username) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('data')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username uniqueness: $e');
      rethrow;
    }
  }
}
