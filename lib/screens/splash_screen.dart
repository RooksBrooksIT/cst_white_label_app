import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        Navigator.pushReplacementNamed(context, '/letsStart');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add the splash screen logo image
            Image.asset(
              'assets/images/splash_screen_logo.png',
              width: 250, // Adjust width as needed
              height: 250, // Adjust height as needed
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to Construct Pro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            CircularProgressIndicator(
              valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF0b3470)),

            ),
          ],
        ),
      ),
    );
  }
}
