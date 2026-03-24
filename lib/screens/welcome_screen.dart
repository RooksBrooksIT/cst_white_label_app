import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _showReferralDialog() {
    final TextEditingController codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Join Organization',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the referral code provided by your organization administrator.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Referral Code',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white60,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF017FDF)),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        final referralDoc = await FirebaseFirestore.instance
                            .collection('referralCodes')
                            .doc(code)
                            .get();

                        if (referralDoc.exists) {
                          final dynamicPath =
                              referralDoc.data()?['dynamicPath'] as String?;
                          if (dynamicPath != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('temp_org_path', dynamicPath);

                            if (mounted) {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/authSelection');
                            }
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid referral code'),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF017FDF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'JOIN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); // Removed unused variable
    const primary = Color(0xFF017FDF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF001D3D), Color(0xFF003768), Color(0xFF005A9E)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.scaleH(context, 0.08),
              vertical: Responsive.scaleV(context, 0.04),
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo and Title Area
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.construction_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ValueListenableBuilder<String>(
                          valueListenable: AppTheme.appName,
                          builder: (context, name, _) {
                            return Text(
                              name,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 32),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Streamlining Construction Excellence',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                // Buttons Area
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildButton(
                        context: context,
                        text: 'LOGIN',
                        isPrimary: true,
                        onPressed: () =>
                            Navigator.pushNamed(context, '/authSelection'),
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        context: context,
                        text: 'REGISTER ORGANIZATION',
                        isPrimary: false,
                        onPressed: () =>
                            Navigator.pushNamed(context, '/orgRegistration'),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: _showReferralDialog,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: const Text(
                          'Join using referral code',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? const Color(0xFF017FDF)
              : Colors.transparent,
          foregroundColor: Colors.white,
          elevation: isPrimary ? 4 : 0,
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: Colors.white30, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
