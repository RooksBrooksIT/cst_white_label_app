import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'Organization_Dashboard.dart';

class OrganisationRegistrationPage extends StatefulWidget {
  const OrganisationRegistrationPage({super.key});

  @override
  _OrganisationRegistrationPageState createState() =>
      _OrganisationRegistrationPageState();
}

class _OrganisationRegistrationPageState extends State<OrganisationRegistrationPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuint),
    );

    _translateAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _orgNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final String orgName = _orgNameController.text.trim();
        final String username = _usernameController.text.trim().toLowerCase();
        final String password = _passwordController.text.trim();
        final String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        
        // 1. Check if organization/username already exists in central lookup
        final userDoc = await FirebaseFirestore.instance
            .collection('organizationUser')
            .doc(username)
            .get();

        if (userDoc.exists) {
          _showError('Username already taken. Please choose another.');
          return;
        }

        // 2. Generate referral code
        final String referralCode = await FirestoreService.generateUniqueReferralCode();

        // 3. Create paths
        final String rootCollection = '${orgName.replaceAll(' ', '_')}_$dateStr';
        final String dynamicPath = '$rootCollection/data/admin/User';

        // 4. Create Organization data in transaction to ensure consistency
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // A. Create admin document
          transaction.set(FirebaseFirestore.instance.doc(dynamicPath), {
            'orgName': orgName,
            'username': username,
            'password': password,
            'referralCode': referralCode,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // B. Create central lookup record
          transaction.set(FirebaseFirestore.instance.collection('organizationUser').doc(username), {
            'orgName': orgName,
            'dynamicPath': dynamicPath,
            'username': username,
            'password': password,
          });

          // C. Create referral code mapping
          transaction.set(FirebaseFirestore.instance.collection('referralCodes').doc(referralCode), {
            'orgName': orgName,
            'dynamicPath': dynamicPath,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        // 5. Auto-login and navigate
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('org_isLoggedIn', true);
        await prefs.setString('org_username', username);
        await prefs.setString('org_dynamic_path', dynamicPath);
        await prefs.setString('org_name', orgName);
        await prefs.setString('org_doc_path', dynamicPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration successful! Referral Code: $referralCode')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OrganizationDashboard()),
          );
        }
      } catch (e) {
        debugPrint('Registration error: $e');
        _showError('Registration failed. Please try again.');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Organization', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF003768),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF003768), Color(0xFF005A9E)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Transform.translate(
                offset: Offset(0, _translateAnimation.value),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, size: 64, color: Color(0xFF003768)),
                          const SizedBox(height: 16),
                          const Text(
                            'New Organization',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003768)),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _orgNameController,
                            decoration: const InputDecoration(
                              labelText: 'Organization Name',
                              prefixIcon: Icon(Icons.apartment),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Admin Username',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003768),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('REGISTER', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Already have an account? Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
