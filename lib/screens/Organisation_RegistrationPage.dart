import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/responsive.dart';
import 'branding_screen.dart';
import '../services/firestore_service.dart';

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

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

  Future<void> _goToNextStep() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Uniqueness checks
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();
      final String username = _usernameController.text.trim().toLowerCase();

      final results = await Future.wait([
        FirestoreService.isEmailUnique(email),
        FirestoreService.isPhoneUnique(phone),
        FirestoreService.isUsernameUnique(username),
      ]);

      final bool isEmailUnique = results[0];
      final bool isPhoneUnique = results[1];
      final bool isUsernameUnique = results[2];

      if (!isEmailUnique) {
        _showError('Email address already registered');
        setState(() => _isLoading = false);
        return;
      }

      if (!isPhoneUnique) {
        _showError('Phone number already registered');
        setState(() => _isLoading = false);
        return;
      }

      if (!isUsernameUnique) {
        _showError('Username is already taken');
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrandingScreen(
              orgName: _orgNameController.text.trim(),
              email: email,
              phone: phone,
              username: username,
              password: _passwordController.text.trim(),
              dateStr: DateFormat('dd-MM-yyyy').format(DateTime.now()),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Registration check error: $e');
      String errorMsg = 'Error checking availability. Please try again.';

      if (e is FirebaseException) {
        if (e.code == 'failed-precondition' ||
            e.message?.contains('index') == true) {
          errorMsg = 'Firestore index required. Click to copy creation link.';
        } else if (e.code == 'permission-denied') {
          errorMsg = 'Permission denied. Please check security rules.';
        }
      } else if (e.toString().contains('index')) {
        errorMsg = 'Firestore index required. Click to copy creation link.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
            action: e.toString().contains('http')
                ? SnackBarAction(
                    label: 'COPY LINK',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
    final maxContentWidth = 800.0;

    return GlassScaffold(
      title: 'Register Organization',
      onBack: _goBack,
      body: SafeArea(
        bottom: true,
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isDesktop ? 32.0 : 20.0,
                        ),
                        child: Column(
                          children: [
                            _buildStepIndicator(
                              theme,
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 32.0 : 24.0),
                            FadeTransition(
                              opacity: _opacityAnimation,
                              child: AnimatedBuilder(
                                animation: _translateAnimation,
                                builder: (context, child) =>
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        _translateAnimation.value,
                                      ),
                                      child: child,
                                    ),
                                child: _buildStep1(
                                  theme,
                                  isMobile,
                                  isTablet,
                                  isDesktop,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildStepIndicator(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 0;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
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

          return Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step circle and label
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isDesktop ? 44.0 : 36.0,
                        height: isDesktop ? 44.0 : 36.0,
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
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: isDesktop ? 24.0 : 20.0,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : colorScheme.onSurfaceVariant,
                                    fontSize: isDesktop ? 16.0 : 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 10.0 : 8.0),
                      Text(
                        steps[index],
                        style: TextStyle(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontSize: isDesktop ? 14.0 : 12.0,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Connector line
                if (index < steps.length - 1)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 60.0,
                        minWidth: 20.0,
                      ),
                      height: 2.0,
                      margin: EdgeInsets.only(
                        bottom: isDesktop ? 28.0 : 24.0,
                        left: isDesktop ? 16.0 : (isMobile ? 8.0 : 12.0),
                        right: isDesktop ? 16.0 : (isMobile ? 8.0 : 12.0),
                      ),
                      decoration: BoxDecoration(
                        color: activeStep > index
                            ? colorScheme.primary
                            : colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
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
            fontSize: isDesktop ? 28.0 : 24.0,
          ),
        ),
        SizedBox(height: isDesktop ? 12.0 : 8.0),
        Text(
          'Please provide your organization details below.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: isDesktop ? 17.0 : 15.0,
          ),
        ),
        SizedBox(height: isDesktop ? 40.0 : 32.0),

        // Professional Form Container
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Organization Name', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
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
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildFieldLabel('Corporate Email', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
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
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildFieldLabel('Contact Number', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _phoneController,
                hint: 'Enter mobile number',
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
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildFieldLabel('Admin Username', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
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
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildFieldLabel('Password', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _passwordController,
                hint: 'Min. 8 characters',
                icon: Icons.lock_rounded,
                isPassword: true,
                obscureText: !_isPasswordVisible,
                onToggleVisibility: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
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
                isDesktop: isDesktop,
              ),
              // Strength Indicator
              if (_passwordStrength.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: isDesktop ? 12.0 : 8.0,
                    left: 4.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isDesktop ? 100.0 : 80.0,
                        height: 4.0,
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
                      SizedBox(width: isDesktop ? 12.0 : 8.0),
                      Text(
                        _passwordStrength,
                        style: TextStyle(
                          color: _strengthColor,
                          fontSize: isDesktop ? 14.0 : 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildFieldLabel('Confirm Password', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _confirmPasswordController,
                hint: 'Re-enter password',
                icon: Icons.lock_clock_rounded,
                isPassword: true,
                obscureText: !_isConfirmPasswordVisible,
                onToggleVisibility: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 48.0 : 40.0),

              // Navigation Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 20.0 : 16.0,
                        ),
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
                          fontSize: isDesktop ? 16.0 : 14.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 20.0 : 16.0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _goToNextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 20.0 : 16.0,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: isDesktop ? 28.0 : 20.0,
                              width: isDesktop ? 28.0 : 20.0,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'CONTINUE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                fontSize: isDesktop ? 16.0 : 14.0,
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

  Widget _buildFieldLabel(String label, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isDesktop ? 16.0 : 14.0,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildProfessionalField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    required bool isDesktop,
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
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: isDesktop ? 17.0 : 15.0,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontSize: isDesktop ? 16.0 : 14.0,
          ),
          prefixIcon: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: isDesktop ? 24.0 : 20.0,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: theme.colorScheme.primary,
                    size: isDesktop ? 24.0 : 20.0,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20.0 : 16.0,
            vertical: isDesktop ? 20.0 : 16.0,
          ),
        ),
      ),
    );
  }
}
