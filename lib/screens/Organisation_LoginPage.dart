import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Organisation_RegistrationPage.dart';
import '../services/firestore_service.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

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

  // SharedPreferences keys - ORGANIZATION specific
  static const String _isLoggedInKey = 'org_isLoggedIn';
  static const String _usernameKey = 'org_username';
  static const String _orgPathKey = 'org_dynamic_path';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
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

      // Query organizationUser collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('organizationUser')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docSnapshot = querySnapshot.docs.first;
        final userData = docSnapshot.data();
        
        // Write organization info to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final String? storedOrgName = userData['orgName'] as String?;
        // New Path Logic: dynamicPath is the OrgID, fullConfigPath is the doc path
        final String dynamicPath = userData['dynamicPath'] ?? ''; 
        final String fullConfigPath = userData['fullConfigPath'] ?? 'organisation/$dynamicPath/admin/data';

        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_usernameKey, username);
        await prefs.setString(_orgPathKey, dynamicPath);
        if (storedOrgName != null) {
          await prefs.setString('org_name', storedOrgName);
        }
        await prefs.setString('org_doc_path', fullConfigPath);

        // Refresh FirestoreService cache
        await FirestoreService.initialize();

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
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return GlassScaffold(
      onBack: () => Navigator.pushReplacementNamed(context, '/authSelection'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Organization Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your credentials to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_rounded,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_rounded,
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrganisationRegistrationPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Register Now',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
