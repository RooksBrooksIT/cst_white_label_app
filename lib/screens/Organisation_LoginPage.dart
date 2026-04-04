import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Organisation_RegistrationPage.dart';
import '../services/firestore_service.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../utils/firestore_error_handler.dart';

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
  String? _tempOrgName;
  String? _tempLogoUrl;

  // SharedPreferences keys - ORGANIZATION specific
  static const String _isLoggedInKey = 'org_isLoggedIn';
  static const String _usernameKey = 'org_username';
  static const String _orgPathKey = 'org_dynamic_path';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OrganizationDashboard(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Query the globalUsers mapping directly by Doc ID (username)
      final userDoc = await FirebaseFirestore.instance
          .collection('globalUsers')
          .doc(username)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Validate password locally
        if (userData['password'] != password) {
          _showError('Invalid username or password');
          return;
        }

        // Write organization info to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final String? storedOrgName = userData['orgName'] as String?;
        final String dynamicPath = userData['dynamicPath'] ?? '';
        final String fullConfigPath =
            userData['fullConfigPath'] ??
            'organisation/$dynamicPath/admin/data';

        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_usernameKey, username);
        await prefs.setString(_orgPathKey, dynamicPath);
        if (storedOrgName != null) {
          await prefs.setString('org_name', storedOrgName);
        }
        await prefs.setString('org_doc_path', fullConfigPath);

        // Refresh FirestoreService cache
        await FirestoreService.initialize();

        // Synchronize branding details
        await AppTheme.syncWithFirestore(dynamicPath);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OrganizationDashboard(),
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      onBack: () => Navigator.pop(context),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header or Org Logo
              if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: colorScheme.outline, width: 2),
                    image: DecorationImage(
                      image: NetworkImage(_tempLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.business_center_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                _tempOrgName ?? 'Organization Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your credentials to continue',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),

              GlassCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      GlassButton(
                        label: 'LOGIN',
                        isLoading: _isLoading,
                        onPressed: _login,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const OrganisationRegistrationPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Register Now',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
