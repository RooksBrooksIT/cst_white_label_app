import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/widgets/glass_button.dart';
import 'package:ebricks/widgets/glass_card.dart';
import 'package:ebricks/widgets/glass_scaffold.dart';
import 'package:ebricks/widgets/glass_text_field.dart';

/// Steps in the Forgot Password flow
enum ResetPasswordStep {
  email,
  otp,
  newPassword,
  success,
}

/// A comprehensive screen that implements the Email → OTP Verification → Reset Password flow
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  ResetPasswordStep _currentStep = ResetPasswordStep.email;

  // Form Keys
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // 6-digit OTP Controllers & Focus Nodes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // Password Visibility
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // General State
  bool _isLoading = false;
  bool _isSubmitting = false;
  DateTime? _lastOtpRequestTime;
  String? _errorMessage;
  String? _sessionId;
  String? _maskedEmail;
  String? _resetToken;

  // OTP Rules State
  // 1. 5 minutes validity (300 seconds)
  Timer? _otpValidityTimer;
  int _otpValiditySecondsRemaining = 300;
  bool _isOtpExpired = false;

  // 2. 60-second Resend Cooldown
  Timer? _resendCooldownTimer;
  int _resendSecondsRemaining = 60;
  bool _canResend = false;

  // 3. Maximum 5 Resends
  int _resendCount = 0;
  static const int _maxResends = 5;

  // 4. Maximum 5 Incorrect Attempts
  int _incorrectAttempts = 0;
  static const int _maxIncorrectAttempts = 5;
  bool _isOtpLocked = false;

  /// Helper to cleanly mask registered email (e.g. ro***@gmail.com)
  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) {
      return '${local.substring(0, 1)}***@$domain';
    }
    return '${local.substring(0, 2)}***@$domain';
  }

  /// Sanitizes raw or technical backend errors into user-friendly messages
  String _sanitizeError(String? rawError) {
    if (rawError == null || rawError.isEmpty) {
      return 'An error occurred. Please try again.';
    }
    final lower = rawError.toLowerCase();
    if (lower.contains('smtp') ||
        lower.contains('535') ||
        lower.contains('badcredentials') ||
        lower.contains('invalid credentials')) {
      return 'Unable to send email right now. Please try again later or contact administrator.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('timeout') ||
        lower.contains('unable to connect')) {
      return 'Network connection issue. Please check your internet connection.';
    }
    if (lower.contains('not registered')) {
      return 'This email ID is not registered with eBricks. Please enter a valid registered email.';
    }
    if (lower.contains('wait') && lower.contains('seconds')) {
      return rawError;
    }
    if (lower.contains('maximum') || lower.contains('resend limit')) {
      return 'Maximum OTP resend limit (5) reached for this session. Please try again later.';
    }
    if (lower.contains('expired')) {
      return 'OTP has expired. Please request a new verification code.';
    }
    if (lower.contains('too many incorrect') || lower.contains('invalidated')) {
      return 'Too many incorrect attempts (5). Current OTP has been invalidated. Please request a new OTP.';
    }
    if (lower.contains('incorrect otp')) {
      return rawError;
    }
    if (lower.contains('internal') ||
        lower.contains('exception') ||
        lower.contains('cloud function')) {
      return 'Service temporarily unavailable. Please try again in a few moments.';
    }
    return rawError;
  }

  /// Cleanly navigate back to Step 1 without broken state
  void _handleChangeEmail() {
    _otpValidityTimer?.cancel();
    _resendCooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _currentStep = ResetPasswordStep.email;
      _errorMessage = null;
    });
  }

  double get _passwordStrength {
    final pass = _newPasswordController.text;
    if (pass.isEmpty) return 0.0;
    double score = 0.0;
    if (pass.length >= 6) score += 0.35;
    if (pass.length >= 8) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(pass) && RegExp(r'[a-zA-Z]').hasMatch(pass)) {
      score += 0.25;
    }
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  String get _passwordStrengthLabel {
    final s = _passwordStrength;
    if (s <= 0.0) return '';
    if (s < 0.4) return 'Weak';
    if (s < 0.75) return 'Medium';
    return 'Strong';
  }

  Color get _passwordStrengthColor {
    final s = _passwordStrength;
    if (s < 0.4) return Colors.redAccent;
    if (s < 0.75) return Colors.orangeAccent;
    return Colors.greenAccent.shade400;
  }

  @override
  void initState() {
    super.initState();
    // Add listeners to focus nodes so the UI updates focused border styling
    for (final node in _otpFocusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _newPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
    _confirmPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _otpValidityTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  String get _fullOtp =>
      _otpControllers.map((c) => c.text.replaceAll(RegExp(r'\D'), '')).join();

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        _showSnackBar('No verification code found on clipboard.', isError: true);
        return;
      }
      for (int i = 0; i < digits.length && i < 6; i++) {
        _otpControllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        if (_otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[5].unfocus();
        }
        setState(() {});
        _handleVerifyOtp();
      } else {
        final next = digits.length.clamp(0, 5);
        _otpFocusNodes[next].requestFocus();
        setState(() {});
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // TIMERS & RULES
  // ---------------------------------------------------------------------------

  void _startOtpTimers({int validitySeconds = 300, int cooldownSeconds = 60}) {
    _otpValidityTimer?.cancel();
    _resendCooldownTimer?.cancel();

    setState(() {
      _otpValiditySecondsRemaining = validitySeconds;
      _isOtpExpired = false;
      _resendSecondsRemaining = cooldownSeconds;
      _canResend = false;
      _isOtpLocked = false;
      _incorrectAttempts = 0;
      _errorMessage = null;
    });

    // 5-minute validity countdown
    _otpValidityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpValiditySecondsRemaining > 1) {
        setState(() {
          _otpValiditySecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _otpValiditySecondsRemaining = 0;
          _isOtpExpired = true;
          _errorMessage =
              'OTP has expired. Please request a new verification code.';
        });
      }
    });

    // 60-second resend cooldown countdown
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining > 1) {
        setState(() {
          _resendSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendSecondsRemaining = 0;
          _canResend = true;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: STEP 1 - REQUEST OTP
  // ---------------------------------------------------------------------------

  Future<void> _handleRequestOtp({bool isResend = false}) async {
    // 1. Prevent duplicate rapid taps / double triggers
    if (_isSubmitting || _isLoading) return;

    final now = DateTime.now();
    if (_lastOtpRequestTime != null &&
        now.difference(_lastOtpRequestTime!).inMilliseconds < 1500) {
      return; // Ignore rapid double-tap
    }

    if (!isResend) {
      if (!_emailFormKey.currentState!.validate()) return;
    }

    if (isResend) {
      if (_resendCount >= _maxResends) {
        _showSnackBar(
          'Maximum resend limit (5) reached for this session.',
          isError: true,
        );
        return;
      }
      if (!_canResend) {
        _showSnackBar(
          'Please wait $_resendSecondsRemaining seconds before resending.',
          isError: true,
        );
        return;
      }
    }

    _isSubmitting = true;
    _lastOtpRequestTime = now;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final clientRequestId = '${DateTime.now().millisecondsSinceEpoch}_${email.hashCode}';

    try {
      final result = await AuthService().requestPasswordResetOtp(
        email,
        isResend: isResend,
        requestId: clientRequestId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _sessionId = result['sessionId']?.toString();
        _maskedEmail = result['maskedEmail']?.toString() ?? _maskEmail(email);
        _resendCount = (result['resendCount'] as num?)?.toInt() ?? (_resendCount + (isResend ? 1 : 0));

        // Clear OTP inputs
        for (final c in _otpControllers) {
          c.clear();
        }

        // Start timers
        final validity = (result['expiresInSeconds'] as num?)?.toInt() ?? 300;
        final cooldown = (result['resendCooldownSeconds'] as num?)?.toInt() ?? 60;
        _startOtpTimers(validitySeconds: validity, cooldownSeconds: cooldown);

        setState(() {
          _currentStep = ResetPasswordStep.otp;
        });

        _showSnackBar(
          isResend
              ? 'A new OTP has been sent. The previous OTP is now invalid.'
              : 'Verification OTP sent to your registered email.',
          isError: false,
        );

        // Auto focus first OTP digit
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        });
      } else {
        final errorMsg = _sanitizeError(result['error']?.toString() ??
            'Failed to send verification code. Please check the email and try again.');
        setState(() {
          _errorMessage = errorMsg;
        });
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _sanitizeError('Failed to send verification code. Please try again.');
      setState(() {
        _errorMessage = errorMsg;
      });
      _showSnackBar(errorMsg, isError: true);
    } finally {
      _isSubmitting = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: STEP 2 - VERIFY OTP
  // ---------------------------------------------------------------------------

  Future<void> _handleVerifyOtp() async {
    final otp = _fullOtp;

    if (_isOtpExpired) {
      _showSnackBar('OTP has expired. Please request a new OTP.', isError: true);
      return;
    }
    if (_isOtpLocked) {
      _showSnackBar(
        'Too many incorrect attempts (5). Current OTP is invalid. Request a new OTP.',
        isError: true,
      );
      return;
    }
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final result = await AuthService().verifyPasswordResetOtp(
        email: email,
        otp: otp,
        sessionId: _sessionId ?? '',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _otpValidityTimer?.cancel();
        _resendCooldownTimer?.cancel();

        _resetToken = result['resetToken']?.toString();

        setState(() {
          _currentStep = ResetPasswordStep.newPassword;
          _errorMessage = null;
        });

        _showSnackBar('Identity verified successfully. Create your new password.', isError: false);
      } else {
        final errorMsg = _sanitizeError(result['error']?.toString() ?? 'Invalid verification code.');
        final isExpired = result['isExpired'] == true;
        final isLocked = result['isLocked'] == true;

        setState(() {
          _errorMessage = errorMsg;
          if (isExpired) _isOtpExpired = true;
          if (isLocked) {
            _isOtpLocked = true;
            _incorrectAttempts = _maxIncorrectAttempts;
          } else {
            _incorrectAttempts++;
          }
        });

        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _sanitizeError('Verification failed. Please try again.');
      setState(() {
        _errorMessage = errorMsg;
      });
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: STEP 3 - COMPLETE PASSWORD RESET
  // ---------------------------------------------------------------------------

  Future<void> _handleResetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final result = await AuthService().completePasswordReset(
        email: email,
        resetToken: _resetToken ?? '',
        sessionId: _sessionId ?? '',
        newPassword: newPass,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _currentStep = ResetPasswordStep.success;
        });

        _showSnackBar(
          'Password reset successfully! You can now log in.',
          isError: false,
        );

        // Automatically navigate back to Login after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        final errorMsg = result['error']?.toString() ??
            'Failed to reset password. Please try again.';
        setState(() {
          _errorMessage = errorMsg;
        });
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = 'Reset error: ${e.toString()}';
      setState(() {
        _errorMessage = errorMsg;
      });
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: STEP INDICATOR
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // BUILD: STEP INDICATOR (COMPACT & PRECISELY ALIGNED)
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _buildStepNode(
            index: 1,
            title: 'Email',
            isActive: _currentStep == ResetPasswordStep.email,
            isCompleted: _currentStep.index > ResetPasswordStep.email.index,
            primaryColor: primaryColor,
          ),
          _buildStepDivider(
            isCompleted: _currentStep.index > ResetPasswordStep.email.index,
            primaryColor: primaryColor,
          ),
          _buildStepNode(
            index: 2,
            title: 'Verify OTP',
            isActive: _currentStep == ResetPasswordStep.otp,
            isCompleted: _currentStep.index > ResetPasswordStep.otp.index,
            primaryColor: primaryColor,
          ),
          _buildStepDivider(
            isCompleted: _currentStep.index > ResetPasswordStep.otp.index,
            primaryColor: primaryColor,
          ),
          _buildStepNode(
            index: 3,
            title: 'New Password',
            isActive: _currentStep == ResetPasswordStep.newPassword,
            isCompleted: _currentStep == ResetPasswordStep.success,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required int index,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required Color primaryColor,
  }) {
    final color = isCompleted
        ? Colors.greenAccent.shade400
        : (isActive ? primaryColor : Colors.white38);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green.shade800
                : (isActive ? primaryColor.withValues(alpha: 0.25) : Colors.white10),
            border: Border.all(
              color: color,
              width: isActive ? 2.0 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isCompleted ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isCompleted, required Color primaryColor}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        color: isCompleted ? Colors.greenAccent.shade400 : Colors.white12,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: STEP 1 - EMAIL FORM (HIGH-CONTRAST & PROPORTIONAL)
  // ---------------------------------------------------------------------------

  Widget _buildEmailStep(ThemeData theme, Color primaryColor) {
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final fieldBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white24 : const Color(0xFFCBD5E1);

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Forgot Password',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryColor,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your registered email address to receive a secure authentication OTP.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Explicit high-contrast label
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'Registered Email Address',
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),

          // Clean, high-contrast visible text field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: fieldBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              hintText: 'Enter registered email address',
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: primaryColor,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2.0),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email cannot be empty';
              }
              final emailRegex =
                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(_errorMessage!),
          ],

          const SizedBox(height: 20),

          // Send OTP CTA
          GlassButton(
            label: 'SEND OTP',
            icon: Icons.send_rounded,
            onPressed: _isLoading ? null : () => _handleRequestOtp(isResend: false),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: STEP 2 - REDESIGNED OTP VERIFICATION FORM
  // ---------------------------------------------------------------------------

  Widget _buildOtpStep(ThemeData theme, Color primaryColor) {
    final remainingResends = _maxResends - _resendCount;
    final remainingAttempts = _maxIncorrectAttempts - _incorrectAttempts;
    final displayEmail = _maskedEmail ?? _maskEmail(_emailController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with "Verify Your Email" and "Change Email" action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Verify Your Email',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontSize: 20,
              ),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : _handleChangeEmail,
              icon: const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white70),
              label: const Text(
                'Change Email',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Short Instruction
        Text(
          'Enter the 6-digit code sent to your email address.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.4,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 12),

        // Masked Email Badge Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline_rounded, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayEmail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 6-digit OTP Input Boxes
        _buildOtpBoxes(primaryColor),

        const SizedBox(height: 10),

        // Quick Paste Action & Remaining Attempts Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_incorrectAttempts > 0 && !_isOtpLocked && !_isOtpExpired)
              Text(
                'Incorrect code. $remainingAttempts attempt${remainingAttempts > 1 ? "s" : ""} left.',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const SizedBox(),
            TextButton.icon(
              onPressed: (_isLoading || _isOtpExpired || _isOtpLocked)
                  ? null
                  : _pasteFromClipboard,
              icon: Icon(Icons.paste_rounded, size: 14, color: primaryColor),
              label: Text(
                'Paste Code',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Validity Countdown & Resends Badges
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isOtpExpired
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isOtpExpired
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Validity Timer
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _isOtpExpired
                        ? Colors.redAccent
                        : (_otpValiditySecondsRemaining < 60
                            ? Colors.orangeAccent
                            : Colors.white70),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOtpExpired
                        ? 'Code Expired'
                        : 'Code expires in ${_formatDuration(_otpValiditySecondsRemaining)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _isOtpExpired
                          ? Colors.redAccent
                          : (_otpValiditySecondsRemaining < 60
                              ? Colors.orangeAccent
                              : Colors.white),
                    ),
                  ),
                ],
              ),

              // Resends Remaining
              Text(
                'Resends: $remainingResends/$_maxResends',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorBanner(_errorMessage!),
        ],

        const SizedBox(height: 24),

        // Verify Code Button
        GlassButton(
          label: 'VERIFY CODE',
          icon: Icons.verified_user_rounded,
          onPressed: (_isLoading || _isOtpExpired || _isOtpLocked)
              ? null
              : _handleVerifyOtp,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 16),

        // Resend Button Row (Disabled until 60s cooldown finishes)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code?",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: (_isLoading || !_canResend || _resendCount >= _maxResends || _isOtpLocked)
                  ? null
                  : () => _handleRequestOtp(isResend: true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _canResend
                    ? 'Resend Code'
                    : 'Resend in ${_formatDuration(_resendSecondsRemaining)}',
                style: TextStyle(
                  color: _canResend && _resendCount < _maxResends && !_isOtpLocked
                      ? primaryColor
                      : Colors.white38,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: 6-DIGIT OTP BOXES (RESPONSIVE & CLEAN)
  // ---------------------------------------------------------------------------

  Widget _buildOtpBoxes(Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive box width (38 to 50 px)
        final availableWidth = constraints.maxWidth;
        final totalSpacing = 36.0;
        final boxWidth = ((availableWidth - totalSpacing) / 6).clamp(38.0, 50.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final isFocused = _otpFocusNodes[index].hasFocus;
            final hasValue = _otpControllers[index].text.isNotEmpty;

            return SizedBox(
              width: boxWidth,
              height: 56,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    if (_otpControllers[index].text.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                      _otpControllers[index - 1].clear();
                      setState(() {});
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: !_isLoading && !_isOtpExpired && !_isOtpLocked,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasValue
                            ? primaryColor.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.25),
                        width: hasValue ? 1.8 : 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor,
                        width: 2.4,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (val) {
                    final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                    if (cleanVal.length > 1) {
                      // Handle pasting multiple digits into any box
                      for (int i = 0; i < cleanVal.length && (index + i) < 6; i++) {
                        _otpControllers[index + i].text = cleanVal[i];
                      }
                      final nextIndex = (index + cleanVal.length).clamp(0, 5);
                      _otpFocusNodes[nextIndex].requestFocus();
                      setState(() {});
                      if (_fullOtp.length == 6) {
                        _handleVerifyOtp();
                      }
                      return;
                    }

                    if (cleanVal.isNotEmpty) {
                      _otpControllers[index].text = cleanVal[cleanVal.length - 1];
                      if (index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else {
                        _otpFocusNodes[index].unfocus();
                        if (_fullOtp.length == 6) {
                          _handleVerifyOtp();
                        }
                      }
                    } else {
                      _otpControllers[index].clear();
                      if (index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                    }
                    setState(() {});
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: STEP 3 - REDESIGNED NEW PASSWORD FORM
  // ---------------------------------------------------------------------------

  Widget _buildRuleRow({
    required String label,
    required bool isMet,
    required Color primaryColor,
  }) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isMet ? Colors.greenAccent.shade400 : Colors.white38,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
            color: isMet ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep(ThemeData theme, Color primaryColor) {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final isLengthValid = newPass.length >= 6;
    final hasLetterAndDigit =
        RegExp(r'[a-zA-Z]').hasMatch(newPass) && RegExp(r'[0-9]').hasMatch(newPass);
    final isMatch = confirmPass.isNotEmpty && newPass == confirmPass;

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_reset_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Password',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Identity verified! Set your new account password.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // New Password Field
          GlassTextField(
            controller: _newPasswordController,
            label: 'New Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPassword: _isNewPasswordVisible,
            onTogglePassword: () =>
                setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password cannot be empty';
              if (v.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
            enabled: !_isLoading,
          ),

          // Dynamic Password Strength Bar
          if (newPass.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _passwordStrengthLabel,
                  style: TextStyle(
                    color: _passwordStrengthColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Confirm New Password Field
          GlassTextField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            showPassword: _isConfirmPasswordVisible,
            onTogglePassword: () =>
                setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Confirm password cannot be empty';
              if (v.trim() != _newPasswordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
            enabled: !_isLoading,
          ),

          const SizedBox(height: 16),

          // Live Password Requirement Checklist
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRuleRow(
                  label: 'At least 6 characters',
                  isMet: isLengthValid,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 6),
                _buildRuleRow(
                  label: 'Contains letters & numbers',
                  isMet: hasLetterAndDigit,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 6),
                _buildRuleRow(
                  label: 'Both passwords match',
                  isMet: isMatch,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(_errorMessage!),
          ],

          const SizedBox(height: 24),

          // Submit CTA Button
          GlassButton(
            label: 'UPDATE PASSWORD',
            icon: Icons.check_circle_outline_rounded,
            onPressed: _isLoading ? null : _handleResetPassword,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: STEP 4 - SUCCESS SCREEN
  // ---------------------------------------------------------------------------

  Widget _buildSuccessStep(ThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.15),
            border: Border.all(color: Colors.greenAccent.shade400, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: Colors.greenAccent.shade400,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Password Reset Successful!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been securely updated. You can now log in to eBricks with your new password.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        GlassButton(
          label: 'BACK TO LOGIN',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR BANNER HELPER
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sanitizeError(message),
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIcon(Color primaryColor, {bool isMobile = true}) {
    final IconData icon;
    switch (_currentStep) {
      case ResetPasswordStep.email:
        icon = Icons.lock_reset_rounded;
        break;
      case ResetPasswordStep.otp:
        icon = Icons.mark_email_read_rounded;
        break;
      case ResetPasswordStep.newPassword:
        icon = Icons.password_rounded;
        break;
      case ResetPasswordStep.success:
        icon = Icons.verified_user_rounded;
        break;
    }

    final double size = isMobile ? 56.0 : 66.0;
    final double iconSize = isMobile ? 28.0 : 32.0;

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.28),
              primaryColor.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.22),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD METHOD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        return GlassScaffold(
          title: 'Reset Password',
          toolbarHeight: isMobile ? 54 : 64,
          onBack: () {
            if (_currentStep == ResetPasswordStep.otp) {
              setState(() {
                _currentStep = ResetPasswordStep.email;
                _errorMessage = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 500,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 18.0 : 24.0,
                      vertical: isMobile ? 12.0 : 20.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dynamic Glow Hero Icon
                        _buildHeroIcon(primaryColor, isMobile: isMobile),
                        SizedBox(height: isMobile ? 14 : 20),

                        // Step Indicator
                        if (_currentStep != ResetPasswordStep.success) ...[
                          _buildStepIndicator(theme, primaryColor),
                          SizedBox(height: isMobile ? 14 : 20),
                        ],

                        // Content Card
                        GlassCard(
                          margin: EdgeInsets.zero,
                          padding: EdgeInsets.all(isMobile ? 18.0 : 24.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: switch (_currentStep) {
                              ResetPasswordStep.email =>
                                _buildEmailStep(theme, primaryColor),
                              ResetPasswordStep.otp =>
                                _buildOtpStep(theme, primaryColor),
                              ResetPasswordStep.newPassword =>
                                _buildNewPasswordStep(theme, primaryColor),
                              ResetPasswordStep.success =>
                                _buildSuccessStep(theme, primaryColor),
                            },
                          ),
                        ),

                        SizedBox(height: isMobile ? 12 : 18),

                        // Back to Login Link
                        if (_currentStep != ResetPasswordStep.success)
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                              label: Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
