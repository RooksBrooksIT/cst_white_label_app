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
import 'package:demo_cst/screens/terms_and_conditions_screen.dart';

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

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _checkLoginAndSync();
  }

  Future<void> _checkLoginAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('org_isLoggedIn') ?? false;
    final orgId = prefs.getString('org_dynamic_path');
    final hasAcceptedTerms = prefs.getBool('has_accepted_terms') ?? false;

    if (isLoggedIn && orgId != null && orgId.isNotEmpty) {
      // Refresh branding from Firestore if logged in
      await AppTheme.syncWithFirestore(orgId);
    }

    // After animation and sync, navigate
    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (mounted) {
        if (!hasAcceptedTerms) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TermsAndConditionsScreen(),
            ),
          );
          return;
        }

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
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            children: [
              // Logo shifted slightly higher
              Expanded(
                flex: 5,
                child: Align(
                  alignment: const Alignment(0, -0.2), // Shift slightly up from center
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/images/splash_screen_logo.png',
                        width: 200, // Increased size for better balance
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // App name at bottom
              Opacity(
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
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Build smarter. Manage better.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
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
