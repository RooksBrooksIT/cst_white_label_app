import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/manager/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor/supervisor_dashboard.dart';
import 'package:demo_cst/screens/manager/contractor_entry_page.dart';
import 'package:demo_cst/screens/customer/customer_dashboard.dart';
import 'package:demo_cst/screens/organization/organisation_landing_page.dart';

enum PortalErrorType {
  none,
  sessionExpired,
  accessDenied,
  networkFailure,
  generic,
}

class PortalLoadingScreen extends StatefulWidget {
  final UserRole? expectedRole;
  final String? initialStatusMessage;

  const PortalLoadingScreen({
    super.key,
    this.expectedRole,
    this.initialStatusMessage,
  });

  @override
  State<PortalLoadingScreen> createState() => _PortalLoadingScreenState();
}

class _PortalLoadingScreenState extends State<PortalLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Loading your dashboard…';
  bool _isLoading = true;
  PortalErrorType _errorType = PortalErrorType.none;
  String _errorMessage = '';
  UserRole? _detectedRole;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusMessage != null) {
      _statusMessage = widget.initialStatusMessage!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start resolution
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAndLoadPortal();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _resolveAndLoadPortal() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorType = PortalErrorType.none;
      _errorMessage = '';
      _statusMessage = 'Verifying authentication…';
    });

    try {
      final auth = AuthService();

      // Check if logged in
      if (!auth.isLoggedIn) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorType = PortalErrorType.sessionExpired;
          _errorMessage =
              'Your session has expired or is invalid. Please sign in again to continue.';
        });
        return;
      }

      final actualRole = auth.userRole;
      _detectedRole = actualRole;

      // Validate role if expectedRole is provided
      if (widget.expectedRole != null &&
          widget.expectedRole != UserRole.none &&
          actualRole != widget.expectedRole) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorType = PortalErrorType.accessDenied;
          _errorMessage =
              'You do not have permission to access the requested portal. Your account is registered as a ${_getRoleLabel(actualRole)}.';
        });
        return;
      }

      if (actualRole == UserRole.none) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorType = PortalErrorType.accessDenied;
          _errorMessage =
              'No portal role found for your account. Please contact your organization administrator.';
        });
        return;
      }

      // Step 2: Role-based data loading & cache sync
      if (mounted) {
        setState(() => _statusMessage = 'Syncing workspace data…');
      }

      final data = auth.userData;
      final orgId = (data['dynamicPath'] ?? data['orgId'])?.toString();

      if (orgId != null && orgId.isNotEmpty && orgId != 'uninitialized') {
        try {
          await AppTheme.syncWithFirestore(orgId);
        } catch (_) {}
      }

      try {
        await FirestoreService.initialize();
      } catch (_) {}

      // Save notification token
      final username = data['username']?.toString() ?? 'unknown';
      try {
        await NotificationService.saveToken(
          userId: username,
          userType: actualRole.toString().split('.').last,
          userName: username,
        );
      } catch (_) {}

      // Step 3: Check subscription & branding sync in background if organization
      if (actualRole == UserRole.organization) {
        try {
          await auth.checkSubscriptionStatus();
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _statusMessage = 'Opening dashboard…');
      }

      // Smooth brief delay for fluid transition
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Step 4: Route to correct portal
      Widget destination;
      switch (actualRole) {
        case UserRole.organization:
          destination = const OrganizationDashboard();
          break;
        case UserRole.manager:
          destination = const ConfigAccountDashboard();
          break;
        case UserRole.supervisor:
          final isContractor = data['isContractor'] == true ||
              data['userType'] == 'contractor';
          if (isContractor) {
            destination = ContractorEntryPage(
              userName: data['username'] ?? '',
              userDetails: {
                'supervisorId': data['supervisorId'] ?? '',
                'contractorName': data['contractorName'] ?? '',
                'contractorField': data['contractorField'] ?? '',
              },
            );
          } else {
            destination = SupervisorDashboard(
              supervisorId: data['supervisorId'] ?? '',
              supervisorName: data['supervisorName'] ?? '',
              username: data['username'] ?? '',
            );
          }
          break;
        case UserRole.customer:
          destination = CustomerDashboardPage(
            ownerName: data['ownerName'] ?? '',
            ownerPhoneNumber: data['ownerPhoneNumber'] ?? '',
            siteId: data['siteId'] ?? '',
          );
          break;
        default:
          destination = const OrganisationLandingPage();
      }

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('PortalLoadingScreen error: $e');
      if (!mounted) return;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('timeout');

      setState(() {
        _isLoading = false;
        _errorType = isNetwork
            ? PortalErrorType.networkFailure
            : PortalErrorType.generic;
        _errorMessage = isNetwork
            ? 'Unable to connect to the server. Please check your internet connection and try again.'
            : 'Unable to load your dashboard. Please try again.';
      });
    }
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.organization:
        return 'Organization Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.supervisor:
        return 'Site Supervisor';
      case UserRole.customer:
        return 'Client / Customer';
      default:
        return 'User';
    }
  }

  void _navigateToLogin() async {
    HapticFeedback.lightImpact();
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OrganisationLandingPage()),
      (route) => false,
    );
  }

  void _navigateToDetectedPortal() {
    HapticFeedback.lightImpact();
    _resolveAndLoadPortal();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final bgGradient = AppTheme.getBackgroundGradientColors(primaryColor);

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradient,
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _isLoading
                      ? _buildLoadingState(primaryColor, darkAccent)
                      : _buildErrorState(primaryColor, darkAccent),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(Color primaryColor, Color darkAccent) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Logo Container
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.28),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: ValueListenableBuilder<String>(
                valueListenable: AppTheme.logoUrl,
                builder: (context, logoUrl, _) {
                  if (logoUrl.isNotEmpty) {
                    return Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultLogoIcon(primaryColor),
                    );
                  }
                  return _buildDefaultLogoIcon(primaryColor);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),

        // App Name
        ValueListenableBuilder<String>(
          valueListenable: AppTheme.appName,
          builder: (context, appName, _) {
            return Text(
              appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Custom Spinner Indicator
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3.2,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            backgroundColor: primaryColor.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 18),

        // Dynamic Status Message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _statusMessage,
            key: ValueKey<String>(_statusMessage),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 12, color: Color(0xFF64748B)),
              SizedBox(width: 5),
              Text(
                'Securing portal connection',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultLogoIcon(Color primaryColor) {
    return Center(
      child: Icon(
        Icons.apartment_rounded,
        size: 52,
        color: primaryColor,
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, Color darkAccent) {
    IconData errorIcon;
    Color iconColor;
    String errorTitle;

    switch (_errorType) {
      case PortalErrorType.sessionExpired:
        errorIcon = Icons.lock_clock_rounded;
        iconColor = const Color(0xFFD97706); // Amber
        errorTitle = 'Session Expired';
        break;
      case PortalErrorType.accessDenied:
        errorIcon = Icons.no_accounts_rounded;
        iconColor = const Color(0xFFE11D48); // Rose Red
        errorTitle = 'Access Denied';
        break;
      case PortalErrorType.networkFailure:
        errorIcon = Icons.wifi_off_rounded;
        iconColor = const Color(0xFF2563EB); // Blue
        errorTitle = 'Connection Issue';
        break;
      default:
        errorIcon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFDC2626); // Red
        errorTitle = 'Unable to Load Portal';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                errorIcon,
                color: iconColor,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Error Title
          Text(
            errorTitle,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // User-friendly error message
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          // Primary Button (Retry or Redirect to assigned portal)
          if (_errorType == PortalErrorType.accessDenied &&
              _detectedRole != null &&
              _detectedRole != UserRole.none)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _navigateToDetectedPortal,
                icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                label: Text('Open ${_getRoleLabel(_detectedRole!)} Portal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _resolveAndLoadPortal();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Loading Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Secondary Action (Return to Login)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: _navigateToLogin,
              icon: const Icon(Icons.login_rounded, size: 17),
              label: const Text('Return to Login'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
