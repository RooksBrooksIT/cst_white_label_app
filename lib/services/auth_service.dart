import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import 'firestore_service.dart';

enum UserRole { organization, manager, supervisor, customer, none }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static late SharedPreferences _prefs;

  // Keys
  static const String _isLoggedInKey = 'auth_is_logged_in';
  static const String _userRoleKey = 'auth_user_role';
  static const String _userDataKey = 'auth_user_data';

  /// Initialize SharedPreferences
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if any user is logged in
  bool get isLoggedIn => _prefs.getBool(_isLoggedInKey) ?? false;

  /// Get the current user's role
  UserRole get userRole {
    final roleStr = _prefs.getString(_userRoleKey);
    if (roleStr == null) return UserRole.none;
    return UserRole.values.firstWhere(
      (e) => e.toString() == roleStr,
      orElse: () => UserRole.none,
    );
  }

  /// Get stored user data as a Map
  Map<String, dynamic> get userData {
    final dataStr = _prefs.getString(_userDataKey);
    if (dataStr == null) return {};
    try {
      return jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error decoding user data: $e');
      return {};
    }
  }

  /// Check if the current organization's subscription is active and not expired.
  Future<bool> checkSubscriptionStatus() async {
    final role = userRole;
    if (role != UserRole.organization) return true; // Only enforce for organizations

    try {
      var doc = await FirestoreService.subscriptionDoc.get();

      // Fallback: If admin/subscription doc doesn't exist, check root doc (legacy)
      if (!doc.exists) {
        debugPrint('AuthService: Subscription doc not found in admin, falling back to root.');
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (!doc.exists) return false;

      final data = doc.data()!;
      // Default to true if fields are missing to avoid locking out valid users
      // during transitions or if initialization hasn't finished.
      final isActive = data['isSubscriptionActive'] as bool? ?? true;
      final endDate = data['subscriptionEndDate'] as Timestamp?;

      if (!isActive) return false;
      if (endDate == null) return true; // Assume lifetime/trial if no end date

      return endDate.toDate().isAfter(DateTime.now());
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      return true; // Default to true to avoid locking users out on network issues
    }
  }

  /// Mark a user as logged in with a role and data
  Future<void> login(UserRole role, Map<String, dynamic> data) async {
    await _prefs.setBool(_isLoggedInKey, true);
    await _prefs.setString(_userRoleKey, role.toString());
    await _prefs.setString(_userDataKey, jsonEncode(data));

    // For backward compatibility and specialized logic in existing services,
    // we also set the specific keys they expect.
    await _syncLegacyKeys(role, data);

    // Automatically refresh branding if orgId is available
    final orgId = data['dynamicPath'] ?? data['orgId'];
    if (orgId != null && orgId.toString().isNotEmpty) {
      await refreshBranding(orgId.toString());
    }
  }

  /// Fetch and apply organization branding from Firestore
  Future<void> refreshBranding(String orgId) async {
    try {
      var doc = await FirestoreService.brandingDocWithId(orgId).get();

      // Fallback: If admin/branding doc doesn't exist, check root doc (legacy)
      if (!doc.exists) {
        debugPrint('AuthService: Branding doc not found in admin, falling back to root.');
        doc = await FirebaseFirestore.instance.collection('organisation').doc(orgId).get();
      }

      if (doc.exists) {
        final data = doc.data()!;
        final appName = data['appName'] as String?;
        final primaryColorHex = data['primaryColor'] as String?;

        if (appName != null && appName.isNotEmpty) {
          await AppTheme.updateAppName(appName);
        }
        if (primaryColorHex != null && primaryColorHex.isNotEmpty) {
          final color = AppTheme.hexToColor(primaryColorHex);
          await AppTheme.updateTheme(color);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing branding for $orgId: $e');
    }
  }

  /// Update parts of the stored user data
  Future<void> updateUserData(Map<String, dynamic> newData) async {
    final currentRole = userRole;
    if (currentRole == UserRole.none) return;

    final currentData = userData;
    currentData.addAll(newData);
    await _prefs.setString(_userDataKey, jsonEncode(currentData));

    // Sync to legacy keys
    await _syncLegacyKeys(currentRole, currentData);
  }

  /// Log out and clear all session data
  Future<void> logout() async {
    // Clear our unified keys
    await _prefs.remove(_isLoggedInKey);
    await _prefs.remove(_userRoleKey);
    await _prefs.remove(_userDataKey);

    // Clear all legacy keys to be safe
    final keys = _prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('org_') ||
          key.startsWith('config_') ||
          key.startsWith('sup_') ||
          key.startsWith('cust_')) {
        await _prefs.remove(key);
      }
    }
  }

  /// Sync unified data back to the legacy keys for existing app logic
  Future<void> _syncLegacyKeys(UserRole role, Map<String, dynamic> data) async {
    switch (role) {
      case UserRole.organization:
        await _prefs.setBool('org_isLoggedIn', true);
        if (data.containsKey('username'))
          await _prefs.setString('org_username', data['username']);
        if (data.containsKey('dynamicPath'))
          await _prefs.setString('org_dynamic_path', data['dynamicPath']);
        if (data.containsKey('org_name'))
          await _prefs.setString('org_name', data['org_name']);
        if (data.containsKey('org_doc_path'))
          await _prefs.setString('org_doc_path', data['org_doc_path']);
        break;
      case UserRole.manager:
        await _prefs.setBool('config_is_logged_in', true);
        if (data.containsKey('username'))
          await _prefs.setString('config_username', data['username']);
        if (data.containsKey('password'))
          await _prefs.setString('config_password', data['password']);
        if (data.containsKey('orgId'))
          await _prefs.setString('config_org_path', data['orgId']);
        if (data.containsKey('config_org_doc_path'))
          await _prefs.setString(
            'config_org_doc_path',
            data['config_org_doc_path'],
          );
        break;
      case UserRole.supervisor:
        await _prefs.setBool('sup_isLoggedIn', true);
        if (data.containsKey('username'))
          await _prefs.setString('sup_username', data['username']);
        if (data.containsKey('supervisorId'))
          await _prefs.setString('sup_supervisorId', data['supervisorId']);
        if (data.containsKey('supervisorName'))
          await _prefs.setString('sup_supervisorName', data['supervisorName']);
        if (data.containsKey('isContractor'))
          await _prefs.setBool('sup_isContractor', data['isContractor']);
        if (data.containsKey('userType'))
          await _prefs.setString('sup_userType', data['userType']);
        if (data.containsKey('contractorName'))
          await _prefs.setString('sup_contractorName', data['contractorName']);
        if (data.containsKey('contractorField'))
          await _prefs.setString(
            'sup_contractorField',
            data['contractorField'],
          );
        if (data.containsKey('orgId'))
          await _prefs.setString('sup_org_path', data['orgId']);
        if (data.containsKey('sup_org_doc_path'))
          await _prefs.setString('sup_org_doc_path', data['sup_org_doc_path']);
        break;
      case UserRole.customer:
        await _prefs.setBool('cust_isLoggedIn', true);
        if (data.containsKey('ownerName'))
          await _prefs.setString('cust_ownerName', data['ownerName']);
        if (data.containsKey('siteId'))
          await _prefs.setString('cust_siteId', data['siteId']);
        if (data.containsKey('orgId'))
          await _prefs.setString('cust_org_path', data['orgId']);
        if (data.containsKey('cust_org_doc_path'))
          await _prefs.setString(
            'cust_org_doc_path',
            data['cust_org_doc_path'],
          );
        break;
      default:
        break;
    }
  }
}
