import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../utils/responsive.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showReferralDialog() {
    final TextEditingController codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Join Organization',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the referral code provided by your organization administrator.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: Responsive.fontSize(context, 13),
                ),
              ),
              const SizedBox(height: 20),
              GlassTextField(
                controller: codeController,
                label: 'Referral Code',
                icon: Icons.confirmation_number_rounded,
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
            SizedBox(
              width: 100,
              child: GlassButton(
                label: 'JOIN',
                isLoading: isLoading,
                onPressed: () async {
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      onBack: () => {}, // Disable back on welcome if needed, or just let it pop
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 40,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Area
              Container(
                width: Responsive.isMobile(context) ? 100 : 120,
                height: Responsive.isMobile(context) ? 100 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              ValueListenableBuilder<String>(
                valueListenable: AppTheme.appName,
                builder: (context, name, _) {
                  return Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 36),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -1.0,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Streamlining Construction Excellence',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 64),

              // Buttons
              GlassButton(
                label: 'LOGIN',
                onPressed: () => Navigator.pushNamed(context, '/authSelection'),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'REGISTER ORGANIZATION',
                isSecondary: true,
                onPressed: () =>
                    Navigator.pushNamed(context, '/orgRegistration'),
              ),
              const SizedBox(height: 32),

              TextButton.icon(
                onPressed: _showReferralDialog,
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                label: Text(
                  'Join using referral code',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
