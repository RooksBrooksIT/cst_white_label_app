import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Organisation_RegistrationPage.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../utils/firestore_error_handler.dart';
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
    if (auth.isLoggedIn && auth.userRole == UserRole.organization && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrganizationDashboard()),
      );
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

      // Query for the organization admin/data document by username
      final userQuery = await FirebaseFirestore.instance
          .collectionGroup('admin')
          .where('username', isEqualTo: username)
          .get();

      // Find the document named 'data' in the query results
      QueryDocumentSnapshot<Map<String, dynamic>>? dataDoc;
      for (var doc in userQuery.docs) {
        if (doc.id == 'data') {
          dataDoc = doc;
          break;
        }
      }

      Map<String, dynamic>? userData;
      String? dynamicPath;
      String? fullConfigPath;

      if (dataDoc != null) {
        userData = dataDoc.data();
        // The OrgID is the document ID of the parent organization
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
        // Validate password
        if (userData['password'] != password) {
          _showError('Invalid username or password');
          return;
        }

        final String? storedOrgName = userData['orgName'] as String?;

        // Write organization info to AuthService
        await AuthService().login(UserRole.organization, {
          'username': username,
          'dynamicPath': dynamicPath,
          'org_name': storedOrgName,
          'org_doc_path': fullConfigPath,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      onBack: () => Navigator.pop(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header or Org Logo
              if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(8), // Small padding
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: colorScheme.outline, width: 2),
                  ),
                  child: Image.network(
                    _tempLogoUrl!,
                    fit: BoxFit.contain, // Use contain to prevent cropping
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.business_rounded,
                      size: 60,
                      color: colorScheme.primary,
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _tempOrgName ?? 'Organization Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: Responsive.fontSize(context, 26),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              GlassCard(
                padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
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

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
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
                        fontSize: 14,
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
