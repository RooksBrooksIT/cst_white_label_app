import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/responsive.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  _CustomerLoginPageState createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  late AnimationController _errorController;
  late Animation<Offset> _errorSlideAnimation;
  late Animation<double> _errorFadeAnimation;

  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successFadeAnimation;

  // SharedPreferences keys - CUSTOMER specific
  static const String _isLoggedInKey = 'cust_isLoggedIn';
  static const String _ownerNameKey = 'cust_ownerName';
  static const String _siteIdKey = 'cust_siteId';
  static const String _orgPathKey = 'cust_org_path';

  @override
  void initState() {
    super.initState();

    _checkLoginStatus();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuint),
    );

    _translateAnimation = Tween<double>(
      begin: 80,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _errorSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _errorController,
            curve: Curves.fastOutSlowIn,
          ),
        );

    _errorFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _errorController, curve: Curves.easeIn));

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _successScaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _successFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeInCirc),
    );
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn) {
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
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _errorController.dispose();
    _successController.dispose();
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
          _showErrorAnimation('Invalid Referral Code');
          return;
        }

        final dynamicPath = referralDoc.data()?['dynamicPath'] as String?;
        if (dynamicPath == null) {
          _showErrorAnimation('Organization configuration error');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_orgPathKey, dynamicPath);
        
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
            _showSuccessAnimation('Login Successful!');
            Future.delayed(const Duration(milliseconds: 1500), () {
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
            });
          }
        } else {
          _showErrorAnimation('Invalid username or phone number');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        _showErrorAnimation('An error occurred. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorAnimation(String message) {
    _errorController.reset();
    _errorController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SlideTransition(
          position: _errorSlideAnimation,
          child: FadeTransition(
            opacity: _errorFadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessAnimation(String message) {
    _successController.reset();
    _successController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ScaleTransition(
          scale: _successScaleAnimation,
          child: FadeTransition(
            opacity: _successFadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, '/authSelection'),
        ),
        title: Text(
          'Customer Login', 
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.fontSize(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.scaleH(context, 0.05),
                        vertical: Responsive.scaleV(context, 0.05),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _translateAnimation.value),
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: _buildLoginCard(theme, primaryColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginCard(ThemeData theme, Color primaryColor) {
    return Card(
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Container(
        width: Responsive.isMobile(context) ? double.infinity : 450,
        padding: EdgeInsets.all(Responsive.scaleH(context, 0.08)),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_rounded, 
                  size: Responsive.scaleH(context, 0.15), 
                  color: primaryColor,
                ),
              ),
              SizedBox(height: Responsive.scaleV(context, 0.02)),
              Text(
                'Customer Sign In',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 24), 
                  fontWeight: FontWeight.bold, 
                  color: primaryColor,
                ),
              ),
              SizedBox(height: Responsive.scaleV(context, 0.04)),
              _buildTextField(
                controller: _referralController,
                label: 'Referral Code',
                icon: Icons.business,
                theme: theme,
                primaryColor: primaryColor,
              ),
              SizedBox(height: Responsive.scaleV(context, 0.02)),
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.person,
                theme: theme,
                primaryColor: primaryColor,
              ),
              SizedBox(height: Responsive.scaleV(context, 0.02)),
              _buildTextField(
                controller: _passwordController,
                label: 'Phone Number',
                icon: Icons.phone,
                isPassword: true,
                keyboardType: TextInputType.phone,
                theme: theme,
                primaryColor: primaryColor,
              ),
              SizedBox(height: Responsive.scaleV(context, 0.04)),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          'LOGIN', 
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1.2,
                            fontSize: Responsive.fontSize(context, 16),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    required ThemeData theme,
    required Color primaryColor,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_showPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: primaryColor),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
        filled: true,
        fillColor: theme.brightness == Brightness.light ? Colors.grey[50] : Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isPassword && v.length < 10) return 'Enter valid phone number';
        return null;
      },
    );
  }
}
