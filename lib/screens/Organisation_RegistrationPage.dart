import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
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
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      title: 'Register Organization',
      onBack: _goBack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStepIndicator(theme),
                const SizedBox(height: 24),
                FadeTransition(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 0;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isActive = activeStep == index;
          final isDone = activeStep > index;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step circle and label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? colorScheme.primary
                          : (isActive
                                ? colorScheme.primary
                                : colorScheme.surfaceVariant),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              '${index + 1}',
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
                    steps[index],
                    style: TextStyle(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Connector line
              if (index < steps.length - 1)
                Container(
                  width: 40,
                  height: 2,
                  margin: const EdgeInsets.only(
                    bottom: 24,
                    left: 12,
                    right: 12,
                  ),
                  decoration: BoxDecoration(
                    color: activeStep > index
                        ? colorScheme.primary
                        : colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Heading
        Text(
          'Create Your Profile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please provide your organization details below.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Professional Form Container
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Organization Name'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _orgNameController,
                hint: 'Enter organization name',
                icon: Icons.business_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Organization name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Corporate Email'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _emailController,
                hint: 'e.g. contact@org.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Contact Number'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _phoneController,
                hint: 'Enter mobile number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Admin Username'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _usernameController,
                hint: 'Choose a unique username',
                icon: Icons.person_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Password'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _passwordController,
                hint: 'Min. 8 characters',
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
                  return null;
                },
              ),
              // Strength Indicator
              if (_passwordStrength.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _strengthColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _passwordStrength == 'Weak'
                              ? 0.33
                              : (_passwordStrength == 'Moderate' ? 0.66 : 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _strengthColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _passwordStrength,
                        style: TextStyle(
                          color: _strengthColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _buildFieldLabel('Confirm Password'),
              const SizedBox(height: 8),
              _buildProfessionalField(
                controller: _confirmPasswordController,
                hint: 'Re-enter password',
                icon: Icons.lock_clock_rounded,
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
              const SizedBox(height: 40),

              // Navigation Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goToNextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildProfessionalField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
