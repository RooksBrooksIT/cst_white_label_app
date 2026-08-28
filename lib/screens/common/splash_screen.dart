import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';
import 'package:demo_cst/screens/manager/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor/supervisor_dashboard.dart';
import 'package:demo_cst/screens/manager/contractor_entry_page.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/customer/customer_dashboard.dart';
import 'package:demo_cst/utils/terms_helper.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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
          final orgId = data['dynamicPath'] ?? data['orgId'];
          bool isPaymentPending = false;
          if (orgId != null && orgId.toString().isNotEmpty) {
            try {
              final subDoc = await FirebaseFirestore.instance
                  .collection('organisation')
                  .doc(orgId.toString())
                  .collection('data')
                  .doc('subscription')
                  .get();
              final subData = subDoc.data();
              if (subData != null &&
                  subData['isSubscriptionActive'] != true &&
                  (subData['onboardingStep'] == 'PAYMENT_PENDING' ||
                      subData['subscriptionPlan'] == 'Pending Selection')) {
                isPaymentPending = true;
              }
            } catch (_) {}
          }

          if (isPaymentPending) {
            final rootDoc = await FirebaseFirestore.instance
                .collection('organisation')
                .doc(orgId.toString())
                .get();
            final rootData = rootDoc.data() ?? {};
            final String effectiveOrgName =
                rootData['org_name'] ?? data['org_name'] ?? '';
            final String effectiveAppName =
                rootData['app_name'] ?? effectiveOrgName;
            final String themeHex = rootData['theme_color'] ?? '#00A86B';
            final Color primaryColor = AppTheme.hexToColor(themeHex);

            String dateStr = '';
            if (orgId != null && orgId.toString().contains('_')) {
              dateStr = orgId.toString().split('_').last;
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PricingScreen(
                  orgName: effectiveOrgName,
                  email: (rootData['email'] ?? data['email'] ?? '').toString(),
                  phone: (rootData['phone'] ?? data['phone'] ?? '').toString(),
                  username:
                      (rootData['username'] ?? data['username'] ?? '').toString(),
                  password:
                      (rootData['password'] ?? data['password'] ?? '').toString(),
                  dateStr: dateStr,
                  appName: effectiveAppName,
                  selectedColor: primaryColor,
                ),
              ),
            );
            return;
          }

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
                ownerPhoneNumber: data['ownerPhoneNumber'] ?? '',
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
    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
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
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B1942).withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/images/logo_main.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/splash_screen_logo.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // App name & tagline at bottom
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
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0A183D),
                                letterSpacing: 1.2,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1942),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0B1942).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Build smarter. Manage better.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
