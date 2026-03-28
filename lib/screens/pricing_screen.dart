import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

class PricingScreen extends StatefulWidget {
  final String orgName;
  final String email;
  final String phone;
  final String username;
  final String password;
  final String dateStr;
  final String appName;
  final File? logoFile;
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
    this.logoFile,
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
      final String managerReferralCode =
          await FirestoreService.generateUniqueReferralCode();
      final String supervisorReferralCode =
          await FirestoreService.generateUniqueReferralCode();
      final String customerReferralCode =
          await FirestoreService.generateUniqueReferralCode();

      final String orgId =
          '${widget.orgName.replaceAll(' ', '_')}_${widget.dateStr}';
      
      // Simplified path for organization details
      final String orgConfigDocPath = 'organisation/$orgId/admin/data';


      // Upload logo
      String? logoUrl;
      if (widget.logoFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'org_logos/$orgId.jpg',
        );
        await ref.putFile(widget.logoFile!);
        logoUrl = await ref.getDownloadURL();
      }

      // Subscription dates
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));

      // Write to Firestore
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(FirebaseFirestore.instance.doc(orgConfigDocPath), {

          'orgName': widget.orgName,
          'appName': widget.appName,
          'email': widget.email,
          'phone': widget.phone,
          'username': widget.username,
          'password': widget.password,
          'referralCode': orgReferralCode, // Legacy support
          'orgReferralCode': orgReferralCode,
          'managerReferralCode': managerReferralCode,
          'supervisorReferralCode': supervisorReferralCode,
          'customerReferralCode': customerReferralCode,
          'primaryColor': widget.selectedColor.value.toRadixString(16),
          if (logoUrl != null) 'logoUrl': logoUrl,
          'createdAt': FieldValue.serverTimestamp(),
          // Subscription data
          'subscriptionPlan': '30_days_free_trial',
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'isSubscriptionActive': true,
        });

        transaction.set(
          FirebaseFirestore.instance
              .collection('organizationUser')
              .doc(widget.username),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId, // Store only the ID for FirestoreService
            'username': widget.username,
            'password': widget.password,
            'fullConfigPath': orgConfigDocPath,
          },

        );

        transaction.set(
          FirebaseFirestore.instance
              .collection('referralCodes')
              .doc(orgReferralCode),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId,
            'role': 'organization',
            'createdAt': FieldValue.serverTimestamp(),
            'fullConfigPath': orgConfigDocPath,
          },
        );

        transaction.set(
          FirebaseFirestore.instance
              .collection('referralCodes')
              .doc(managerReferralCode),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId,
            'role': 'manager',
            'createdAt': FieldValue.serverTimestamp(),
            'fullConfigPath': orgConfigDocPath,
          },
        );

        transaction.set(
          FirebaseFirestore.instance
              .collection('referralCodes')
              .doc(supervisorReferralCode),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId,
            'role': 'supervisor',
            'createdAt': FieldValue.serverTimestamp(),
            'fullConfigPath': orgConfigDocPath,
          },
        );

        transaction.set(
          FirebaseFirestore.instance
              .collection('referralCodes')
              .doc(customerReferralCode),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId,
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
            'fullConfigPath': orgConfigDocPath,
          },
        );
      });

      // Auto-login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('org_isLoggedIn', true);
      await prefs.setString('org_username', widget.username);
      await prefs.setString('org_dynamic_path', orgId);
      await prefs.setString('org_name', widget.orgName);
      await prefs.setString('org_doc_path', orgConfigDocPath);


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration successful! Org Code: $orgReferralCode',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OrganizationDashboard(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A86B).withOpacity(0.1),
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
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Full access to all features to see if we\'re the right fit for your organization. No credit card required.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 32),
                        _buildFeatureRow('Unlimited user seats', theme),
                        const SizedBox(height: 16),
                        _buildFeatureRow('Advanced reporting & analytics', theme),
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
  }

  Widget _buildFeatureRow(String text, ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF00A86B), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge,
          ),
        ),
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
                color: activeStep >= i ~/ 2 + 1 ? primaryColor : colorScheme.outlineVariant,
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
                          color: active ? Colors.white : colorScheme.onSurfaceVariant,
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
                color: active || done ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
