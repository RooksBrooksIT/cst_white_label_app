import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import 'Organization_Dashboard.dart';

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
      final String referralCode =
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
          'referralCode': referralCode,
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
              .doc(referralCode),
          {
            'orgName': widget.orgName,
            'dynamicPath': orgId, // Store only the ID for FirestoreService
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
              'Registration successful! Referral Code: $referralCode',
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
    return GlassScaffold(
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          // Step Indicator
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 4,
            ),
            child: _buildStepIndicator(),
          ),
          const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Text(
                        'Choose a Plan',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start growing your business with zero upfront cost',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Transparent Subscription Card
                      GlassCard(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A86B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
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
                            const SizedBox(height: 20),
                            const Text(
                              '30 Days Free Trial',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Full access to all features to see if we\'re the right fit for your organization. No credit card required.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _buildFeatureRow('Unlimited user seats'),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Advanced reporting & analytics'),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Custom branding tools'),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Priority 24/7 support'),
                            const SizedBox(height: 32),
                            
                            // Register Final Actions
                            GlassButton(
                              label: 'START FREE TRIAL',
                              isLoading: _isLoading,
                              onPressed: _register,
                            ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF00A86B), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 2; // Step 3

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: activeStep > i ~/ 2
                  ? Theme.of(context).primaryColor
                  : Colors.white.withOpacity(0.2),
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
                color: done || active
                    ? Theme.of(context).primaryColor
                    : Colors.white.withOpacity(0.15),
                border: Border.all(
                  color: done || active
                      ? Theme.of(context).primaryColor
                      : Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: TextStyle(
                fontSize: 11,
                color: active || done ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
