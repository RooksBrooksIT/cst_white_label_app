import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/branding/branding_screen.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';

// Form screen for organization registration details with real-time backend validation

class OrganisationRegistrationPage extends StatefulWidget {
  const OrganisationRegistrationPage({super.key});

  @override
  State<OrganisationRegistrationPage> createState() =>
      _OrganisationRegistrationPageState();
}

class _OrganisationRegistrationPageState
    extends State<OrganisationRegistrationPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  // Form Controllers
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Real-time Validation State & Debounce Timers
  Timer? _orgNameDebounce;
  bool _isCheckingOrgName = false;
  String? _orgNameStatusText;
  bool? _isOrgNameValid;

  Timer? _emailDebounce;
  bool _isCheckingEmail = false;
  String? _emailStatusText;
  bool? _isEmailValid;

  Timer? _phoneDebounce;
  bool _isCheckingPhone = false;
  String? _phoneStatusText;
  bool? _isPhoneValid;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  String? _usernameStatusText;
  bool? _isUsernameValid;

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

  // -------------------- REAL-TIME VALIDATION HANDLERS --------------------

  void _onOrgNameChanged(String val) {
    _orgNameDebounce?.cancel();
    final clean = val.trim();
    if (clean.isEmpty) {
      setState(() {
        _isCheckingOrgName = false;
        _orgNameStatusText = null;
        _isOrgNameValid = null;
      });
      return;
    }

    if (clean.length < 2) {
      setState(() {
        _isCheckingOrgName = false;
        _orgNameStatusText = 'Organization name must be at least 2 characters';
        _isOrgNameValid = false;
      });
      return;
    }

    setState(() {
      _isCheckingOrgName = true;
      _orgNameStatusText = 'Checking availability...';
      _isOrgNameValid = null;
    });

    _orgNameDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final isUnique = await FirestoreService.isOrgNameUnique(clean);
        if (mounted && _orgNameController.text.trim() == clean) {
          setState(() {
            _isCheckingOrgName = false;
            _isOrgNameValid = isUnique;
            _orgNameStatusText = isUnique
                ? 'Organization name is available ✓'
                : 'Organization name already exists. Please use a different name.';
          });
        }
      } catch (e) {
        if (mounted && _orgNameController.text.trim() == clean) {
          setState(() {
            _isCheckingOrgName = false;
            _orgNameStatusText = null;
            _isOrgNameValid = null;
          });
        }
      }
    });
  }

  void _onEmailChanged(String val) {
    _emailDebounce?.cancel();
    final clean = val.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _isCheckingEmail = false;
        _emailStatusText = null;
        _isEmailValid = null;
      });
      return;
    }

    final isValidFormat =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean);
    if (!isValidFormat) {
      setState(() {
        _isCheckingEmail = false;
        _emailStatusText = 'Please enter a valid email format';
        _isEmailValid = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailStatusText = 'Checking email...';
      _isEmailValid = null;
    });

    _emailDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final isUnique = await FirestoreService.isEmailUnique(clean);
        if (mounted && _emailController.text.trim().toLowerCase() == clean) {
          setState(() {
            _isCheckingEmail = false;
            _isEmailValid = isUnique;
            _emailStatusText = isUnique
                ? 'Mail ID is available ✓'
                : 'Mail ID already exists. Please use another mail.';
          });
        }
      } catch (e) {
        if (mounted && _emailController.text.trim().toLowerCase() == clean) {
          setState(() {
            _isCheckingEmail = false;
            _emailStatusText = null;
            _isEmailValid = null;
          });
        }
      }
    });
  }

  void _onPhoneChanged(String val) {
    _phoneDebounce?.cancel();
    final clean = val.trim();
    if (clean.isEmpty) {
      setState(() {
        _isCheckingPhone = false;
        _phoneStatusText = null;
        _isPhoneValid = null;
      });
      return;
    }

    if (clean.length < 10) {
      setState(() {
        _isCheckingPhone = false;
        _phoneStatusText = 'Must be 10 digits (${clean.length}/10)';
        _isPhoneValid = false;
      });
      return;
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneStatusText = 'Checking phone...';
      _isPhoneValid = null;
    });

    _phoneDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final isUnique = await FirestoreService.isPhoneUnique(clean);
        if (mounted && _phoneController.text.trim() == clean) {
          setState(() {
            _isCheckingPhone = false;
            _isPhoneValid = isUnique;
            _phoneStatusText = isUnique
                ? 'Mobile number is available ✓'
                : 'Mobile number already exists. Please use another number.';
          });
        }
      } catch (e) {
        if (mounted && _phoneController.text.trim() == clean) {
          setState(() {
            _isCheckingPhone = false;
            _phoneStatusText = null;
            _isPhoneValid = null;
          });
        }
      }
    });
  }

  void _onUsernameChanged(String val) {
    _usernameDebounce?.cancel();
    final clean = val.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _usernameStatusText = null;
        _isUsernameValid = null;
      });
      return;
    }

    if (clean.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _usernameStatusText = 'Username must be at least 3 characters';
        _isUsernameValid = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatusText = 'Checking username...';
      _isUsernameValid = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final isUnique = await FirestoreService.isUsernameUnique(clean);
        if (mounted && _usernameController.text.trim().toLowerCase() == clean) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameValid = isUnique;
            _usernameStatusText = isUnique
                ? 'Username is available ✓'
                : 'Username already exists. Please use a different name.';
          });
        }
      } catch (e) {
        if (mounted && _usernameController.text.trim().toLowerCase() == clean) {
          setState(() {
            _isCheckingUsername = false;
            _usernameStatusText = null;
            _isUsernameValid = null;
          });
        }
      }
    });
  }

  // -------------------- LIFECYCLE --------------------

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
    _orgNameDebounce?.cancel();
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    _usernameDebounce?.cancel();

    _controller.dispose();
    _orgNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // -------------------- SUBMIT STEP --------------------

  Future<void> _goToNextStep() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    // Check if any real-time validation is actively failing
    if (_isOrgNameValid == false) {
      _showError(_orgNameStatusText ?? 'Organization name is already registered');
      return;
    }
    if (_isEmailValid == false) {
      _showError(_emailStatusText ?? 'Email address is already registered');
      return;
    }
    if (_isPhoneValid == false) {
      _showError(_phoneStatusText ?? 'Mobile number is already registered');
      return;
    }
    if (_isUsernameValid == false) {
      _showError(_usernameStatusText ?? 'Admin username is already taken');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Final atomic backend validation across all 4 fields simultaneously
      final String orgName = _orgNameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();
      final String username = _usernameController.text.trim().toLowerCase();

      final validation =
          await FirestoreService.validateOrganizationRegistration(
        orgName: orgName,
        email: email,
        phone: phone,
        username: username,
      );

      if (!validation.isValid) {
        // Check if there is a pending onboarding registration for this user
        final pendingQuery = await FirebaseFirestore.instance
            .collectionGroup('data')
            .where('username', isEqualTo: username)
            .get();

        bool isPendingPayment = false;
        Map<String, dynamic>? pendingData;
        String? pendingOrgId;

        for (var doc in pendingQuery.docs) {
          final data = doc.data();
          final plan = (data['subscriptionPlan'] ?? '').toString().trim();
          final step = (data['onboardingStep'] ?? '').toString().trim();
          final isSubActive = data['isSubscriptionActive'] == true;

          if (!isSubActive &&
              (step == 'PAYMENT_PENDING' ||
                  plan == 'Pending Selection' ||
                  (plan.isEmpty && step != 'COMPLETED' && data['paymentStatus'] == 'PENDING'))) {
            isPendingPayment = true;
            pendingData = data;
            pendingOrgId = doc.reference.parent.parent?.id;
            break;
          }
        }

        if (isPendingPayment && pendingData != null && mounted) {
          setState(() => _isLoading = false);
          final bool? shouldResume = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.pending_actions_rounded,
                      color: Color(0xFF2563EB), size: 26),
                  SizedBox(width: 10),
                  Text('Pending Registration',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: Text(
                'An account for "${pendingData!['org_name'] ?? username}" was already registered and is awaiting subscription payment.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('CANCEL',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1942),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('RESUME PAYMENT',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          if (shouldResume == true && mounted) {
            final String resOrgName =
                pendingData['org_name'] ?? _orgNameController.text.trim();
            final String appName = pendingData['app_name'] ?? resOrgName;
            final String themeHex = pendingData['theme_color'] ?? '#00A86B';
            final Color primaryColor = AppTheme.hexToColor(themeHex);
            String dateStr = '';
            if (pendingOrgId != null && pendingOrgId.contains('_')) {
              dateStr = pendingOrgId.split('_').last;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PricingScreen(
                  orgName: resOrgName,
                  email: pendingData!['email'] ?? email,
                  phone: pendingData['phone'] ?? phone,
                  username: username,
                  password: _passwordController.text.trim().isNotEmpty
                      ? _passwordController.text.trim()
                      : (pendingData['password'] ?? ''),
                  dateStr: dateStr,
                  appName: appName,
                  selectedColor: primaryColor,
                ),
              ),
            );
            return;
          }
        }

        if (mounted) {
          _showError(validation.errorMessage ??
              'One or more details already exist. Please check and try again.');
        }
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
        errorMsg = 'Database error: ${e.message}';
      }
      if (mounted) _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    AppTheme.showErrorToast(context, message);
  }

  // -------------------- UI BUILD --------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
    const maxContentWidth = 800.0;

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
                      constraints: const BoxConstraints(maxWidth: maxContentWidth),
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

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
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
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isDesktop ? 44.0 : 36.0,
                        height: isDesktop ? 44.0 : 36.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone || isActive
                              ? const Color(0xFF0B1942)
                              : const Color(0xFFE2E8F0),
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
                                        : const Color(0xFF0A183D),
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
                          color: const Color(0xFF0A183D),
                          fontSize: isDesktop ? 14.0 : 12.0,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 60.0,
                        minWidth: 20.0,
                      ),
                      height: 2.5,
                      margin: EdgeInsets.only(
                        bottom: isDesktop ? 28.0 : 24.0,
                        left: isDesktop ? 16.0 : (isMobile ? 8.0 : 12.0),
                        right: isDesktop ? 16.0 : (isMobile ? 8.0 : 12.0),
                      ),
                      decoration: BoxDecoration(
                        color: activeStep > index
                            ? const Color(0xFF0B1942)
                            : const Color(0xFFCBD5E1),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Heading
        Text(
          'Create Your Profile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A183D),
            letterSpacing: -0.5,
            fontSize: isDesktop ? 28.0 : 24.0,
          ),
        ),
        SizedBox(height: isDesktop ? 12.0 : 8.0),
        Text(
          'Please provide your organization details below.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
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
              // 1. Organization Name
              _buildFieldLabel('Organization Name', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _orgNameController,
                hint: 'Enter organization name',
                icon: Icons.business_rounded,
                isChecking: _isCheckingOrgName,
                isValid: _isOrgNameValid,
                statusText: _orgNameStatusText,
                onChanged: _onOrgNameChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Organization name is required';
                  }
                  if (_isOrgNameValid == false) {
                    return _orgNameStatusText ??
                        'Organization name is already registered';
                  }
                  return null;
                },
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),

              // 2. Corporate Email
              _buildFieldLabel('Corporate Email', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _emailController,
                hint: 'e.g. contact@org.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                isChecking: _isCheckingEmail,
                isValid: _isEmailValid,
                statusText: _emailStatusText,
                onChanged: _onEmailChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value.trim())) {
                    return 'Enter a valid email address';
                  }
                  if (_isEmailValid == false) {
                    return _emailStatusText ??
                        'Email address is already registered';
                  }
                  return null;
                },
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),

              // 3. Contact Number
              _buildFieldLabel('Contact Number', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _phoneController,
                hint: 'Enter 10-digit mobile number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                isChecking: _isCheckingPhone,
                isValid: _isPhoneValid,
                statusText: _phoneStatusText,
                onChanged: _onPhoneChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.trim().length != 10) {
                    return 'Phone number must be exactly 10 digits';
                  }
                  if (_isPhoneValid == false) {
                    return _phoneStatusText ??
                        'Mobile number is already registered';
                  }
                  return null;
                },
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),

              // 4. Admin Username
              _buildFieldLabel('Admin Username', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _usernameController,
                hint: 'Choose a unique admin username',
                icon: Icons.person_rounded,
                isChecking: _isCheckingUsername,
                isValid: _isUsernameValid,
                statusText: _usernameStatusText,
                onChanged: _onUsernameChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  if (_isUsernameValid == false) {
                    return _usernameStatusText ??
                        'Admin username is already taken';
                  }
                  return null;
                },
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),

              // 5. Password
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
              if (_passwordStrength.isNotEmpty) ...[
                SizedBox(height: isDesktop ? 10.0 : 8.0),
                Row(
                  children: [
                    Text(
                      'Strength: ',
                      style: TextStyle(
                        fontSize: isDesktop ? 14.0 : 12.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _passwordStrength,
                      style: TextStyle(
                        fontSize: isDesktop ? 14.0 : 12.0,
                        fontWeight: FontWeight.bold,
                        color: _strengthColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: isDesktop ? 100.0 : 80.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: _strengthColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _passwordStrength == 'Weak'
                            ? 0.33
                            : _passwordStrength == 'Moderate'
                                ? 0.66
                                : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _strengthColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: isDesktop ? 24.0 : 20.0),

              // 6. Confirm Password
              _buildFieldLabel('Confirm Password', isDesktop),
              SizedBox(height: isDesktop ? 12.0 : 8.0),
              _buildProfessionalField(
                controller: _confirmPasswordController,
                hint: 'Re-enter your password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                obscureText: !_isConfirmPasswordVisible,
                onToggleVisibility: () => setState(() =>
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
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
              SizedBox(height: isDesktop ? 48.0 : 36.0),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 20.0 : 16.0,
                        ),
                        side: const BorderSide(
                            color: Color(0xFF0A183D), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          color: const Color(0xFF0A183D),
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
                        backgroundColor: AppTheme.getDarkAccent(
                            AppTheme.primaryColor.value),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 20.0 : 16.0,
                        ),
                        elevation: 4,
                        shadowColor: AppTheme.getDarkAccent(
                                AppTheme.primaryColor.value)
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: isDesktop ? 28.0 : 20.0,
                              width: isDesktop ? 28.0 : 20.0,
                              child: const CircularProgressIndicator(
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
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0A183D),
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
    bool isChecking = false,
    bool? isValid,
    String? statusText,
    required bool isDesktop,
  }) {
    final Color statusColor = isChecking
        ? const Color(0xFF64748B)
        : (isValid == true
            ? const Color(0xFF10B981)
            : (isValid == false
                ? const Color(0xFFDC2626)
                : const Color(0xFF64748B)));

    final Color effectiveBorderColor = isChecking
        ? const Color(0xFFD4E3F4)
        : (isValid == true
            ? const Color(0xFF10B981)
            : (isValid == false
                ? const Color(0xFFDC2626)
                : const Color(0xFFD4E3F4)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: isDesktop ? 17.0 : 15.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0A183D),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: isDesktop ? 16.0 : 14.0,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF0B1942),
              size: isDesktop ? 24.0 : 20.0,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: const Color(0xFF0B1942),
                      size: isDesktop ? 24.0 : 20.0,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : (isChecking
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppTheme.getDarkAccent(
                                AppTheme.primaryColor.value),
                          ),
                        ),
                      )
                    : (isValid != null
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              isValid
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: statusColor,
                              size: isDesktop ? 22.0 : 19.0,
                            ),
                          )
                        : null)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20.0 : 16.0,
              vertical: isDesktop ? 18.0 : 16.0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: effectiveBorderColor,
                width: isValid != null && !isChecking ? 1.5 : 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isChecking
                    ? const Color(0xFF0B1942)
                    : (isValid != null ? effectiveBorderColor : const Color(0xFF0B1942)),
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFDC2626), width: 2.0),
            ),
            errorStyle: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
        if (statusText != null && statusText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5.0, left: 4.0),
            child: Row(
              children: [
                if (isChecking)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  )
                else if (isValid != null)
                  Icon(
                    isValid
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 13,
                    color: statusColor,
                  ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: isDesktop ? 12.5 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
