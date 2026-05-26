import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'Organization_Dashboard.dart';
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
        final orgRef = FirebaseFirestore.instance
            .collection('organisation')
            .doc(orgId);
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
        transaction
            .set(orgRef.collection('organizationUser').doc(widget.username), {
              'username': widget.username,
              'password': widget.password,
              'role': 'admin',
              'orgId': orgId,
              'createdAt': FieldValue.serverTimestamp(),
            });
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
          final headerColor = const Color(0xFF003668); // Fixed professional color

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: const Text(
                'Pricing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Column(
              children: [
                // Rectangular Header with Step Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: headerColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildStepIndicator(theme, headerColor),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section Heading
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose a Plan',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start growing your business with zero upfront cost.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Pricing Card
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Full access to all features to see if we\'re the right fit for your organization. No credit card required.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                              const SizedBox(height: 48),

                              // Register Final Actions
                              ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 32,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 54),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'START FREE TRIAL',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
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
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(ThemeData theme, Color headerColor) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isActive = activeStep == index;
        final isDone = activeStep > index;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step circle and label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? Colors.white : (isActive ? Colors.white : Colors.white24),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check, color: headerColor, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? headerColor : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Connector line
            if (index < steps.length - 1)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
                decoration: BoxDecoration(
                  color: activeStep > index ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      }),
    );
  }
}
