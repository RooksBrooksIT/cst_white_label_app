import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/responsive.dart';
import 'branding_screen.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';

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

  String _passwordStrength = '';
  Color _strengthColor = Colors.transparent;

  void _checkPasswordStrength(String value) {
    if (value.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _strengthColor = Colors.transparent;
      });
      return;
    }

    int score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) score++;

    setState(() {
      if (score <= 2) {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.redAccent;
      } else if (score <= 4) {
        _passwordStrength = 'Moderate';
        _strengthColor = Colors.orangeAccent;
      } else {
        _passwordStrength = 'Strong';
        _strengthColor = Colors.greenAccent;
      }
    });
  }

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
    final theme = Theme.of(context);

    return GlassScaffold(
      title: 'Register Organization',
      onBack: _goBack,
      body: Column(
        children: [
          const SizedBox(height: 24),
          // Step Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStepIndicator(theme),
          ),
          const SizedBox(height: 12),
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
                child: _buildStep1(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 0;
    final primaryColor = theme.primaryColor;
    final colorScheme = theme.colorScheme;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: colorScheme.outlineVariant,
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive ? primaryColor : colorScheme.surface,
                border: Border.all(
                  color: isDone || isActive
                      ? primaryColor
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              steps[stepIndex],
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text('Organization Details', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Complete your organization profile to get started.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Form
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GlassTextField(
                    controller: _orgNameController,
                    label: 'Organization Name',
                    icon: Icons.apartment_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Organization name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _emailController,
                    label: 'Corporate Email',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Corporate email is required';
                      }
                      // Basic email validation regex
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid corporate email (e.g. name@company.com)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone number is required';
                      }
                      if (value.length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _usernameController,
                    label: 'Admin Username',
                    icon: Icons.person_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Admin username is required';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _passwordController,
                    label: 'Secure Password',
                    icon: Icons.lock_rounded,
                    isPassword: true,
                    onChanged: _checkPasswordStrength,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Add at least one uppercase letter';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'Add at least one lowercase letter';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Add at least one number';
                      }
                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                        return 'Add at least one special character';
                      }
                      return null;
                    },
                  ),
                  if (_passwordStrength.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Password Strength: $_passwordStrength',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _strengthColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value:
                                  _passwordStrength == 'Weak'
                                      ? 0.33
                                      : (_passwordStrength == 'Moderate'
                                          ? 0.66
                                          : 1.0),
                              backgroundColor: theme.colorScheme.outlineVariant
                                  .withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _strengthColor,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Action Buttons
          GlassButton(label: 'CONTINUE', onPressed: _goToNextStep),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _goBack,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
