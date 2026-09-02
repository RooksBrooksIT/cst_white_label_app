import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/common/portal_loading_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    AppTheme.showErrorToast(context, message);
  }

  // -------------------- UNIFIED ROLE-BASED LOGIN HANDLER --------------------
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Fetch all organisation documents (single roundtrip, no composite index needed)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs = [];
      try {
        final orgsSnapshot =
            await FirebaseFirestore.instance.collection('organisation').get();
        orgDocs = orgsSnapshot.docs;
      } catch (e) {
        debugPrint('LandingPage: Root organisation fetch note: $e');
      }

      // 1. Check if user is an Organization Admin
      final bool isOrg =
          await _tryOrganizationLogin(username, password, orgDocs);
      if (isOrg) return;

      // 2. Check if user is a Manager
      final bool isManager =
          await _tryManagerLogin(username, password, orgDocs);
      if (isManager) return;

      // 3. Check if user is a Supervisor / Contractor
      final bool isSupervisor =
          await _trySupervisorLogin(username, password, orgDocs);
      if (isSupervisor) return;

      // 4. Check if user is a Customer / Client
      final bool isCustomer =
          await _tryCustomerLogin(username, password, orgDocs);
      if (isCustomer) return;

      // If no matching account found across any role:
      if (mounted) {
        _showError('Incorrect username or password. Please check your credentials.');
      }
    } catch (e) {
      debugPrint('Universal Login Exception: $e');
      if (mounted) {
        _showError('Login failed: ${e.toString().replaceAll("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 1. Organization Login Check
  Future<bool> _tryOrganizationLogin(
    String username,
    String password,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs,
  ) async {
    final cleanInput = username.trim();
    final cleanLower = cleanInput.toLowerCase();
    final cleanPass = password.trim();

    try {
      Map<String, dynamic>? userData;
      String? dynamicPath;
      String? fullConfigPath;

      // Strategy A: Check in fetched orgDocs (Instant, zero index needed)
      for (var doc in orgDocs) {
        final data = doc.data();
        final docEmail = (data['email'] ?? data['Email'] ?? data['emailId'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final docUser = (data['username'] ?? data['UserName'] ?? data['userName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final docPhone = (data['phone'] ??
                data['MobileNumber'] ??
                data['phone_number'] ??
                data['phoneNumber'] ??
                '')
            .toString()
            .trim();
        final docOrgName = (data['org_name'] ?? data['orgName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final docId = doc.id.toLowerCase();

        if (docEmail == cleanLower ||
            docUser == cleanLower ||
            docUser == cleanInput ||
            docPhone == cleanInput ||
            docId == cleanLower ||
            docId == 'cst_$cleanLower' ||
            (cleanLower.isNotEmpty && docOrgName == cleanLower)) {
          userData = data;
          dynamicPath = doc.id;
          fullConfigPath = doc.reference.path;
          break;
        }
      }

      // Strategy B: If matched org root or need to check data/admin & organizationUser
      if (userData != null && dynamicPath != null) {
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('organisation')
              .doc(dynamicPath)
              .collection('data')
              .doc('admin')
              .get();
          if (adminDoc.exists && adminDoc.data() != null) {
            userData = {...userData, ...adminDoc.data()!};
            fullConfigPath = adminDoc.reference.path;
          }
        } catch (_) {}
      } else {
        // Deep search inside each organisation subcollection
        for (var doc in orgDocs) {
          try {
            final adminDoc =
                await doc.reference.collection('data').doc('admin').get();
            if (adminDoc.exists && adminDoc.data() != null) {
              final aData = adminDoc.data()!;
              final aEmail = (aData['email'] ?? '').toString().trim().toLowerCase();
              final aUser = (aData['username'] ?? '').toString().trim().toLowerCase();
              final aPhone =
                  (aData['phone'] ?? aData['MobileNumber'] ?? '').toString().trim();
              if (aEmail == cleanLower || aUser == cleanLower || aPhone == cleanInput) {
                userData = aData;
                dynamicPath = doc.id;
                fullConfigPath = adminDoc.reference.path;
                break;
              }
            }

            final userDoc =
                await doc.reference.collection('organizationUser').doc(cleanLower).get();
            if (userDoc.exists && userDoc.data() != null) {
              userData = userDoc.data();
              dynamicPath = doc.id;
              fullConfigPath = userDoc.reference.path;
              break;
            }
          } catch (_) {}
        }
      }

      // Strategy C: Direct doc ID fallback
      if (userData == null) {
        try {
          final directDoc = await FirebaseFirestore.instance
              .collection('organisation')
              .doc(cleanInput)
              .get();
          if (directDoc.exists && directDoc.data() != null) {
            userData = directDoc.data();
            dynamicPath = directDoc.id;
            fullConfigPath = directDoc.reference.path;
          } else {
            final cstDoc = await FirebaseFirestore.instance
                .collection('organisation')
                .doc('cst_$cleanInput')
                .get();
            if (cstDoc.exists && cstDoc.data() != null) {
              userData = cstDoc.data();
              dynamicPath = cstDoc.id;
              fullConfigPath = cstDoc.reference.path;
            }
          }
        } catch (_) {}
      }

      if (userData == null) return false;

      final String storedPassword =
          (userData['password'] ?? userData['Password'] ?? '').toString().trim();
      final String email =
          (userData['email'] ?? userData['Email'] ?? '').toString().trim();
      final String actualUsername =
          (userData['username'] ?? userData['UserName'] ?? cleanInput).toString().trim();
      final String? storedOrgName =
          (userData['org_name'] ?? userData['orgName']) as String?;

      bool isPasswordValid = false;

      // 1. Direct Password Match (Primary for all registered accounts)
      if (storedPassword.isNotEmpty && storedPassword == cleanPass) {
        isPasswordValid = true;
      }

      // 2. Firebase Auth login attempt
      if (email.isNotEmpty) {
        try {
          await AuthService().loginWithEmail(email, cleanPass);
          isPasswordValid = true;

          // Sync password if updated
          if (storedPassword != cleanPass && fullConfigPath != null) {
            final WriteBatch batch = FirebaseFirestore.instance.batch();
            batch.update(FirebaseFirestore.instance.doc(fullConfigPath), {
              'password': cleanPass,
            });
            if (dynamicPath != null && dynamicPath != 'uninitialized') {
              batch.update(
                FirebaseFirestore.instance
                    .collection('organisation')
                    .doc(dynamicPath)
                    .collection('organizationUser')
                    .doc(actualUsername),
                {'password': cleanPass},
              );
              batch.update(
                FirebaseFirestore.instance
                    .collection('organisation')
                    .doc(dynamicPath),
                {'password': cleanPass},
              );
            }
            await batch.commit().catchError((_) {});
          }
        } catch (authErr) {
          debugPrint('LandingPage: Firebase Auth note: $authErr');
        }
      }

      if (!isPasswordValid) return false;

      final String? referralCode = userData['referralCode']?.toString() ??
          userData['orgReferralCode']?.toString();

      // Set org path and sync branding
      FirestoreService.setOrgPath(dynamicPath ?? '');
      if (dynamicPath != null && dynamicPath != 'uninitialized') {
        try {
          await AppTheme.syncWithFirestore(dynamicPath);
        } catch (_) {}
      }

      await AuthService().login(UserRole.organization, {
        'username': actualUsername,
        'dynamicPath': dynamicPath,
        'org_name': storedOrgName,
        'org_doc_path': fullConfigPath,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
      });

      await NotificationService.saveToken(
        userId: actualUsername,
        userType: 'organisation',
        userName: actualUsername,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PortalLoadingScreen(
              expectedRole: UserRole.organization,
              initialStatusMessage: 'Loading your dashboard…',
            ),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
          (route) => false,
        );
      }
      return true;
    } catch (e) {
      debugPrint('LandingPage: _tryOrganizationLogin error: $e');
      return false;
    }
  }

  // 2. Manager Login Check
  Future<bool> _tryManagerLogin(
    String username,
    String password,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs,
  ) async {
    final cleanInput = username.trim();
    final cleanLower = cleanInput.toLowerCase();
    final cleanPass = password.trim();

    try {
      // 1. Direct subcollection check under each org (zero index dependency)
      for (var orgDoc in orgDocs) {
        final orgId = orgDoc.id;
        try {
          final managerSnap = await orgDoc.reference.collection('manager').get();
          for (var doc in managerSnap.docs) {
            final docData = doc.data();
            final docUser = (docData['UserName'] ?? docData['username'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final docEmail =
                (docData['email'] ?? '').toString().trim().toLowerCase();
            final docPhone =
                (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
            final storedPass =
                (docData['Password'] ?? docData['password'] ?? '').toString().trim();

            if ((docUser == cleanLower ||
                    docUser == cleanInput ||
                    docEmail == cleanLower ||
                    docPhone == cleanInput ||
                    doc.id.toLowerCase() == cleanLower) &&
                storedPass == cleanPass) {
              return await _completeManagerLogin(
                  doc.id, orgId, docData, cleanInput, cleanPass);
            }
          }

          final configUsersSnap =
              await orgDoc.reference.collection('configUsers').get();
          for (var doc in configUsersSnap.docs) {
            final docData = doc.data();
            final docUser = (docData['UserName'] ?? docData['username'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final docEmail =
                (docData['email'] ?? '').toString().trim().toLowerCase();
            final docPhone =
                (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
            final storedPass =
                (docData['Password'] ?? docData['password'] ?? '').toString().trim();

            if ((docUser == cleanLower ||
                    docUser == cleanInput ||
                    docEmail == cleanLower ||
                    docPhone == cleanInput) &&
                storedPass == cleanPass) {
              return await _completeManagerLogin(
                  doc.id, orgId, docData, cleanInput, cleanPass);
            }
          }
        } catch (_) {}
      }

      // 2. Safe collectionGroup fallback with isolated error handling
      try {
        final cgSnap =
            await FirebaseFirestore.instance.collectionGroup('manager').get();
        for (var doc in cgSnap.docs) {
          final docData = doc.data();
          final docUser = (docData['UserName'] ?? docData['username'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final docEmail =
              (docData['email'] ?? '').toString().trim().toLowerCase();
          final docPhone =
              (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
          final storedPass =
              (docData['Password'] ?? docData['password'] ?? '').toString().trim();

          if ((docUser == cleanLower ||
                  docUser == cleanInput ||
                  docEmail == cleanLower ||
                  docPhone == cleanInput) &&
              storedPass == cleanPass) {
            String orgId = '';
            final segments = doc.reference.path.split('/');
            final orgIndex = segments.indexOf('organisation');
            if (orgIndex != -1 && orgIndex + 1 < segments.length) {
              orgId = segments[orgIndex + 1];
            }
            return await _completeManagerLogin(
                doc.id, orgId, docData, cleanInput, cleanPass);
          }
        }
      } catch (_) {}

      return false;
    } catch (e) {
      debugPrint('LandingPage: _tryManagerLogin error: $e');
      return false;
    }
  }

  Future<bool> _completeManagerLogin(
    String docId,
    String orgId,
    Map<String, dynamic> docData,
    String cleanInput,
    String cleanPass,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (orgId.isNotEmpty) {
      await prefs.setString('config_org_path', orgId);
      final String resolvedPath = 'organisation/$orgId/data/admin';
      await prefs.setString('config_org_doc_path', resolvedPath);
      FirestoreService.setOrgPath(orgId);
      await FirestoreService.initialize();
      await AppTheme.syncWithFirestore(orgId);
    }

    final Map<String, dynamic> data = {
      'username': docData['UserName'] ?? docData['username'] ?? cleanInput,
      'password': cleanPass,
      'orgId': orgId,
      'config_org_doc_path': 'organisation/$orgId/data/admin',
      ...docData,
    };
    await AuthService().login(UserRole.manager, data);

    await NotificationService.saveToken(
      userId: docId,
      userType: 'manager',
      userName: data['username'] ?? cleanInput,
    );

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PortalLoadingScreen(
            expectedRole: UserRole.manager,
            initialStatusMessage: 'Loading manager portal…',
          ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    }
    return true;
  }

  // 3. Supervisor Login Check
  Future<bool> _trySupervisorLogin(
    String username,
    String password,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs,
  ) async {
    final cleanInput = username.trim();
    final cleanLower = cleanInput.toLowerCase();
    final cleanPass = password.trim();

    try {
      // 1. Direct subcollection search under each org (zero index dependency)
      for (var orgDoc in orgDocs) {
        final orgId = orgDoc.id;
        try {
          final supSnap = await orgDoc.reference.collection('supervisor').get();
          for (var doc in supSnap.docs) {
            final docData = doc.data();
            final docUser = (docData['UserName'] ??
                    docData['username'] ??
                    docData['Name'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();
            final docEmail =
                (docData['email'] ?? '').toString().trim().toLowerCase();
            final docPhone =
                (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
            final storedPass =
                (docData['Password'] ?? docData['password'] ?? '').toString().trim();

            if ((docUser == cleanLower ||
                    docUser == cleanInput ||
                    docEmail == cleanLower ||
                    docPhone == cleanInput ||
                    doc.id.toLowerCase() == cleanLower) &&
                storedPass == cleanPass) {
              return await _completeSupervisorLogin(
                  doc.id, orgId, docData, cleanInput);
            }
          }

          final supsSnap =
              await orgDoc.reference.collection('supervisors').get();
          for (var doc in supsSnap.docs) {
            final docData = doc.data();
            final docUser = (docData['UserName'] ??
                    docData['username'] ??
                    docData['Name'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();
            final docEmail =
                (docData['email'] ?? '').toString().trim().toLowerCase();
            final docPhone =
                (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
            final storedPass =
                (docData['Password'] ?? docData['password'] ?? '').toString().trim();

            if ((docUser == cleanLower ||
                    docUser == cleanInput ||
                    docEmail == cleanLower ||
                    docPhone == cleanInput) &&
                storedPass == cleanPass) {
              return await _completeSupervisorLogin(
                  doc.id, orgId, docData, cleanInput);
            }
          }
        } catch (_) {}
      }

      // 2. Safe collectionGroup fallback
      try {
        final cgSnap =
            await FirebaseFirestore.instance.collectionGroup('supervisor').get();
        for (var doc in cgSnap.docs) {
          final docData = doc.data();
          final docUser = (docData['UserName'] ??
                  docData['username'] ??
                  docData['Name'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase();
          final docEmail =
              (docData['email'] ?? '').toString().trim().toLowerCase();
          final docPhone =
              (docData['MobileNumber'] ?? docData['phone'] ?? '').toString().trim();
          final storedPass =
              (docData['Password'] ?? docData['password'] ?? '').toString().trim();

          if ((docUser == cleanLower ||
                  docUser == cleanInput ||
                  docEmail == cleanLower ||
                  docPhone == cleanInput) &&
              storedPass == cleanPass) {
            String orgId = '';
            final segments = doc.reference.path.split('/');
            final orgIndex = segments.indexOf('organisation');
            if (orgIndex != -1 && orgIndex + 1 < segments.length) {
              orgId = segments[orgIndex + 1];
            }
            return await _completeSupervisorLogin(
                doc.id, orgId, docData, cleanInput);
          }
        }
      } catch (_) {}

      return false;
    } catch (e) {
      debugPrint('LandingPage: _trySupervisorLogin error: $e');
      return false;
    }
  }

  Future<bool> _completeSupervisorLogin(
    String supervisorId,
    String orgId,
    Map<String, dynamic> docData,
    String cleanInput,
  ) async {
    final supervisorName = (docData['Name'] ??
            docData['supervisorName'] ??
            docData['UserName'] ??
            cleanInput)
        .toString();

    final prefs = await SharedPreferences.getInstance();
    if (orgId.isNotEmpty) {
      await prefs.setString('sup_org_path', orgId);
      final String resolvedPath = 'organisation/$orgId/data/admin';
      await prefs.setString('sup_org_doc_path', resolvedPath);
      FirestoreService.setOrgPath(orgId);
      await FirestoreService.initialize();
      await AppTheme.syncWithFirestore(orgId);
    }

    await AuthService().login(UserRole.supervisor, {
      'username': docData['UserName'] ?? docData['username'] ?? cleanInput,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'isContractor':
          docData['isContractor'] == true || docData['userType'] == 'contractor',
      'userType': docData['userType'] ?? 'supervisor',
      'orgId': orgId,
      'sup_org_doc_path': 'organisation/$orgId/data/admin',
    });

    await NotificationService.saveToken(
      userId: supervisorId,
      userType: 'supervisor',
      userName: supervisorName,
    );

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PortalLoadingScreen(
            expectedRole: UserRole.supervisor,
            initialStatusMessage: 'Loading supervisor portal…',
          ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    }
    return true;
  }

  // 4. Customer Login Check
  Future<bool> _tryCustomerLogin(
    String username,
    String password,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs,
  ) async {
    final cleanInput = username.trim();
    final cleanLower = cleanInput.toLowerCase();
    final cleanPass = password.trim();

    try {
      // 1. Direct subcollection search under each org (zero index dependency)
      for (var orgDoc in orgDocs) {
        try {
          final custSnap =
              await orgDoc.reference.collection('customers').get();
          for (var doc in custSnap.docs) {
            final data = doc.data();
            final phone =
                (data['ownerPhoneNumber'] ?? data['phone'] ?? '').toString().trim();
            final user =
                (data['username'] ?? data['ownerName'] ?? '').toString().trim().toLowerCase();
            final storedPass =
                (data['password'] ?? data['pin'] ?? '').toString().trim();

            if ((phone == cleanInput ||
                    user == cleanLower ||
                    user == cleanInput ||
                    doc.id.toLowerCase() == cleanLower) &&
                (storedPass.isEmpty || storedPass == cleanPass)) {
              return await _completeCustomerLogin(data, cleanInput);
            }
          }
        } catch (_) {}
      }

      // 2. Safe collectionGroup fallback
      try {
        final cgSnap =
            await FirebaseFirestore.instance.collectionGroup('customers').get();
        for (var doc in cgSnap.docs) {
          final data = doc.data();
          final phone =
              (data['ownerPhoneNumber'] ?? data['phone'] ?? '').toString().trim();
          final user =
              (data['username'] ?? data['ownerName'] ?? '').toString().trim().toLowerCase();
          final storedPass =
              (data['password'] ?? data['pin'] ?? '').toString().trim();

          if ((phone == cleanInput ||
                  user == cleanLower ||
                  user == cleanInput) &&
              (storedPass.isEmpty || storedPass == cleanPass)) {
            return await _completeCustomerLogin(data, cleanInput);
          }
        }
      } catch (_) {}

      return false;
    } catch (e) {
      debugPrint('LandingPage: _tryCustomerLogin error: $e');
      return false;
    }
  }

  Future<bool> _completeCustomerLogin(
      Map<String, dynamic> data, String cleanInput) async {
    await AuthService().login(UserRole.customer, {
      'ownerName': data['ownerName'] ?? cleanInput,
      'ownerPhoneNumber': data['ownerPhoneNumber'] ?? cleanInput,
      'siteId': data['siteId'] ?? '',
    });

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PortalLoadingScreen(
            expectedRole: UserRole.customer,
            initialStatusMessage: 'Loading client portal…',
          ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    }
    return true;
  }

  // -------------------- UI BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return GlassScaffold(
          padding: EdgeInsets.zero,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    children: [
                      // 1. Branding Header
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ValueListenableBuilder<String>(
                            valueListenable: AppTheme.logoUrl,
                            builder: (context, logoUrl, _) {
                              if (logoUrl.isNotEmpty) {
                                return Image.network(
                                  logoUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/logo_main.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => Icon(
                                      Icons.construction_rounded,
                                      size: 48,
                                      color: primaryColor,
                                    ),
                                  ),
                                );
                              }
                              return Image.asset(
                                'assets/images/logo_main.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.construction_rounded,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      ValueListenableBuilder<String>(
                        valueListenable: AppTheme.appName,
                        builder: (context, name, _) {
                          return Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0A183D),
                              letterSpacing: -0.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),

                      const Text(
                        'Manage Your Projects Like a Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A183D),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 4),

                      const Text(
                        'Sign in to access your role-based portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Unified Sign In Card
                      _buildUnifiedLoginFormCard(primaryColor, darkAccent),
                      const SizedBox(height: 20),

                      // 3. Register New Account Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/orgRegistrationForm',
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- UNIFIED LOGIN FORM CARD --------------------
  Widget _buildUnifiedLoginFormCard(Color primaryColor, Color darkAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 22,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Sign In',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sign in with your assigned account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Username or Email Field
            _buildInputField(
              controller: _usernameController,
              label: 'Username or Email',
              hint: 'Enter username or email',
              icon: Icons.person_outline_rounded,
              primaryColor: primaryColor,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Username or email is required' : null,
            ),
            const SizedBox(height: 16),

            // Password Field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isObscured: _isPasswordObscured,
              primaryColor: primaryColor,
              onToggleObscure: () {
                setState(() => _isPasswordObscured = !_isPasswordObscured);
              },
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Password is required' : null,
            ),

            // Forgot Password Link
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/resetPassword'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Submit Sign In CTA Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, darkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Sign In to Portal',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- INPUT FIELD BUILDER --------------------
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: isPassword && isObscured,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, size: 20, color: primaryColor),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
