import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Organisation_RegistrationPage.dart';
import '../services/firestore_service.dart';
import 'Organization_Dashboard.dart';
import '../utils/responsive.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header or Org Logo
              if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: DecorationImage(
                      image: NetworkImage(_tempLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.business_center_rounded,
                    size: 64,
                    color: primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _tempOrgName ?? 'Organization Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              if (_tempOrgName != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Organization Account',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Enter your credentials to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                        ),
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
                    style: TextStyle(color: const Color(0xFF64748B)),
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
