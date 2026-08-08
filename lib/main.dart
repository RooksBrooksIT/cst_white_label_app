import 'package:demo_cst/screens/organization/organisation_landing_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/common/splash_screen.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/common/main_dashboard.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/organization/organisation_login_page.dart';
import 'package:demo_cst/screens/common/config_login.dart';
import 'package:demo_cst/screens/supervisor/supervisor_login_page.dart';
import 'package:demo_cst/screens/customer/customer_login_page.dart';
import 'package:demo_cst/screens/common/reset_password_screen.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/organization/organisation_registration_page.dart';
import 'package:demo_cst/screens/common/landing_page.dart';
import 'package:demo_cst/screens/common/join_by_referral_page.dart';
import 'package:demo_cst/screens/common/landing_page.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/branding/branding_edit_screen.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
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
