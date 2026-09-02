import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/firestore_error_handler.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/screens/manager/config_account_dashboard.dart';
import 'package:demo_cst/screens/common/portal_loading_screen.dart';

class ConfigLoginPage extends StatefulWidget {
  const ConfigLoginPage({super.key});

  @override
  State<ConfigLoginPage> createState() => _ConfigLoginPageState();
}

class _ConfigLoginPageState extends State<ConfigLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _tempOrgName;
  String? _tempLogoUrl;
  String? _actualReferralCode;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Check if user is already logged in
  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch org details if available
    setState(() {
      _tempOrgName = prefs.getString('temp_org_name');
      _tempLogoUrl = prefs.getString('temp_logo_url');
      _actualReferralCode = prefs.getString('temp_referral_code');

      if (_tempOrgName != null) {
        _referralController.text = _tempOrgName!;
      } else if (_actualReferralCode != null) {
        _referralController.text = _actualReferralCode!;
      }
    });

    final auth = AuthService();
    if (auth.isLoggedIn && auth.userRole == UserRole.manager) {
      final orgId = auth.userData['orgId'];
      if (orgId != null && orgId.toString().isNotEmpty) {
        await AppTheme.syncWithFirestore(orgId.toString());
      }
      if (mounted) {
        // Auto-navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ConfigAccountDashboard(),
          ),
        );
      }
    }
  }

  // Save login credentials
  Future<void> _saveLoginCredentials(
    String username,
    String password,
    String orgId,
    String resolvedPath, {
    Map<String, dynamic>? extraData,
  }) async {
    final Map<String, dynamic> data = {
      'username': username,
      'password': password,
      'orgId': orgId,
      'config_org_doc_path': resolvedPath,
    };
    if (extraData != null) {
      data.addAll(extraData);
    }
    await AuthService().login(UserRole.manager, data);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    AppTheme.showErrorToast(context, message);
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final referralCode =
          _actualReferralCode ?? _referralController.text.trim();

      // 1. Validate Referral Code by searching across all admin/referal documents
      final orgId = await FirestoreService.findOrgIdByReferralCode(
        referralCode,
      );

      if (orgId == null) {
        if (mounted) _showError('Invalid Referral Code');
        return;
      }

      // 2. Save org path temporarily for FirestoreService
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'config_org_path',
        orgId,
      ); // Store the ID for FirestoreService
      final String resolvedPath = 'organisation/$orgId/data/admin';
      await prefs.setString('config_org_doc_path', resolvedPath);

      // Refresh FirestoreService cache
      await FirestoreService.initialize();

      // Sync branding details
      await AppTheme.syncWithFirestore(orgId);

      // 3. Authenticate within organization
      final configCollection = FirestoreService.configUsers;
      var querySnapshot = await configCollection
          .where('UserName', isEqualTo: _usernameController.text.trim())
          .where('Password', isEqualTo: _passwordController.text.trim())
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Check 'manager' collection as well
        querySnapshot = await FirestoreService.getCollection('manager')
            .where('UserName', isEqualTo: _usernameController.text.trim())
            .where('Password', isEqualTo: _passwordController.text.trim())
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final docData = querySnapshot.docs.first.data();
        final String resolvedPath = 'organisation/$orgId/data/admin';
        await _saveLoginCredentials(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
          orgId,
          resolvedPath,
          extraData: docData,
        );

        // Save FCM token for push notifications
        await NotificationService.saveToken(
          userId: _usernameController.text.trim(),
          userType: 'manager',
          userName: _usernameController.text.trim(),
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
      } else {
        if (!mounted) return;
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
    bool enabled = true,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
      disabledBorder: OutlineInputBorder(
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
        final bool isReferralFieldEnabled =
            _actualReferralCode == null && _tempOrgName == null;

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
                                Icons.manage_accounts_rounded,
                                size: 14,
                                color: darkAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MANAGER PORTAL',
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
                                  Icons.manage_accounts_rounded,
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
                                  Icons.manage_accounts_rounded,
                                  size: isDesktop ? 34 : (isTablet ? 30 : 28),
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),

                        // Title & Subtitle
                        Text(
                          _tempOrgName ?? 'Manager Login',
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
                          'Sign in to manage projects, materials & sites',
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
                                // Referral Code / Org Name
                                _buildFieldLabel('Organization / Referral Code'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _referralController,
                                  enabled: isReferralFieldEnabled,
                                  style: TextStyle(
                                    color: isReferralFieldEnabled
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF475569),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Enter referral code or org name',
                                    prefixIcon: Icons.business_rounded,
                                    primaryColor: primaryColor,
                                    enabled: isReferralFieldEnabled,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 18),

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
                                const SizedBox(height: 24),

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
