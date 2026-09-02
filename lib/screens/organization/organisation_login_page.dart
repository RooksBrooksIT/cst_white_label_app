import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/screens/organization/organisation_registration_page.dart';
import 'package:demo_cst/screens/common/reset_password_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/firestore_error_handler.dart';
import 'package:demo_cst/screens/common/portal_loading_screen.dart';

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
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PortalLoadingScreen(
              expectedRole: UserRole.organization,
            ),
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
      final cleanInput = _usernameController.text.trim();
      final cleanLower = cleanInput.toLowerCase();
      final cleanPass = _passwordController.text.trim();

      // Fetch all organisation documents (single roundtrip, no composite index needed)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orgDocs = [];
      try {
        final orgsSnapshot =
            await FirebaseFirestore.instance.collection('organisation').get();
        orgDocs = orgsSnapshot.docs;
      } catch (e) {
        debugPrint('Organisation_LoginPage: Root fetch note: $e');
      }

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

      if (userData == null) {
        _showError('No account found for "$cleanInput". Please check your credentials.');
        return;
      }

      final String storedPassword =
          (userData['password'] ?? userData['Password'] ?? '').toString().trim();
      final String email =
          (userData['email'] ?? userData['Email'] ?? '').toString().trim();
      final String actualUsername =
          (userData['username'] ?? userData['UserName'] ?? cleanInput).toString().trim();
      final String? storedOrgName =
          (userData['org_name'] ?? userData['orgName']) as String?;

      bool isPasswordValid = false;

      // 1. Direct Password Match (Primary)
      if (storedPassword.isNotEmpty && storedPassword == cleanPass) {
        isPasswordValid = true;
      }

      // 2. Firebase Auth login attempt
      if (email.isNotEmpty) {
        try {
          await AuthService().loginWithEmail(email, cleanPass);
          isPasswordValid = true;

          // Sync password in Firestore if it was changed
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
          debugPrint('Organisation_LoginPage: Firebase Auth note: $authErr');
        }
      }

      if (!isPasswordValid) {
        _showError('The password you entered is incorrect');
        return;
      }

      final String? referralCode = userData['referralCode']?.toString() ??
          userData['orgReferralCode']?.toString();

      // Write organization info to AuthService
      await AuthService().login(UserRole.organization, {
        'username': actualUsername,
        'dynamicPath': dynamicPath,
        'org_name': storedOrgName,
        'org_doc_path': fullConfigPath,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
      });

      // Refresh FirestoreService cache
      await FirestoreService.initialize();

      // Synchronize branding details
      if (dynamicPath != null && dynamicPath != 'uninitialized') {
        try {
          await AppTheme.syncWithFirestore(dynamicPath);
        } catch (_) {}
      }

      // Save FCM token for push notifications
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
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
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
