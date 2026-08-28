import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/screens/organization/organisation_registration_page.dart';
import 'package:demo_cst/screens/common/reset_password_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/firestore_error_handler.dart';

class Organisation_LoginPage extends StatefulWidget {
  const Organisation_LoginPage({super.key});

  @override
  _Organisation_LoginPageState createState() => _Organisation_LoginPageState();
}

class _Organisation_LoginPageState extends State<Organisation_LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _tempOrgName;
  String? _tempLogoUrl;

  @override
  void initState() {
    super.initState();
    _checkReferralInfo();
    _checkLoginStatus();
  }

  Future<void> _checkReferralInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tempOrgName = prefs.getString('temp_org_name');
      _tempLogoUrl = prefs.getString('temp_logo_url');
    });
  }

  // Check if organization is already logged in
  Future<void> _checkLoginStatus() async {
    final auth = AuthService();
    if (auth.isLoggedIn && auth.userRole == UserRole.organization) {
      final orgId = auth.userData['dynamicPath'];
      if (orgId != null && orgId.toString().isNotEmpty) {
        await AppTheme.syncWithFirestore(orgId.toString());
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OrganizationDashboard(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    AppTheme.showErrorToast(context, message);
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Search for organization credentials in 'admin' or 'data' collections
      // This handles both path structures: /admin/data and /data/admin
      QuerySnapshot<Map<String, dynamic>>? userQuery;

      // Try 'admin' collection group first
      userQuery = await FirebaseFirestore.instance
          .collectionGroup('admin')
          .where('username', isEqualTo: username)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? dataDoc;

      if (userQuery.docs.isNotEmpty) {
        for (var doc in userQuery.docs) {
          if (doc.id == 'data' || doc.id == 'admin') {
            dataDoc = doc;
            break;
          }
        }
      }

      // If not found, try 'data' collection group
      if (dataDoc == null) {
        userQuery = await FirebaseFirestore.instance
            .collectionGroup('data')
            .where('username', isEqualTo: username)
            .get();

        if (userQuery.docs.isNotEmpty) {
          for (var doc in userQuery.docs) {
            if (doc.id == 'admin' || doc.id == 'data') {
              dataDoc = doc;
              break;
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
        // FALLBACK: Check root organisation collection for legacy accounts
        final legacyQuery = await FirebaseFirestore.instance
            .collection('organisation')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (legacyQuery.docs.isNotEmpty) {
          final legacyDoc = legacyQuery.docs.first;
          userData = legacyDoc.data();
          dynamicPath = legacyDoc.id;
          fullConfigPath = legacyDoc.reference.path;
          debugPrint(
            'Organisation_LoginPage: Logged in via legacy root fallback for $username',
          );
        }
      }

      if (userData != null) {
        final String? email = (userData['email'] ?? '').toString();
        final String? storedOrgName = (userData['org_name'] ?? userData['orgName']) as String?;

        if (email != null && email.isNotEmpty) {
          // Authenticate with Firebase Authentication
          try {
            await AuthService().loginWithEmail(email, password);

            // Sync password in Firestore if it was reset via email
            if (userData['password'] != password) {
              final WriteBatch batch = FirebaseFirestore.instance.batch();

              // Update the admin/data or data/admin document
              batch.update(FirebaseFirestore.instance.doc(fullConfigPath!), {
                'password': password,
              });

              // Also update the organizationUser collection entry for this admin
              if (dynamicPath != null && dynamicPath != 'uninitialized') {
                final userDocRef = FirebaseFirestore.instance
                    .collection('organisation')
                    .doc(dynamicPath)
                    .collection('organizationUser')
                    .doc(username);

                batch.update(userDocRef, {'password': password});
              }

              await batch.commit();
              debugPrint(
                'Firestore passwords synced with Firebase Auth in both locations',
              );
            }
          } catch (e) {
            _showError('The username or password you entered is incorrect');
            return;
          }
        } else {
          // FALLBACK: If email is missing (legacy accounts), validate password manually
          if (userData['password'] != password) {
            _showError('Invalid username or password');
            return;
          }
        }

        final String? referralCode = userData['referralCode']?.toString() ??
            userData['orgReferralCode']?.toString();

        // Write organization info to AuthService
        await AuthService().login(UserRole.organization, {
          'username': username,
          'dynamicPath': dynamicPath,
          'org_name': storedOrgName,
          'org_doc_path': fullConfigPath,
          if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
        });

        // Refresh FirestoreService cache
        await FirestoreService.initialize();

        // Synchronize branding details
        await AppTheme.syncWithFirestore(dynamicPath ?? 'uninitialized');

        // Save FCM token for push notifications
        await NotificationService.saveToken(
          userId: username,
          userType: 'organisation',
          userName: username,
        );

        // Check if registration is completed but subscription/payment is pending
        bool isPaymentPending = false;
        if (dynamicPath != null && dynamicPath != 'uninitialized') {
          try {
            final subDoc = await FirebaseFirestore.instance
                .collection('organisation')
                .doc(dynamicPath)
                .collection('data')
                .doc('subscription')
                .get();

            final subData = subDoc.data();
            final bool isSubActive = subData?['isSubscriptionActive'] == true;
            final String onboardingStep = (subData?['onboardingStep'] ??
                    userData['onboardingStep'] ??
                    '')
                .toString();
            final String paymentStatus = (subData?['paymentStatus'] ??
                    userData['paymentStatus'] ??
                    '')
                .toString();

            if (!isSubActive &&
                (onboardingStep == 'PAYMENT_PENDING' ||
                    paymentStatus == 'PENDING' ||
                    subData == null ||
                    subData['subscriptionPlan'] == 'Pending Selection')) {
              isPaymentPending = true;
            }
          } catch (subCheckErr) {
            debugPrint('Subscription pending check note: $subCheckErr');
          }
        }

        if (isPaymentPending) {
          final rootDoc = await FirebaseFirestore.instance
              .collection('organisation')
              .doc(dynamicPath)
              .get();
          final rootData = rootDoc.data() ?? {};
          final String effectiveOrgName = rootData['org_name'] ??
              userData['org_name'] ??
              storedOrgName ??
              '';
          final String effectiveAppName =
              rootData['app_name'] ?? userData['app_name'] ?? effectiveOrgName;
          final String themeHex =
              rootData['theme_color'] ?? userData['theme_color'] ?? '#00A86B';
          final Color primaryColor = AppTheme.hexToColor(themeHex);

          String dateStr = '';
          if (dynamicPath != null && dynamicPath.contains('_')) {
            dateStr = dynamicPath.split('_').last;
          }

          final String phoneStr =
              (userData['phone'] ?? rootData['phone'] ?? '').toString();

          if (mounted) {
            AppTheme.showSuccessToast(
              context,
              'Registration details found. Please choose your plan to activate your workspace.',
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PricingScreen(
                  orgName: effectiveOrgName,
                  email: email ?? '',
                  phone: phoneStr,
                  username: username,
                  password: password,
                  dateStr: dateStr,
                  appName: effectiveAppName,
                  selectedColor: primaryColor,
                ),
              ),
            );
            return;
          }
        }

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/orgDashboard',
            (route) => false,
          );
        }
      } else {
        _showError('Invalid username or password');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        FirestoreErrorHandler.handleError(context, e, title: 'Login Error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        letterSpacing: -0.2,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required Color primaryColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: const Color(0xFF64748B),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final screenWidth = MediaQuery.of(context).size.width;

        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1024;
        bool isDesktop = screenWidth >= 1024;

        double horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
        double maxContentWidth = 480.0;

        return GlassScaffold(
          onBack: () => Navigator.pop(context),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      36,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: darkAccent.withValues(alpha: 0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: darkAccent.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.business_rounded,
                                size: 14,
                                color: darkAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ORGANIZATION PORTAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: darkAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Logo / Avatar
                        if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                          Container(
                            width: isDesktop ? 96 : (isTablet ? 88 : 80),
                            height: isDesktop ? 96 : (isTablet ? 88 : 80),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: darkAccent.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                _tempLogoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.corporate_fare_rounded,
                                  size: isDesktop ? 48 : 40,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: isDesktop ? 92 : (isTablet ? 84 : 76),
                            height: isDesktop ? 92 : (isTablet ? 84 : 76),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: darkAccent.withValues(alpha: 0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  Icons.corporate_fare_rounded,
                                  size: isDesktop ? 34 : (isTablet ? 30 : 28),
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),

                        // Title & Subtitle
                        Text(
                          _tempOrgName ?? 'Organization Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isDesktop ? 26 : (isTablet ? 24 : 22),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: darkAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to manage your organization & team',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            fontWeight: FontWeight.w500,
                            color: darkAccent.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Form Card Container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0A183D).withValues(alpha: 0.08),
                                blurRadius: 28,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: darkAccent.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFEDF2F7),
                              width: 1.2,
                            ),
                          ),
                          padding: EdgeInsets.all(
                            isDesktop ? 28 : (isTablet ? 24 : 20),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username
                                _buildFieldLabel('Username'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Enter username',
                                    prefixIcon: Icons.person_outline_rounded,
                                    primaryColor: primaryColor,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 18),

                                // Password
                                _buildFieldLabel('Password'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Enter password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    primaryColor: primaryColor,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: 20,
                                        color: const Color(0xFF64748B),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible = !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 10),

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ResetPasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: darkAccent,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          darkAccent.withValues(alpha: 0.5),
                                      disabledForegroundColor:
                                          Colors.white.withValues(alpha: 0.7),
                                      elevation: 4,
                                      shadowColor: darkAccent.withValues(alpha: 0.35),
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
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'LOGIN',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                // Divider
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFFE2E8F0),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFFE2E8F0),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Register Now High-Contrast Footer Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    runAlignment: WrapAlignment.center,
                                    spacing: 4,
                                    children: [
                                      const Text(
                                        "Don't have an account?",
                                        style: TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const OrganisationRegistrationPage(),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            'Register Now',
                                            style: TextStyle(
                                              color: darkAccent,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: darkAccent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
