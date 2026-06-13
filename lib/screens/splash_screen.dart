import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor_dashboard.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:demo_cst/screens/org_subscription_page.dart';
import '../utils/terms_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _nameOpacity;
  late Animation<double> _logoScale;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
    _checkLoginAndSync();
  }

  Future<void> _checkLoginAndSync() async {
    final auth = AuthService();
    if (auth.isLoggedIn) {
      final data = auth.userData;
      final orgId = data['dynamicPath'] ?? data['orgId'];

      if (orgId != null && orgId.toString().isNotEmpty) {
        // Refresh branding from Firestore if logged in
        await AppTheme.syncWithFirestore(orgId.toString());
      }
    } else {
      // Also check if there's a temp org path from referral joining
      final prefs = await SharedPreferences.getInstance();
      final tempOrgPath = prefs.getString('temp_org_path');
      if (tempOrgPath != null && tempOrgPath.isNotEmpty) {
        await AppTheme.syncWithFirestore(tempOrgPath);
      }
    }

    // After animation and sync, navigate
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (mounted) {
        final accepted = await TermsHelper.hasAcceptedTerms();
        if (!accepted) {
          TermsHelper.showTermsDialog(
            context,
            onAccepted: () {
              _navigateToNext();
            },
          );
        } else {
          _navigateToNext();
        }
      }
    });
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    // Request location permissions on startup
    await LocationService.handleLocationPermission(context);

    final auth = AuthService();
    if (auth.isLoggedIn) {
      final data = auth.userData;
      switch (auth.userRole) {
        case UserRole.organization:
          final isSubscriptionValid = await auth.checkSubscriptionStatus();
          if (isSubscriptionValid) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationDashboard(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationSubscriptionPage(),
              ),
            );
          }
          break;
        case UserRole.manager:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfigAccountDashboard(),
            ),
          );
          break;
        case UserRole.supervisor:
          final isContractor = data['isContractor'] ?? false;
          if (isContractor) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorEntryPage(
                  userName: data['username'] ?? '',
                  userDetails: {
                    'supervisorId': data['supervisorId'] ?? '',
                    'contractorName': data['contractorName'] ?? '',
                    'contractorField': data['contractorField'] ?? '',
                  },
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorDashboard(
                  supervisorId: data['supervisorId'] ?? '',
                  supervisorName: data['supervisorName'] ?? '',
                  username: data['username'] ?? '',
                ),
              ),
            );
          }
          break;
        case UserRole.customer:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDashboardPage(
                ownerName: data['ownerName'] ?? '',
                ownerPhoneNumber: '',
                siteId: data['siteId'] ?? '',
              ),
            ),
          );
          break;
        default:
          Navigator.pushReplacementNamed(context, '/landing');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                  Colors.grey.shade100,
                ],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: const Alignment(0, -0.1),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/splash_screen_logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // App name at bottom
                SlideTransition(
                  position: _textSlide,
                  child: Opacity(
                    opacity: _nameOpacity.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: AppTheme.appName,
                            builder: (context, name, _) {
                              return Text(
                                name,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.2,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Build smarter. Manage better.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
        ),
      ),
    );
  }
}
