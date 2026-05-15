import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/enums.dart';
import '../services/auth_service.dart';


class PricingScreen extends StatefulWidget {
  final String orgName;
  final String email;
  final String phone;
  final String username;
  final String password;
  final String dateStr;
  final String appName;
  final Color selectedColor;

  const PricingScreen({
    super.key,
    required this.orgName,
    required this.email,
    required this.phone,
    required this.username,
    required this.password,
    required this.dateStr,
    required this.appName,
    required this.selectedColor,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final String orgReferralCode =
          await FirestoreService.generateUniqueReferralCode();

      // Sanitize orgName to create a valid Firestore document ID
      final String sanitizedOrgName = widget.orgName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_]'),
        '_',
      );
      final String orgId = '${sanitizedOrgName}_${widget.dateStr}';

      // Simplified path for organization details
      final String orgConfigDocPath = 'organisation/$orgId/data/admin';

      // Subscription dates
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));

      // Write to Firestore
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orgRef =
            FirebaseFirestore.instance.collection('organisation').doc(orgId);
        final adminColl = orgRef.collection('admin');

        // 1. Branding Document
        transaction.set(adminColl.doc('branding'), {
          'appName': widget.appName,
          'primaryColor': AppTheme.colorToHex(widget.selectedColor),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Data Document (Credentials & Info)
        transaction.set(adminColl.doc('data'), {
          'orgName': widget.orgName,
          'email': widget.email,
          'phone': widget.phone,
          'username': widget.username,
          'password': widget.password,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Referral Document
        transaction.set(adminColl.doc('referral'), {
          'referralCode': orgReferralCode,
          'orgReferralCode': orgReferralCode,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Subscription Document
        transaction.set(adminColl.doc('subscription'), {
          'subscriptionPlan': '30 days',
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'isSubscriptionActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also add the admin as the first entry in the organizationUser subcollection
        transaction.set(
          orgRef.collection('organizationUser').doc(widget.username),
          {
            'username': widget.username,
            'password': widget.password,
            'role': 'admin',
            'orgId': orgId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      // Auto-login using AuthService to ensure all unified keys are set
      await AuthService().login(UserRole.organization, {
        'username': widget.username,
        'dynamicPath': orgId,
        'org_name': widget.orgName,
        'org_doc_path': orgConfigDocPath,
      });

      // Crucial: Initialize FirestoreService with the new orgId so it uses the correct path immediately
      await FirestoreService.initialize();

      // Apply the new branding globally immediately after successful registration
      await AppTheme.updateTheme(widget.selectedColor);
      await AppTheme.updateAppName(widget.appName);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            final colorScheme = theme.colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
              actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00A86B),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Registration Successful!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your organization referral code is:',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          orgReferralCode,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: orgReferralCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Referral code copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          label: Text(
                            'Copy Code',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share this code with your managers and supervisors so they can join your organization.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CONTINUE TO DASHBOARD',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OrganizationDashboard(),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      String errorMsg = 'Registration failed. Please try again.';

      if (e.toString().contains('permission-denied')) {
        errorMsg = 'Permission denied. Please check Firestore security rules.';
      } else if (e.toString().contains('index')) {
        errorMsg = 'Firestore index required. Click to copy creation link.';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
            action: e.toString().contains('http')
                ? SnackBarAction(
                    label: 'COPY LINK',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error copied to clipboard!'),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(widget.selectedColor),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return GlassScaffold(
            title: 'Pricing',
            onBack: () => Navigator.pop(context),
            body: Column(
              children: [
                const SizedBox(height: 24),
                // Step Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildStepIndicator(theme),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Choose a Plan',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start growing your business with zero upfront cost',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 40),

                        // Pricing Card
                        GlassCard(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00A86B,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    color: Color(0xFF00A86B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '30 Days Free Trial',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Full access to all features to see if we\'re the right fit for your organization. No credit card required.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Divider(),
                              const SizedBox(height: 32),
                              _buildFeatureRow('Unlimited user seats', theme),
                              const SizedBox(height: 16),
                              _buildFeatureRow(
                                'Advanced reporting & analytics',
                                theme,
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureRow('Custom branding tools', theme),
                              const SizedBox(height: 16),
                              _buildFeatureRow('Priority 24/7 support', theme),
                              const SizedBox(height: 40),

                              // Register Final Actions
                              GlassButton(
                                label: 'START FREE TRIAL',
                                isLoading: _isLoading,
                                onPressed: _register,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureRow(String text, ThemeData theme) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF00A86B),
          size: 22,
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
      ],
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 2;
    final primaryColor = theme.primaryColor;
    final colorScheme = theme.colorScheme;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: activeStep >= i ~/ 2 + 1
                    ? primaryColor
                    : colorScheme.outlineVariant,
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < activeStep;
        final active = idx == activeStep;

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? primaryColor : colorScheme.surface,
                border: Border.all(
                  color: done || active ? primaryColor : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              steps[idx],
              style: theme.textTheme.labelMedium?.copyWith(
                color: active || done
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
