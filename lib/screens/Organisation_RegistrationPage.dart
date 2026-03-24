import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'branding_screen.dart';

class OrganisationRegistrationPage extends StatefulWidget {
  const OrganisationRegistrationPage({super.key});

  @override
  _OrganisationRegistrationPageState createState() =>
      _OrganisationRegistrationPageState();
}

class _OrganisationRegistrationPageState
    extends State<OrganisationRegistrationPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  // Step 1 - Details
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuint),
    );
    _translateAnimation = Tween<double>(
      begin: 30,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _orgNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandingScreen(
          orgName: _orgNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          username: _usernameController.text.trim().toLowerCase(),
          password: _passwordController.text.trim(),
          dateStr: DateFormat('dd-MM-yyyy').format(DateTime.now()),
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF001D3D), Color(0xFF003768), Color(0xFF005A9E)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Register Organization',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Step Indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                child: _buildStepIndicator(),
              ),
              // Page Content
              Expanded(
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: AnimatedBuilder(
                    animation: _translateAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _translateAnimation.value),
                      child: child,
                    ),
                    child: _buildStep1(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 0; // Always on step 1 here
    
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          return Expanded(
            child: Container(
              height: 2,
              color: Colors.white.withOpacity(0.2),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isDone = activeStep > stepIndex;
        final isActive = activeStep == stepIndex;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive
                    ? const Color(0xFF017FDF)
                    : Colors.white.withOpacity(0.15),
                border: Border.all(
                  color: isDone || isActive
                      ? const Color(0xFF017FDF)
                      : Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 11,
                color: isActive || isDone ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                 BoxShadow(
                  color: const Color(0xFF017FDF).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.business_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Organization Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fill in your organization information',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildField(
                    controller: _orgNameController,
                    label: 'Organization Name',
                    icon: Icons.apartment_rounded,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _emailController,
                    label: 'Corporate Email',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _usernameController,
                    label: 'Admin Username',
                    icon: Icons.person_rounded,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _passwordController,
                    label: 'Secure Password',
                    icon: Icons.lock_rounded,
                    isPassword: true,
                    showPassword: _showPassword,
                    onTogglePassword: () =>
                        setState(() => _showPassword = !_showPassword),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    showPassword: _showPassword,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPrimaryButton(label: 'NEXT', onPressed: _goToNextStep),
          const SizedBox(height: 12),
          _buildSecondaryButton(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF017FDF),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !showPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.65), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.white.withOpacity(0.65),
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF017FDF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }
}
