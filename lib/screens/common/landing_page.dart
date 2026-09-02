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
      // 1. Check if user is an Organization Admin
      final bool isOrg = await _tryOrganizationLogin(username, password);
      if (isOrg) return;

      // 2. Check if user is a Manager
      final bool isManager = await _tryManagerLogin(username, password);
      if (isManager) return;

      // 3. Check if user is a Supervisor / Contractor
      final bool isSupervisor = await _trySupervisorLogin(username, password);
      if (isSupervisor) return;

      // 4. Check if user is a Customer / Client
      final bool isCustomer = await _tryCustomerLogin(username, password);
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
  Future<bool> _tryOrganizationLogin(String username, String password) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? userQuery;

      // Check 'admin' collection group
      userQuery = await FirebaseFirestore.instance
          .collectionGroup('admin')
          .where('username', isEqualTo: username)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? dataDoc;

      if (userQuery.docs.isNotEmpty) {
        for (var doc in userQuery.docs) {
          if (doc.id == 'data' || doc.id == 'admin') {
            final data = doc.data();
            final appId = (data['app_id'] ?? data['appId'] ?? '').toString();
            final orgDocId = doc.reference.parent.parent?.id ?? '';
            if (appId == FirestoreService.cstAppId ||
                FirestoreService.isCstOrgId(orgDocId) ||
                data['is_cst_app'] == true) {
              dataDoc = doc;
              break;
            }
          }
        }
      }

      // Check 'data' collection group
      if (dataDoc == null) {
        userQuery = await FirebaseFirestore.instance
            .collectionGroup('data')
            .where('username', isEqualTo: username)
            .get();

        if (userQuery.docs.isNotEmpty) {
          for (var doc in userQuery.docs) {
            if (doc.id == 'admin' || doc.id == 'data') {
              final data = doc.data();
              final appId = (data['app_id'] ?? data['appId'] ?? '').toString();
              final orgDocId = doc.reference.parent.parent?.id ?? '';
              if (appId == FirestoreService.cstAppId ||
                  FirestoreService.isCstOrgId(orgDocId) ||
                  data['is_cst_app'] == true) {
                dataDoc = doc;
                break;
              }
            }
          }
        }
      }

      Map<String, dynamic>? userData;
      String? dynamicPath;
      String? fullConfigPath;

      if (dataDoc != null) {
        userData = dataDoc.data();
        dynamicPath = dataDoc.reference.parent.parent?.id ?? 'uninitialized';
        fullConfigPath = dataDoc.reference.path;
      } else {
        // Fallback check root organisation collection
        final legacyQuery = await FirebaseFirestore.instance
            .collection('organisation')
            .where('username', isEqualTo: username)
            .get();

        for (var legacyDoc in legacyQuery.docs) {
          final data = legacyDoc.data();
          final appId = (data['app_id'] ?? data['appId'] ?? '').toString();
          if (appId == FirestoreService.cstAppId ||
              FirestoreService.isCstOrgId(legacyDoc.id) ||
              data['is_cst_app'] == true) {
            userData = data;
            dynamicPath = legacyDoc.id;
            fullConfigPath = legacyDoc.reference.path;
            break;
          }
        }
      }

      if (userData == null) return false;

      final String email = (userData['email'] ?? '').toString();
      final String? storedOrgName =
          (userData['org_name'] ?? userData['orgName']) as String?;

      if (email.isNotEmpty) {
        try {
          await AuthService().loginWithEmail(email, password);
          if (userData['password'] != password && fullConfigPath != null) {
            final WriteBatch batch = FirebaseFirestore.instance.batch();
            batch.update(FirebaseFirestore.instance.doc(fullConfigPath), {
              'password': password,
            });
            if (dynamicPath != null && dynamicPath != 'uninitialized') {
              batch.update(
                FirebaseFirestore.instance
                    .collection('organisation')
                    .doc(dynamicPath)
                    .collection('organizationUser')
                    .doc(username),
                {'password': password},
              );
            }
            await batch.commit();
          }
        } catch (_) {
          // If Firebase Auth fails, compare direct password as fallback
          if (userData['password'] != password) {
            return false;
          }
        }
      } else {
        if (userData['password'] != password) {
          return false;
        }
      }

      // Set org path and sync branding
      FirestoreService.setOrgPath(dynamicPath ?? '');
      await AppTheme.syncWithFirestore(dynamicPath ?? '');

      await AuthService().login(UserRole.organization, {
        'username': username,
        'dynamicPath': dynamicPath,
        'org_name': storedOrgName,
        'org_doc_path': fullConfigPath,
      });

      await NotificationService.saveToken(
        userId: username,
        userType: 'organisation',
        userName: username,
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
    } catch (_) {
      return false;
    }
  }

  // 2. Manager Login Check
  Future<bool> _tryManagerLogin(String username, String password) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? querySnapshot;

      // Check 'manager' collection group
      querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('manager')
          .where('UserName', isEqualTo: username)
          .where('Password', isEqualTo: password)
          .get();

      // Check 'configUsers' collection group
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('configUsers')
            .where('UserName', isEqualTo: username)
            .where('Password', isEqualTo: password)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final docData = doc.data();

        // Extract orgId from document path (organisation/{orgId}/...)
        String orgId = '';
        final segments = doc.reference.path.split('/');
        final orgIndex = segments.indexOf('organisation');
        if (orgIndex != -1 && orgIndex + 1 < segments.length) {
          orgId = segments[orgIndex + 1];
        }

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
          'username': username,
          'password': password,
          'orgId': orgId,
          'config_org_doc_path': 'organisation/$orgId/data/admin',
          ...docData,
        };
        await AuthService().login(UserRole.manager, data);

        await NotificationService.saveToken(
          userId: username,
          userType: 'manager',
          userName: username,
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
      return false;
    } catch (_) {
      return false;
    }
  }

  // 3. Supervisor Login Check
  Future<bool> _trySupervisorLogin(String username, String password) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? querySnapshot;

      querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('supervisor')
          .where('UserName', isEqualTo: username)
          .where('Password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('supervisors')
            .where('UserName', isEqualTo: username)
            .where('Password', isEqualTo: password)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final supervisorId = doc.id;
        final supervisorName =
            doc.data()['Name'] ?? doc.data()['supervisorName'] ?? username;

        // Extract orgId from document path (organisation/{orgId}/...)
        String orgId = '';
        final segments = doc.reference.path.split('/');
        final orgIndex = segments.indexOf('organisation');
        if (orgIndex != -1 && orgIndex + 1 < segments.length) {
          orgId = segments[orgIndex + 1];
        }

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
          'username': username,
          'supervisorId': supervisorId,
          'supervisorName': supervisorName,
          'isContractor': false,
          'userType': 'supervisor',
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
      return false;
    } catch (_) {
      return false;
    }
  }

  // 4. Customer Login Check
  Future<bool> _tryCustomerLogin(String username, String password) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collectionGroup('customers')
              .where('ownerPhoneNumber', isEqualTo: username)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        await AuthService().login(UserRole.customer, {
          'ownerName': data['ownerName'] ?? username,
          'ownerPhoneNumber': data['ownerPhoneNumber'] ?? username,
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
      return false;
    } catch (_) {
      return false;
    }
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
