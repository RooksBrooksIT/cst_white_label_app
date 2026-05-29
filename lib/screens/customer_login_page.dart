import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_dashboard.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/firestore_error_handler.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  _CustomerLoginPageState createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  bool _isLoading = false;
  String? _tempOrgName;
  String? _tempLogoUrl;
  String? _actualReferralCode;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
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
    if (auth.isLoggedIn && auth.userRole == UserRole.customer && mounted) {
      final data = auth.userData;
      final ownerName = data['ownerName'] ?? '';
      final siteId = data['siteId'] ?? '';

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerDashboardPage(
              ownerName: ownerName,
              ownerPhoneNumber: '',
              siteId: siteId,
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
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final referralCode =
            _actualReferralCode ?? _referralController.text.trim();

        // Validate referral code by searching across all admin/referal documents
        final orgId = await FirestoreService.findOrgIdByReferralCode(
          referralCode,
        );

        if (orgId == null) {
          if (context.mounted) _showError('Invalid Referral Code');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cust_org_path', orgId);
        final String resolvedPath = 'organisation/$orgId/data/admin';
        await prefs.setString('cust_org_doc_path', resolvedPath);

        await FirestoreService.initialize();

        final projectsCollection = await FirestoreService.projects;
        final querySnapshot = await projectsCollection
            .where('ownerName', isEqualTo: _usernameController.text.trim())
            .where(
              'ownerPhoneNumber',
              isEqualTo: _passwordController.text.trim(),
            )
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          final siteId = data['siteId'] ?? '';

          await AuthService().login(UserRole.customer, {
            'ownerName': _usernameController.text.trim(),
            'siteId': siteId,
            'orgId': orgId,
            'cust_org_doc_path': resolvedPath,
          });

          if (mounted) {
            _showSuccess('Login Successful!');
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerDashboardPage(
                      ownerName: _usernameController.text.trim(),
                      ownerPhoneNumber: _passwordController.text.trim(),
                      siteId: siteId,
                    ),
                  ),
                  (route) => false,
                );
              }
            });
          }
        } else {
          if (context.mounted) _showError('Invalid username or phone number');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        if (context.mounted) {
          FirestoreErrorHandler.handleError(context, e, title: 'Login Error');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: colorScheme.outline, width: 2),
                  ),
                  child: Image.network(
                    _tempLogoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_rounded,
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
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _tempOrgName ?? 'Customer Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
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
                        controller: _referralController,
                        label: 'Referral Code / Org Name',
                        icon: Icons.business_rounded,
                        enabled:
                            _actualReferralCode == null && _tempOrgName == null,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Owner Name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Phone Number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
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
            ],
          ),
        ),
      ),
    );
  }
}
