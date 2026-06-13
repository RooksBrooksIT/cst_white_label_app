import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_account_dashboard.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/firestore_error_handler.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class ConfigLoginPage extends StatefulWidget {
  const ConfigLoginPage({super.key});

  @override
  State<ConfigLoginPage> createState() => _ConfigLoginPageState();
}

class _ConfigLoginPageState extends State<ConfigLoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _tempOrgName;
  String? _tempLogoUrl;
  String? _actualReferralCode;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    String resolvedPath,
  ) async {
    await AuthService().login(UserRole.manager, {
      'username': username,
      'password': password,
      'orgId': orgId,
      'config_org_doc_path': resolvedPath,
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final referralCode =
            _actualReferralCode ?? _referralController.text.trim();

        // 1. Validate Referral Code by searching across all admin/referal documents
        final orgId = await FirestoreService.findOrgIdByReferralCode(
          referralCode,
        );

        if (orgId == null) {
          if (context.mounted) _showErrorDialog('Invalid Referral Code');
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
        final querySnapshot = await configCollection
            .where('UserName', isEqualTo: _usernameController.text.trim())
            .where('Password', isEqualTo: _passwordController.text.trim())
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final String resolvedPath = 'organisation/$orgId/data/admin';
          await _saveLoginCredentials(
            _usernameController.text.trim(),
            _passwordController.text.trim(),
            orgId,
            resolvedPath,
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
              MaterialPageRoute(
                builder: (context) => const ConfigAccountDashboard(),
              ),
              (route) => false,
            );
          }
        } else {
          if (!mounted) return;
          _showErrorDialog('Invalid username or password');
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
  }

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1024;
    bool isDesktop = screenWidth >= 1024;

    double horizontalPadding = isDesktop ? 40 : (isTablet ? 32 : 24);
    double maxContentWidth = 500;

    return GlassScaffold(
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Header or Org Logo
                if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                  Container(
                    width: isDesktop ? 110 : (isTablet ? 95 : 80),
                    height: isDesktop ? 110 : (isTablet ? 95 : 80),
                    padding: EdgeInsets.all(isDesktop ? 10 : (isTablet ? 9 : 8)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: colorScheme.outline, width: 2),
                    ),
                    child: Image.network(
                      _tempLogoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.manage_accounts_rounded,
                        size: isDesktop ? 70 : (isTablet ? 65 : 60),
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Container(
                    width: isDesktop ? 110 : (isTablet ? 95 : 80),
                    height: isDesktop ? 110 : (isTablet ? 95 : 80),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      size: isDesktop ? 52 : (isTablet ? 46 : 40),
                      color: colorScheme.primary,
                    ),
                  ),
                SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
                Text(
                  _tempOrgName ?? 'Manager Login',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isDesktop ? 30 : (isTablet ? 28 : 26),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : (isTablet ? 36 : 32)),

                GlassCard(
                  padding: EdgeInsets.all(isDesktop ? 28 : (isTablet ? 26 : 24)),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GlassTextField(
                          controller: _referralController,
                          label: 'Referral Code / Org Name',
                          icon: Icons.business_rounded,
                          enabled:
                              _actualReferralCode == null && _tempOrgName == null,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: isDesktop ? 24 : (isTablet ? 22 : 20)),
                        GlassTextField(
                          controller: _usernameController,
                          label: 'Username',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: isDesktop ? 24 : (isTablet ? 22 : 20)),
                        GlassTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: isDesktop ? 36 : (isTablet ? 34 : 32)),
                        SizedBox(
                          width: double.infinity,
                          child: GlassButton(
                            label: 'LOGIN',
                            isLoading: _isLoading,
                            onPressed: _login,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 28 : (isTablet ? 26 : 24)),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
