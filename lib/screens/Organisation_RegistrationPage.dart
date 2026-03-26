import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import 'branding_screen.dart';

// Form screen for organization registration details

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
    // Force Light Mode colors for this specific page as per user request
    const backgroundColor = Colors.white;
    const textColor = Color(0xFF0F172A); // Slate 900
    const secondaryTextColor = Color(0xFF64748B); // Slate 500

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Register Organization',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Step Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildStepIndicator(textColor, secondaryTextColor),
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
                child: _buildStep1(textColor, secondaryTextColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(Color textColor, Color secondaryTextColor) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 0;
    const primaryColor = Color(0xFFF59E0B);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFFE2E8F0), // Slate 200
              ),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isActive = activeStep == stepIndex;
        final isDone = activeStep > stepIndex;

        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive ? primaryColor : Colors.white,
                border: Border.all(
                  color: isDone || isActive
                      ? primaryColor
                      : const Color(0xFFE2E8F0),
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : secondaryTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 12,
                color: isActive ? textColor : secondaryTextColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStep1(Color textColor, Color secondaryTextColor) {
    const primaryColor = Color(0xFFF59E0B);
    const inputFillColor = Color(0xFFF8FAFC); // Slate 50
    const borderColor = Color(0xFFE2E8F0); // Slate 200

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Organization Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your organization profile to get started.',
            style: TextStyle(fontSize: 15, color: secondaryTextColor),
          ),
          const SizedBox(height: 32),

          // Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildField(
                  controller: _orgNameController,
                  label: 'Organization Name',
                  icon: Icons.apartment_rounded,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _emailController,
                  label: 'Corporate Email',
                  icon: Icons.email_rounded,
                  type: TextInputType.emailAddress,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_rounded,
                  type: TextInputType.phone,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _usernameController,
                  label: 'Admin Username',
                  icon: Icons.person_rounded,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _passwordController,
                  label: 'Secure Password',
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  showPassword: _showPassword,
                  onPasswordToggle: () =>
                      setState(() => _showPassword = !_showPassword),
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  showPassword: _showPassword,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Action Buttons
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: TextButton(
              onPressed: _goBack,
              style: TextButton.styleFrom(foregroundColor: secondaryTextColor),
              child: const Text(
                'CANCEL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool isPassword = false,
    bool? showPassword,
    VoidCallback? onPasswordToggle,
    required Color fillColor,
    required Color borderColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: isPassword && (showPassword == false),
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword! ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
                onPressed: onPasswordToggle,
              )
            : null,
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      validator: (v) => v!.isEmpty ? 'Required field' : null,
    );
  }

}
