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

  /// Gets a collection that is nested under the organization's data root.
  /// Resulting Path: /organisation/{OrgID}/data/{collectionName}
  /// This method is synchronous to support UI StreamBuilders.
  static CollectionReference<Map<String, dynamic>> getCollection(String collectionName) {
    if (_cachedDynamicPath == null || _cachedDynamicPath!.isEmpty) {
      // Fallback if not initialized or logged out
      return FirebaseFirestore.instance.collection(collectionName);
    }
    
    // The _cachedDynamicPath will now be just the OrgID (e.g. Rooks_18-03-2026)
    // or the full legacy path which we handle for backward compatibility.
    final pathParts = _cachedDynamicPath!.split('/');
    final String orgId = pathParts[0];

    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection(collectionName); // Synchronous business collection access

  }

  /// Gets a specific document reference inside an organization collection.
  static DocumentReference<Map<String, dynamic>> getDoc(String collectionName, String docId) {
    return getCollection(collectionName).doc(docId);
  }

  // Legacy async support wrappers
  static Future<DocumentReference<Map<String, dynamic>>> getOrgDataRoot() async {
    if (_cachedDynamicPath == null) await initialize();
    if (_cachedDynamicPath == null || _cachedDynamicPath!.isEmpty) {
      throw Exception('Organization not logged in');
    }
    final pathParts = _cachedDynamicPath!.split('/');
    final String orgId = pathParts[0];

    return FirebaseFirestore.instance
        .collection('organisation')
        .doc(orgId)
        .collection('admin') // Using 'admin' as a parent collection for org-level metadata
        .doc('data'); // 'data' is the document containing organization details

  }

  static Future<CollectionReference<Map<String, dynamic>>> getOrgCollection(String name) async {
    final root = await getOrgDataRoot();
    return root.collection(name);
  }

  // Common collection getters (Now synchronous)
  static CollectionReference<Map<String, dynamic>> get projects => getCollection('projects');
  static CollectionReference<Map<String, dynamic>> get sites => getCollection('Site');
  static CollectionReference<Map<String, dynamic>> get supervisors => getCollection('supervisor');
  static CollectionReference<Map<String, dynamic>> get supervisorDesignation => getCollection('supervisorDesignation');
  static CollectionReference<Map<String, dynamic>> get projectCategories => getCollection('projectCategories');
  static CollectionReference<Map<String, dynamic>> get projectStatus => getCollection('projectStatus');
  static CollectionReference<Map<String, dynamic>> get siteSupervisorMap => getCollection('siteSupervisorMap');
  static CollectionReference<Map<String, dynamic>> get totalSiteExpensesPerDay => getCollection('totalSiteExpensesPerDay');
  static CollectionReference<Map<String, dynamic>> get labours => getCollection('labours');
  static CollectionReference<Map<String, dynamic>> get materials => getCollection('materials');
  static CollectionReference<Map<String, dynamic>> get contractors => getCollection('contractors');
  static CollectionReference<Map<String, dynamic>> get materialCategories => getCollection('materialCategories');
  static CollectionReference<Map<String, dynamic>> get materialUnits => getCollection('materialUnits');
  static CollectionReference<Map<String, dynamic>> get materialSubCategories => getCollection('materialSubCategories');
  static CollectionReference<Map<String, dynamic>> get projectSubCategories => getCollection('projectSubCategories');
  static CollectionReference<Map<String, dynamic>> get configUsers => getCollection('configUser');

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
