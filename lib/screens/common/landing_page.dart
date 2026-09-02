import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';
import 'package:demo_cst/screens/manager/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor/supervisor_dashboard.dart';

enum LoginRole { organization, manager, supervisor }

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  LoginRole _selectedRole = LoginRole.organization;
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

  // -------------------- LOGIN HANDLER --------------------
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    try {
      switch (_selectedRole) {
        case LoginRole.organization:
          await _loginOrganization();
          break;
        case LoginRole.manager:
          await _loginManager();
          break;
        case LoginRole.supervisor:
          await _loginSupervisor();
          break;
      }
    } catch (e) {
      debugPrint('Login Exception: $e');
      if (mounted) {
        _showError('Login failed: ${e.toString().replaceAll("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 1. Organization Login
  Future<void> _loginOrganization() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    QuerySnapshot<Map<String, dynamic>>? userQuery;

    // Try 'admin' collection group
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

    // Try 'data' collection group
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
      // Fallback: Check root organisation collection
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

    if (userData == null) {
      _showError('Invalid username or organization account not found');
      return;
    }

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
              FirebaseFirestore.instance.collection('organisation').doc(dynamicPath),
              {'password': password},
            );
          }
          await batch.commit();
        }
      } catch (authError) {
        if (userData['password'] == password) {
          try {
            await AuthService().registerWithEmail(email, password);
          } catch (_) {}
        } else {
          _showError('Incorrect password. Please try again.');
          return;
        }
      }
    } else {
      if (userData['password'] != password) {
        _showError('Incorrect password. Please try again.');
        return;
      }
    }

    // Set org path and sync branding
    FirestoreService.setOrgPath(dynamicPath ?? '');
    await AppTheme.syncWithFirestore(dynamicPath ?? '');

    // Check payment pending state
    bool isPaymentPending = false;
    try {
      final subDoc = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(dynamicPath)
          .collection('data')
          .doc('subscription')
          .get();
      final subData = subDoc.data();
      if (subData != null &&
          subData['isSubscriptionActive'] != true &&
          (subData['onboardingStep'] == 'PAYMENT_PENDING' ||
              subData['subscriptionPlan'] == 'Pending Selection')) {
        isPaymentPending = true;
      }
    } catch (_) {}

    final authData = {
      ...userData,
      'dynamicPath': dynamicPath,
      'fullConfigPath': fullConfigPath,
    };
    await AuthService().login(UserRole.organization, authData);

    if (!mounted) return;

    if (isPaymentPending) {
      final rootDoc = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(dynamicPath)
          .get();
      final rootData = rootDoc.data() ?? {};
      final String effectiveOrgName =
          rootData['org_name'] ?? storedOrgName ?? 'Organization';
      final String effectiveAppName =
          rootData['app_name'] ?? effectiveOrgName;
      final String themeHex = rootData['theme_color'] ?? '#00A86B';
      final Color primaryColor = AppTheme.hexToColor(themeHex);

      String dateStr = '';
      if (dynamicPath != null && dynamicPath.contains('_')) {
        dateStr = dynamicPath.split('_').last;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PricingScreen(
            orgName: effectiveOrgName,
            appName: effectiveAppName,
            selectedColor: primaryColor,
            dateStr: dateStr,
            username: username,
            password: password,
            email: email,
          ),
        ),
      );
      return;
    }

    final isSubscriptionValid = await AuthService().checkSubscriptionStatus();
    if (!mounted) return;

    if (isSubscriptionValid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrganizationDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrganizationSubscriptionPage()),
      );
    }
  }

  // 2. Manager Login
  Future<void> _loginManager() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    QuerySnapshot<Map<String, dynamic>>? querySnapshot;

    // 1. Search in collectionGroup 'manager'
    querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('manager')
        .where('UserName', isEqualTo: username)
        .where('Password', isEqualTo: password)
        .get();

    // 2. Also search in collectionGroup 'configUsers'
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConfigAccountDashboard()),
        );
      }
    } else {
      _showError('Invalid Manager username or password');
    }
  }

  // 3. Supervisor Login
  Future<void> _loginSupervisor() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    QuerySnapshot<Map<String, dynamic>>? querySnapshot;

    // 1. Search in collectionGroup 'supervisor'
    querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('supervisor')
        .where('UserName', isEqualTo: username)
        .where('Password', isEqualTo: password)
        .limit(1)
        .get();

    // 2. Also search in collectionGroup 'supervisors'
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
      final supervisorName = doc.data()['Name'] ?? doc.data()['supervisorName'] ?? username;

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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SupervisorDashboard(
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              username: username,
            ),
          ),
        );
      }
    } else {
      _showError('Invalid Supervisor username or password');
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: Image.asset(
                            'assets/images/logo_main.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.construction_rounded,
                              size: 56,
                              color: primaryColor,
                            ),
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

                      // 2. Role Selector Tabs
                      _buildRoleSelector(primaryColor, darkAccent),
                      const SizedBox(height: 18),

                      // 3. Unified Form Card
                      _buildLoginFormCard(primaryColor, darkAccent),
                      const SizedBox(height: 20),

                      // 4. Create Account Link (Only visible on Organization tab)
                      if (_selectedRole == LoginRole.organization) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.92),
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

  // -------------------- ROLE SELECTOR --------------------
  Widget _buildRoleSelector(Color primaryColor, Color darkAccent) {
    final roles = [
      {
        'role': LoginRole.organization,
        'title': 'Organization',
        'icon': Icons.business_center_rounded,
      },
      {
        'role': LoginRole.manager,
        'title': 'Manager',
        'icon': Icons.manage_accounts_rounded,
      },
      {
        'role': LoginRole.supervisor,
        'title': 'Supervisor',
        'icon': Icons.supervisor_account_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: roles.map((item) {
          final role = item['role'] as LoginRole;
          final isSelected = _selectedRole == role;
          final title = item['title'] as String;
          final icon = item['icon'] as IconData;

          return Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedRole != role) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedRole = role;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [primaryColor, darkAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------- LOGIN FORM CARD --------------------
  Widget _buildLoginFormCard(Color primaryColor, Color darkAccent) {
    final roleName = _selectedRole == LoginRole.organization
        ? 'Organization'
        : _selectedRole == LoginRole.manager
            ? 'Manager'
            : 'Supervisor';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 12,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _selectedRole == LoginRole.organization
                        ? Icons.domain_rounded
                        : _selectedRole == LoginRole.manager
                            ? Icons.badge_rounded
                            : Icons.engineering_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roleName Sign In',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter your credentials to continue',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Username Field
            _buildInputField(
              controller: _usernameController,
              label: _selectedRole == LoginRole.organization
                  ? 'Username or Email'
                  : '$roleName Username',
              hint: _selectedRole == LoginRole.organization
                  ? 'Enter admin username or email'
                  : 'Enter $roleName username',
              icon: Icons.person_outline_rounded,
              primaryColor: primaryColor,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Username is required' : null,
            ),
            const SizedBox(height: 16),

            // Password Field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter password',
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

            // Forgot Password Link for Organization
            if (_selectedRole == LoginRole.organization) ...[
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
            ],
            const SizedBox(height: 22),

            // Submit Login CTA Button
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
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                      borderRadius: BorderRadius.circular(14),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Login as $roleName',
                              style: const TextStyle(
                                fontSize: 15,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
