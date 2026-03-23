import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/splash_screen.dart';
import 'package:demo_cst/screens/main_dashboard.dart';
import 'package:demo_cst/screens/lets_start_page.dart';
import 'package:demo_cst/screens/Organisation_LoginPage.dart';
import 'package:demo_cst/screens/config_login.dart';
import 'package:demo_cst/screens/supervisor_login_page.dart';
import 'package:demo_cst/screens/customer_login_page.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/Organisation_RegistrationPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize AppTheme to load stored settings

  await AppTheme.initialize();
  // Start the app

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: AppTheme.primaryColor,
          builder: (context, primary, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppTheme.appName,
              builder: (context, name, _) {
                return MaterialApp(
                  title: name,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.getTheme(primary, isDark: false),
                  darkTheme: AppTheme.getTheme(primary, isDark: true),
                  themeMode: mode,

                  // Define initial route
                  initialRoute: '/',
                  // Define app routes
                  routes: {
                    '/': (context) => const SplashScreen(),
                    '/letsStart': (context) => const LetsStartPage(),
                    '/authSelection': (context) =>
                        const MainDashboard(), // Role selection screen
                    '/orgLogin': (context) => const Organisation_LoginPage(),
                    '/managerLogin': (context) => const ConfigLoginPage(),
                    '/supervisorLogin': (context) =>
                        const Supervisor_LoginPage(),
                    '/customerLogin': (context) => const CustomerLoginPage(),
                    '/orgDashboard': (context) => const OrganizationDashboard(),
                    '/orgRegistration': (context) =>
                        const OrganisationRegistrationPage(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
