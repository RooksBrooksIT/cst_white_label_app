import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_dashboard.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

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

  // SharedPreferences keys - CUSTOMER specific
  static const String _isLoggedInKey = 'cust_isLoggedIn';
  static const String _ownerNameKey = 'cust_ownerName';
  static const String _siteIdKey = 'cust_siteId';
  static const String _orgPathKey = 'cust_org_path';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn && mounted) {
      final ownerName = prefs.getString(_ownerNameKey) ?? '';
      final siteId = prefs.getString(_siteIdKey) ?? '';

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
        final referralCode = _referralController.text.trim();
        
        final referralDoc = await FirebaseFirestore.instance
            .collection('referralCodes')
            .doc(referralCode)
            .get();

        if (!referralDoc.exists) {
          if (context.mounted) _showError('Invalid Referral Code');
          return;
        }

        final orgId = referralDoc.data()?['dynamicPath'] as String?;
        final fullConfigPath = referralDoc.data()?['fullConfigPath'] as String?;
        if (orgId == null) {
          if (context.mounted) _showError('Organization configuration error');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_orgPathKey, orgId);
        if (fullConfigPath != null) {
          await prefs.setString('cust_org_doc_path', fullConfigPath);
        }
        
        await FirestoreService.initialize();

        final projectsCollection = await FirestoreService.projects;
        final querySnapshot = await projectsCollection
            .where('ownerName', isEqualTo: _usernameController.text.trim())
            .where('ownerPhoneNumber', isEqualTo: _passwordController.text.trim())
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          final siteId = data['siteId'] ?? '';

          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_ownerNameKey, _usernameController.text.trim());
          await prefs.setString(_siteIdKey, siteId);

          if (mounted) {
            _showSuccess('Login Successful!');
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerDashboardPage(
                      ownerName: _usernameController.text.trim(),
                      ownerPhoneNumber: _passwordController.text.trim(),
                      siteId: siteId,
                    ),
                  ),
                );
              }
            });
          }
        } else {
          if (context.mounted) _showError('Invalid username or phone number');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        if (context.mounted) _showError('An error occurred. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
                  Icons.account_balance_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Customer Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Access your project details',
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
                        controller: _referralController,
                        label: 'Referral Code',
                        icon: Icons.business_rounded,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Phone Number',
                        icon: Icons.phone_rounded,
                        isPassword: true,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 10) return 'Enter valid phone number';
                          return null;
                        },
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
            ],
          ),
        ),
      ),
    );
  }
}
