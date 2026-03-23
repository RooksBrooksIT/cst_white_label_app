import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/Organisation_RegistrationPage.dart';
import 'package:demo_cst/utils/responsive.dart';

class Organisation_LoginPage extends StatefulWidget {
  const Organisation_LoginPage({super.key});

  @override
  _Organisation_LoginPageState createState() => _Organisation_LoginPageState();
}

class _Organisation_LoginPageState extends State<Organisation_LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;
  late Animation<Color?> _gradientAnimation;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  late AnimationController _errorController;
  late Animation<Offset> _errorSlideAnimation;
  late Animation<double> _errorFadeAnimation;

  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successFadeAnimation;

  // SharedPreferences keys - ORGANIZATION specific
  static const String _isLoggedInKey = 'org_isLoggedIn';
  static const String _usernameKey = 'org_username';
  static const String _passwordKey = 'org_password';

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

    _gradientAnimation = ColorTween(
      begin: const Color(0xFF003768),
      end: const Color(0xFF003768).withOpacity(0.8),
    ).animate(_controller);

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
      // Navigate automatically to main page without showing login
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const OrganizationDashboard(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      _controller.forward(); // start animations if not logged in
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _errorController.dispose();
    _successController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Organisation Login',
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/authSelection');
          },
        ),
      ),

      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _gradientAnimation.value!,
                  _gradientAnimation.value!.withOpacity(0.8),
                ],
              ),
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(0, _translateAnimation.value),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: _buildLoginCard(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        debugPrint('=== LOGIN DEBUG ===');
        debugPrint(
          'Attempting login with username: "${_usernameController.text.trim()}"',
        );

        // Step 1: Look up user in central organizationUser collection
        final userLookup = await FirebaseFirestore.instance
            .collection('organizationUser')
            .doc(_usernameController.text.trim().toLowerCase())
            .get();

        if (!userLookup.exists) {
          debugPrint('User not found in organizationUser lookup');
          _showErrorAnimation('Invalid username or password');
          return;
        }

        final lookupData = userLookup.data()!;
        final String dynamicPath = lookupData['dynamicPath'] ?? '';
        debugPrint('Dynamic path from lookup: $dynamicPath');

        if (dynamicPath.isEmpty) {
          _showErrorAnimation('Account configuration error. Contact support.');
          return;
        }

        // Step 2: Fetch the full admin document using the dynamic path
        final docSnapshot = await FirebaseFirestore.instance
            .doc(dynamicPath)
            .get();

        debugPrint('Document exists: ${docSnapshot.exists}');

        if (docSnapshot.exists) {
          final userData = docSnapshot.data()!;
          debugPrint('Document path: ${docSnapshot.reference.path}');
          debugPrint('Document fields: ${userData.keys.toList()}');
          debugPrint('Stored username: "${userData['username']}"');
          debugPrint('Stored password: "${userData['password']}"');
          debugPrint('Entered username: "${_usernameController.text.trim()}"');
          debugPrint('Entered password: "${_passwordController.text.trim()}"');

          if (userData['username'] ==
                  _usernameController.text.trim().toLowerCase() &&
              userData['password'] == _passwordController.text.trim()) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_isLoggedInKey, true);
            await prefs.setString(
              _usernameKey,
              _usernameController.text.trim().toLowerCase(),
            );

            // Store the document path and org info for future reference
            await prefs.setString('org_doc_path', docSnapshot.reference.path);
            await prefs.setString(
              'org_name',
              userData['orgName'] ?? lookupData['orgName'] ?? '',
            );
            await prefs.setString('org_dynamic_path', dynamicPath);

            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 800),
                  pageBuilder: (_, __, ___) => const OrganizationDashboard(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                ),
              );
            }
            return;
          }
        }
        _showErrorAnimation('Invalid username or password');
      } catch (e) {
        debugPrint('Login error: $e');
        _showErrorAnimation('Login failed. Please try again.');
      } finally {
        setState(() => _isLoading = false);
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
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF003768), // Primary blue start
                    Color(0xFF005A9E), // Accent lighter blue end
                  ],
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
        duration: const Duration(seconds: 3),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final usernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              final primary = theme.primaryColor;
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_reset,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white54),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    _showErrorAnimation(
                                      'Passwords do not match',
                                    );
                                    return;
                                  }

                                  setState(() => isUpdating = true);

                                  try {
                                    // Query across all org admin subcollections
                                    final querySnapshot =
                                        await FirebaseFirestore.instance
                                            .collectionGroup('admin')
                                            .where(
                                              'username',
                                              isEqualTo: usernameController.text
                                                  .trim(),
                                            )
                                            .get();

                                    if (querySnapshot.docs.isNotEmpty) {
                                      final docRef =
                                          querySnapshot.docs.first.reference;

                                      // Update password directly on the admin document
                                      await docRef.update({
                                        'password': newPasswordController.text
                                            .trim(),
                                      });

                                      // Update password in the central lookup collection
                                      // Note: the username in lookup is always lowercase
                                      await FirebaseFirestore.instance
                                          .collection('organizationUser')
                                          .doc(usernameController.text.trim().toLowerCase())
                                          .update({
                                            'password': newPasswordController.text.trim(),
                                          });

                                      Navigator.pop(context);
                                      _showSuccessAnimation(
                                        'Password updated successfully',
                                      );
                                    } else {
                                      _showErrorAnimation('Username not found');
                                    }
                                  } catch (e) {
                                    _showErrorAnimation(
                                      'Failed to update password. Please try again.',
                                    );
                                  } finally {
                                    setState(() => isUpdating = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginCard() {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Material(
      elevation: 20,
      borderRadius: BorderRadius.circular(25),
      shadowColor: Colors.black.withOpacity(0.2),
      child: Container(
        width: Responsive.isMobile(context) ? screenWidth * 0.85 : 350,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.isMobile(context) ? 40 : 50,
          horizontal: Responsive.isMobile(context) ? 28 : 32,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.97),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Text(
                    'Organisation Login',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 24),
                      fontWeight: FontWeight.bold,
                      color: primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.fastOutSlowIn,
                        ),
                      ),
                  child: const Text(
                    'Sign in to continue',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 32),
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(-0.5, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                  child: TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(
                        Icons.person,
                        color: primary,
                        size: 24,
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light 
                          ? Colors.grey[50] 
                          : Colors.grey[900],
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
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.5, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(
                        Icons.lock,
                        color: primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: primary,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light 
                          ? Colors.grey[50] 
                          : Colors.grey[900],
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
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.6, 1, curve: Curves.elasticOut),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: primary.withOpacity(0.3),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.black54),
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
                          'Register',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
