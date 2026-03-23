import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static String? _cachedDynamicPath;

  /// Initializes the service by loading the dynamic path from SharedPreferences.
  /// Should be called after login or at app startup.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedDynamicPath = prefs.getString('org_dynamic_path') ??
                         prefs.getString('config_org_path') ??
                         prefs.getString('sup_org_path') ??
                         prefs.getString('cust_org_path');
  }

  /// Gets the root document reference for the current organization's data.
  /// Path: /{OrgName_Date}/data/
  static Future<DocumentReference> getOrgDataRoot() async {
    if (_cachedDynamicPath == null) {
      await initialize();
    }

    final dynamicPath = _cachedDynamicPath;
    if (dynamicPath == null || dynamicPath.isEmpty) {
      throw Exception('Organization not logged in or dynamic path missing');
    }

    // dynamicPath is "OrgName_Date/data/admin/User"
    // We need "OrgName_Date/data"
    final pathParts = dynamicPath.split('/');
    if (pathParts.length < 2) {
      throw Exception('Invalid dynamic path format: $dynamicPath');
    }

    final rootCollection = pathParts[0];
    return FirebaseFirestore.instance.collection(rootCollection).doc('data');
  }

  /// Gets a collection that is nested under the organization's data root.
  /// Resulting Path: /{OrgName_Date}/data/{collectionName}
  static Future<CollectionReference> getOrgCollection(
    String collectionName,
  ) async {
    final root = await getOrgDataRoot();
    return root.collection(collectionName);
  }

  // Common collection getters for easier refactoring
  static Future<CollectionReference> get projects =>
      getOrgCollection('projects');
  static Future<CollectionReference> get sites => getOrgCollection('Site');
  static Future<CollectionReference> get supervisors =>
      getOrgCollection('supervisor');
  static Future<CollectionReference> get supervisorDesignation =>
      getOrgCollection('supervisorDesignation');
  static Future<CollectionReference> get projectCategories =>
      getOrgCollection('projectCategories');
  static Future<CollectionReference> get projectStatus =>
      getOrgCollection('projectStatus');
  static Future<CollectionReference> get siteSupervisorMap =>
      getOrgCollection('siteSupervisorMap');
  static Future<CollectionReference> get totalSiteExpensesPerDay =>
      getOrgCollection('totalSiteExpensesPerDay');
  static Future<CollectionReference> get labours => getOrgCollection('labours');
  static Future<CollectionReference> get materials =>
      getOrgCollection('materials');
  static Future<CollectionReference> get contractors =>
      getOrgCollection('contractors');
  static Future<CollectionReference> get materialCategories =>
      getOrgCollection('materialCategories');
  static Future<CollectionReference> get materialUnits =>
      getOrgCollection('materialUnits');
  static Future<CollectionReference> get materialSubCategories =>
      getOrgCollection('materialSubCategories');
  static Future<CollectionReference> get projectSubCategories =>
      getOrgCollection('projectSubCategories');
  static Future<CollectionReference> get configUsers =>
      getOrgCollection('configUser');

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

      // Check if this code already exists in the central referralCodes collection
      final doc = await FirebaseFirestore.instance
          .collection('referralCodes')
          .doc(code)
          .get();

      if (!doc.exists) {
        isUnique = true;
      }
    }

    return code!;
  }
}
