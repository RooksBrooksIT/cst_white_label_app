import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Customer amber accent
const _kAccent = Color(0xFFF59E0B);
const _kAccentDark = Color(0xFFB45309);

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  _CustomerLoginPageState createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  static const String _isLoggedInKey = 'cust_isLoggedIn';
  static const String _ownerNameKey = 'cust_ownerName';
  static const String _siteIdKey = 'cust_siteId';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    if (isLoggedIn && mounted) {
      final ownerName = prefs.getString(_ownerNameKey) ?? '';
      final siteId = prefs.getString(_siteIdKey) ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CustomerDashboardPage(ownerName: ownerName, ownerPhoneNumber: '', siteId: siteId)),
      );
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .where('ownerName', isEqualTo: _usernameController.text.trim())
            .where('ownerPhoneNumber', isEqualTo: _passwordController.text.trim())
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_ownerNameKey, _usernameController.text.trim());
          await prefs.setString(_siteIdKey, querySnapshot.docs.first['siteId']);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDashboardPage(
                  ownerName: _usernameController.text.trim(),
                  ownerPhoneNumber: _passwordController.text.trim(),
                  siteId: querySnapshot.docs.first['siteId'],
                ),
              ),
            );
          }
        } else {
          _showError('Invalid name or phone number');
        }
      } catch (e) {
        _showError('Login failed. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFF59E0B)]),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
                    ),
                    const SizedBox(height: 28),
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.3))), child: const Icon(Icons.person_rounded, color: Colors.white, size: 32)),
                    const SizedBox(height: 16),
                    const Text('Customer Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('View your project status & reports', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                  ]),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Form(
                          key: _formKey,
                          child: Column(children: [
                            // Info chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: _kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Icon(Icons.info_outline_rounded, color: _kAccentDark, size: 18),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Use your registered name and 10-digit phone number', style: TextStyle(fontSize: 12, color: _kAccentDark))),
                              ]),
                            ),
                            const SizedBox(height: 20),
                            _buildField(controller: _usernameController, label: 'Owner Name', icon: Icons.person_outline_rounded, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              keyboardType: TextInputType.number,
                              obscureText: !_showPassword,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length != 10) return 'Must be exactly 10 digits';
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: const Icon(Icons.phone_rounded, color: _kAccent, size: 22),
                                suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _kAccent, size: 20), onPressed: () => setState(() => _showPassword = !_showPassword)),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF92400E), Color(0xFFF59E0B)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))]),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, required String? Function(String?) validator}) {
    return TextFormField(
      controller: controller, validator: validator,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF64748B)), prefixIcon: Icon(icon, color: _kAccent, size: 22), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
    );
  }
}
