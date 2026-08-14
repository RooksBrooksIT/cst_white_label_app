import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/terms_helper.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class OrganizationSubscriptionPage extends StatefulWidget {
  const OrganizationSubscriptionPage({super.key});

  @override
  State<OrganizationSubscriptionPage> createState() =>
      _OrganizationSubscriptionPageState();
}

class _OrganizationSubscriptionPageState
    extends State<OrganizationSubscriptionPage> {
  bool _isLoading = true;
  String _planName = 'Loading...';
  String _status = 'Loading...';
  String _expiryDate = 'Loading...';
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      var doc = await FirestoreService.subscriptionDoc.get();

      if (!doc.exists) {
        debugPrint('OrganizationSubscriptionPage: Subscription doc not found in admin, falling back to root.');
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _planName = _formatPlanName(data['subscriptionPlan'] ?? 'Free Trial');
          
          final isActiveField = data['isSubscriptionActive'] as bool? ?? true;
          final expiry = data['subscriptionEndDate'] as Timestamp?;
          
          bool isExpired = false;
          if (expiry != null) {
            isExpired = DateTime.now().isAfter(expiry.toDate());
            _expiryDate = DateFormat('dd MMM yyyy').format(expiry.toDate());
          } else {
            _expiryDate = 'Lifetime';
          }

          _isActive = isActiveField && !isExpired;
          _status = _isActive ? 'Active' : 'Inactive';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription data: $e');
      if (mounted) {
        setState(() {
          _planName = 'Free Trial';
          _status = 'Active';
          _expiryDate = '22 Aug 2026';
          _isActive = true;
          _isLoading = false;
        });
      }
    }
  }

  String _formatPlanName(String raw) {
    if (raw.trim().isEmpty) return 'Free Trial';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return PopScope(
      canPop: _isActive,
      child: GlassScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: _isActive ? () => Navigator.pop(context) : null,
                      ),
                    ),
                    Text(
                      'Manage Subscription',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF0A183D)),
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Current Plan Section Card
                                _buildCurrentPlanCard(darkCardBg),

                                const SizedBox(height: 20),

                                // 2. Plan Features Section Card
                                _buildPlanDetailsSection(darkCardBg),

                                const SizedBox(height: 20),

                                // 3. Need to Change Plan Section Card
                                _buildSupportSection(darkCardBg),

                                const SizedBox(height: 24),

                                // Terms & Conditions Link
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      TermsHelper.showTermsDialog(
                                        context,
                                        onAccepted: () {},
                                        readOnly: true,
                                      );
                                    },
                                    child: const Text(
                                      'View Terms & Conditions & Refund Policy',
                                      style: TextStyle(
                                        color: Color(0xFF1E88E5),
                                        decoration: TextDecoration.underline,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 100),
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
    );
  }

  Widget _buildCurrentPlanCard(Color darkCardBg) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkCardBg.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isActive ? Icons.stars_rounded : Icons.warning_rounded,
              color: _isActive ? const Color(0xFF10B981) : Colors.orangeAccent,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _planName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _isActive ? const Color(0xFF10B981) : Colors.orangeAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Next Billing Date',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              Text(
                _expiryDate,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailsSection(Color darkCardBg) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkCardBg.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'PLAN FEATURES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildFeatureItem('Unlimited Projects & Sites'),
          const SizedBox(height: 12),
          _buildFeatureItem('Real-time Financial Tracking'),
          const SizedBox(height: 12),
          _buildFeatureItem('Dynamic Report Generation'),
          const SizedBox(height: 12),
          _buildFeatureItem('Custom Branding Tools'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF10B981),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(Color darkCardBg) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkCardBg.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Need to change your plan?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Contact our support team to upgrade your subscription or manage billing details.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/contactSupport');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B1942),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF0B1942).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'CONTACT SUPPORT',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
