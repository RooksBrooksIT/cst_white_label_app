import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'Organization_Dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/enums.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../utils/terms_helper.dart';

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
  String _selectedPlanType = 'Monthly';
  String _selectedPlan = 'Silver';
  int _goldProjectsCount = 10;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      // 1. Create Firebase Auth account first
      final userCredential = await AuthService().registerWithEmail(
        widget.email,
        widget.password,
      );
      final String uid = userCredential.user!.uid;

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
      final DateTime endDate;
      if (_selectedPlanType == 'Free Trial') {
        endDate = now.add(const Duration(days: 14));
      } else if (_selectedPlanType == '6 Months') {
        endDate = now.add(const Duration(days: 180));
      } else if (_selectedPlanType == 'Yearly') {
        endDate = now.add(const Duration(days: 365));
      } else {
        endDate = now.add(const Duration(days: 30));
      }

      // Write to Firestore
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orgRef = FirebaseFirestore.instance
            .collection('organisation')
            .doc(orgId);

        // Structure: /organisation/{orgId}/data/{docName}
        // This matches the "admin document, data collection" requirement
        final dataColl = orgRef.collection('data');

        // 1. Branding Document
        transaction.set(dataColl.doc('branding'), {
          'appName': widget.appName,
          'primaryColor': AppTheme.colorToHex(widget.selectedColor),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Admin (Data) Document (Credentials & Info)
        transaction.set(dataColl.doc('admin'), {
          'orgName': widget.orgName,
          'email': widget.email,
          'phone': widget.phone,
          'username': widget.username,
          'password': widget.password,
          'uid': uid, // Store Firebase Auth UID
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Referral Document
        transaction.set(dataColl.doc('referral'), {
          'referralCode': orgReferralCode,
          'orgReferralCode': orgReferralCode,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Subscription Document
        transaction.set(dataColl.doc('subscription'), {
          'subscriptionPlan': _selectedPlan.toLowerCase(),
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'isSubscriptionActive': true,
          'maxProjects': _selectedPlan == 'Gold'
              ? _goldProjectsCount
              : _selectedPlan == 'Silver'
              ? 3
              : _selectedPlan == 'Platinum'
              ? 99999
              : 1, // Free Trial
          'maxUsers': _selectedPlan == 'Gold'
              ? (_goldProjectsCount * 1.5).round()
              : _selectedPlan == 'Silver'
              ? 5
              : _selectedPlan == 'Platinum'
              ? 99999
              : 2, // Free Trial
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
            'uid': uid, // Store Firebase Auth UID
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
            final screenWidth = MediaQuery.of(ctx).size.width;
            final isMobile = screenWidth < 600;
            final isDesktop = screenWidth >= 1024;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: EdgeInsets.fromLTRB(
                isDesktop ? 48 : 32,
                isDesktop ? 36 : 28,
                isDesktop ? 48 : 32,
                isDesktop ? 16 : 12,
              ),
              actionsPadding: EdgeInsets.fromLTRB(
                isDesktop ? 48 : 32,
                0,
                isDesktop ? 48 : 32,
                isDesktop ? 32 : 24,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFF00A86B),
                      size: isDesktop ? 60 : 48,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 24 : 20),
                  Text(
                    'Registration Successful!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 26 : 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 16 : 12),
                  Text(
                    'Your organization referral code is:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isDesktop ? 17 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 20 : 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 20 : 16,
                      horizontal: isDesktop ? 24 : 20,
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
                            fontSize: isDesktop ? 36 : 28,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isDesktop ? 12 : 8),
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
                            size: isDesktop ? 22 : 18,
                          ),
                          label: Text(
                            'Copy Code',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isDesktop ? 20 : 16),
                  Text(
                    'Share this code with your managers and supervisors so they can join your organization.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontSize: isDesktop ? 15 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(bottom: isDesktop ? 8 : 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isDesktop ? 18 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'CONTINUE TO DASHBOARD',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              fontSize: isDesktop ? 16 : 14,
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

      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          errorMsg = 'This email address is already in use by another account.';
        } else if (e.code == 'invalid-email') {
          errorMsg = 'The email address is not valid.';
        } else if (e.code == 'weak-password') {
          errorMsg = 'The password is too weak.';
        } else {
          errorMsg = 'Authentication error: ${e.message}';
        }
      } else if (e.toString().contains('permission-denied')) {
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
                          duration: Duration(seconds: 2),
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

  String _formatPrice(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
    final maxContentWidth = 800.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isDesktop ? 32.0 : 20.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme, isMobile, isTablet, isDesktop),
                            SizedBox(height: isDesktop ? 24.0 : 20.0),
                            _buildSubtitle(
                              theme,
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24.0 : 20.0),
                            _buildPlanTabs(
                              theme,
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24.0 : 20.0),
                            _buildPlanCards(
                              theme,
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            padding: const EdgeInsets.all(16),
          ),
        ),
        SizedBox(width: isDesktop ? 24.0 : 16.0),
        Text(
          'Choose Your Plan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 28.0 : 24.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Text(
      'Manage projects smarter with the right plan',
      style: theme.textTheme.titleMedium?.copyWith(
        color: Colors.black54,
        fontSize: isDesktop ? 18.0 : 16.0,
      ),
    );
  }

  Widget _buildPlanTabs(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final colorScheme = theme.colorScheme;
    final tabs = ['Free Trial', 'Monthly', '6 Months', 'Yearly'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = _selectedPlanType == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlanType = tab;
                  if (tab == 'Free Trial') {
                    _selectedPlan = 'Free Trial';
                  } else {
                    _selectedPlan = 'Silver';
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 12.0 : 10.0,
                  horizontal: isMobile ? 4.0 : 8.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: isDesktop ? 16.0 : (isMobile ? 12.0 : 14.0),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCards(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final isFreeTrial = _selectedPlanType == 'Free Trial';
    final is6Months = _selectedPlanType == '6 Months';
    final isYearly = _selectedPlanType == 'Yearly';

    if (isFreeTrial) {
      return Column(
        children: [
          _buildPlanCard(
            theme,
            isMobile,
            isTablet,
            isDesktop,
            'Free Trial',
            'Experience our platform for 14 days',
            'Free',
            '',
            [
              'Basic Project Management',
              'Task Tracking',
              'Limited Team Members',
              'Basic Reports',
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildPlanCard(
          theme,
          isMobile,
          isTablet,
          isDesktop,
          'Silver',
          'For small teams starting out',
          is6Months
              ? '₹1,194'
              : isYearly
              ? '₹2,388'
              : '₹199',
          is6Months
              ? '₹1,794'
              : isYearly
              ? '₹3,588'
              : '₹299',
          [
            'Basic Project Management',
            'Task Tracking',
            'Limited Team Members (3-5)',
            'Basic Reports',
          ],
        ),
        SizedBox(height: isDesktop ? 20.0 : 16.0),
        _buildPlanCard(
          theme,
          isMobile,
          isTablet,
          isDesktop,
          'Gold',
          'Comprehensive management',
          is6Months
              ? _formatPrice((_goldProjectsCount * 599.4).round())
              : isYearly
              ? _formatPrice((_goldProjectsCount * 1198.8).round())
              : _formatPrice((_goldProjectsCount * 99.9).round()),
          is6Months
              ? _formatPrice((_goldProjectsCount * 899.4).round())
              : isYearly
              ? _formatPrice((_goldProjectsCount * 1798.8).round())
              : _formatPrice((_goldProjectsCount * 149.9).round()),
          [
            'Up to $_goldProjectsCount Projects & Active Sites',
            'Up to ${(_goldProjectsCount / 2).round().clamp(2, 25)} Managers',
            'Up to $_goldProjectsCount Supervisors',
            'Advanced collaboration',
            'Site monitoring & Expense tracking',
            'Monthly report views',
          ],
        ),
        SizedBox(height: isDesktop ? 20.0 : 16.0),
        _buildPlanCard(
          theme,
          isMobile,
          isTablet,
          isDesktop,
          'Platinum',
          'For enterprise scale',
          is6Months
              ? '₹10,794'
              : isYearly
              ? '₹21,588'
              : '₹1,799',
          is6Months
              ? '₹14,994'
              : isYearly
              ? '₹29,988'
              : '₹2499',
          [
            'Medium teams (up to 20)',
            'Advanced collaboration',
            'Site monitoring',
            'Expense tracking',
            'Monthly reports',
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    String planName,
    String description,
    String price,
    String originalPrice,
    List<String> features,
  ) {
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedPlan == planName;
    final isFreeTrial = _selectedPlanType == 'Free Trial';
    final is6Months = _selectedPlanType == '6 Months';
    final isYearly = _selectedPlanType == 'Yearly';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = planName;
        });
      },
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.blue : const Color(0xFFE0E0E0),
            width: isSelected ? 3.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: isDesktop ? 28.0 : 24.0,
                        height: isDesktop ? 28.0 : 24.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey[400]!,
                            width: 2.0,
                          ),
                          color: isSelected ? Colors.blue : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.circle,
                                size: isDesktop ? 14.0 : 12.0,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(width: isDesktop ? 16.0 : 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 26.0 : 22.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: isDesktop ? 15.0 : 13.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isDesktop ? 16.0 : 8.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 32.0 : 28.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (originalPrice.isNotEmpty) ...[
                      SizedBox(height: 4.0),
                      Text(
                        originalPrice,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: isDesktop ? 16.0 : 14.0,
                          decoration: TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4.0),
                    Text(
                      isFreeTrial
                          ? '14-day trial'
                          : is6Months
                          ? '6 month'
                          : isYearly
                          ? 'Per year'
                          : 'Per month',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isDesktop ? 14.0 : 12.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isSelected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (planName == 'Gold') ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customize Projects Limit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isDesktop ? 16.0 : 14.0,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_goldProjectsCount Projects',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isDesktop ? 14.0 : 12.0,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blue,
                              inactiveTrackColor: Colors.grey[200],
                              thumbColor: Colors.blue,
                              overlayColor: Colors.blue.withOpacity(0.1),
                              valueIndicatorColor: Colors.blue,
                              valueIndicatorTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            child: Slider(
                              value: _goldProjectsCount.toDouble(),
                              min: 5.0,
                              max: 50.0,
                              divisions: 45,
                              label: '$_goldProjectsCount Projects',
                              onChanged: (double newValue) {
                                setState(() {
                                  _goldProjectsCount = newValue.round();
                                });
                              },
                            ),
                          ),
                        ],
                        if (features.isNotEmpty) ...[
                          SizedBox(height: isDesktop ? 20.0 : 16.0),
                          ...features.map((feature) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: isDesktop ? 10.0 : 8.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.description_rounded,
                                    size: isDesktop ? 20.0 : 18.0,
                                    color: Colors.black54,
                                  ),
                                  SizedBox(width: isDesktop ? 12.0 : 10.0),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16.0 : 14.0,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        SizedBox(height: isDesktop ? 20.0 : 16.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isDesktop ? 18.0 : 14.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: isDesktop ? 24.0 : 20.0,
                                    width: isDesktop ? 24.0 : 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isFreeTrial
                                        ? 'Start Free Trial'
                                        : 'Upgrade to $planName',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isDesktop ? 16.0 : 14.0,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              TermsHelper.showTermsDialog(
                                context,
                                onAccepted: () {},
                                readOnly: true,
                              );
                            },
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: isDesktop ? 12.0 : 11.0,
                                  color: Colors.grey[600],
                                  fontFamily:
                                      theme.textTheme.bodyMedium?.fontFamily,
                                ),
                                children: [
                                  TextSpan(
                                    text: isFreeTrial
                                        ? 'By starting the trial, you agree to our '
                                        : 'By upgrading, you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms & Conditions & Refund Policy',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
