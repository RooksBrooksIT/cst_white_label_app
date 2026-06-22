import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/splash_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/main_dashboard.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/Organisation_LoginPage.dart';
import 'package:demo_cst/screens/config_login.dart';
import 'package:demo_cst/screens/supervisor_login_page.dart';
import 'package:demo_cst/screens/customer_login_page.dart';
import 'package:demo_cst/screens/reset_password_screen.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/Organisation_RegistrationPage.dart';
import 'package:demo_cst/screens/organisation_landing_page.dart';
import 'package:demo_cst/screens/join_by_referral_page.dart';
import 'package:demo_cst/screens/landing_page.dart';
import 'package:demo_cst/screens/org_menu_screen.dart';
import 'package:demo_cst/screens/branding_edit_screen.dart';
import 'package:demo_cst/screens/contact_support_screen.dart';
import 'package:demo_cst/widgets/connectivity_wrapper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirestoreService.initialize();
  await AppTheme.initialize();
  await AuthService.initialize();

  // Initialize FCM: request permissions, foreground listener
  await NotificationService.initialize(navigatorKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primary, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppTheme.appName,
          builder: (context, name, _) {
            return MaterialApp(
              title: name,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getTheme(primary),
              navigatorKey: navigatorKey,
              builder: (context, child) {
                return ConnectivityWrapper(child: child!);
              },
              // Define initial route
              initialRoute: '/',

              // Define app routes
              routes: {
                '/': (context) => const SplashScreen(),
                '/landing': (context) => const LandingPage(),
                '/authSelection': (context) =>
                    const MainDashboard(), // Role selection screen
                '/orgLogin': (context) => const Organisation_LoginPage(),
                '/managerLogin': (context) => const ConfigLoginPage(),
                '/supervisorLogin': (context) => const SupervisorLoginPage(),
                '/customerLogin': (context) => const CustomerLoginPage(),
                '/resetPassword': (context) => const ResetPasswordScreen(),
                '/orgDashboard': (context) => const OrganizationDashboard(),
                '/orgRegistration': (context) =>
                    const OrganisationLandingPage(),
                '/orgRegistrationForm': (context) =>
                    const OrganisationRegistrationPage(),
                '/joinByReferral': (context) => const JoinByReferralPage(),
                '/orgMenu': (context) => const OrgMenuScreen(),
                '/branding': (context) => const BrandingEditScreen(),
                '/contactSupport': (context) => const ContactSupportScreen(),
              },
            );
          },
        );
      },
    );
  }
}
