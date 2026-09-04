import 'package:demo_cst/screens/organization/org_reset_password_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/organization/org_information_screen.dart';
import 'package:demo_cst/screens/common/about_us_screen.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';

class OrgMenuScreen extends StatefulWidget {
  final bool standalone;
  const OrgMenuScreen({super.key, this.standalone = true});

  @override
  State<OrgMenuScreen> createState() => _OrgMenuScreenState();
}

class _OrgMenuScreenState extends State<OrgMenuScreen> {
  String _subscriptionPlan = 'Loading...';
  String _subscriptionExpiry = '';
  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    _fetchOrgData();
  }

  Future<void> _fetchOrgData() async {
    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      // Fetch subscription status
      try {
        final subDoc = await FirestoreService.subscriptionDoc.get();
        if (subDoc.exists && mounted) {
          final data = subDoc.data();
          setState(() {
            _subscriptionPlan = data?['planName'] ?? 'Pro Plan';
            final expiry = data?['expiresAt'];
            if (expiry != null && expiry is Timestamp) {
              _subscriptionExpiry = DateFormat('dd MMM yyyy').format(expiry.toDate());
              _isSubscriptionActive = expiry.toDate().isAfter(DateTime.now());
            } else {
              _subscriptionExpiry = 'Active';
              _isSubscriptionActive = true;
            }
          });
        } else if (mounted) {
          setState(() {
            _subscriptionPlan = 'Standard Plan';
            _subscriptionExpiry = 'Active';
            _isSubscriptionActive = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _subscriptionPlan = 'Standard Plan';
            _subscriptionExpiry = 'Active';
            _isSubscriptionActive = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching org data in menu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 600,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            children: [
              _buildSettingsSection(theme),
              const SizedBox(height: 20),
              _buildSubscriptionSection(theme),
              const SizedBox(height: 28),
              _buildLogoutSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (!widget.standalone) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: content,
      );
    }

    final darkAccent = AppTheme.getDarkAccent(theme.primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBody: true,
      bottomNavigationBar: const BottomNav(currentIndex: 4),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Organization Menu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  theme.primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: content,
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 10.0),
          child: Text(
            'Settings & Customization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A183D),
              letterSpacing: -0.3,
            ),
          ),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.business_rounded,
          iconColor: const Color(0xFF1E88E5),
          title: 'Organisation Information',
          subtitle: 'Update address and phone details',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrgInformationScreen(),
            ),
          ),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.color_lens_outlined,
          iconColor: const Color(0xFF10B981),
          title: 'Brand Color',
          subtitle: 'Change app theme color',
          onTap: () => Navigator.pushNamed(context, '/branding'),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.lock_reset_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'Reset Password',
          subtitle: 'Update your account password',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrgResetPasswordScreen(),
            ),
          ),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.headset_mic_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'Contact Support',
          subtitle: 'Get help from our team',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContactSupportScreen(),
            ),
          ),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.privacy_tip_rounded,
          iconColor: const Color(0xFF06B6D4),
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          onTap: () async {
            final Uri url = Uri.parse(
              'https://sites.google.com/view/cst-whitelabel-app/home',
            );
            if (!await launchUrl(url)) {
              if (mounted) {
                AppTheme.showErrorToast(context, 'Could not open privacy policy');
              }
            }
          },
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFFEC4899),
          title: 'About Us',
          subtitle: 'Learn more about eBricks',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutUsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 10.0),
          child: Text(
            'Billing & Membership',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A183D),
              letterSpacing: -0.3,
            ),
          ),
        ),
        _buildSettingsTile(
          theme: theme,
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFF10B981),
          title: 'Manage Subscription',
          subtitle: _isSubscriptionActive
              ? 'Active: $_subscriptionPlan (Expires: $_subscriptionExpiry)'
              : 'Current: $_subscriptionPlan (Inactive)',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationSubscriptionPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutConfirmation(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
        label: const Text(
          'LOGOUT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 2,
          shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to log out of your organization account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5A759E),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF0A183D), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                      shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'YES, LOGOUT',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await AuthService().logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('org_isLoggedIn');
      await prefs.remove('org_username');

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/landing',
          (route) => false,
        );
      }
    }
  }

  Widget _buildSettingsTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                // Icon Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
