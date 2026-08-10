import 'package:demo_cst/screens/organization/org_reset_password_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/organization/org_information_screen.dart';
import 'package:demo_cst/screens/common/about_us_screen.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class OrgMenuScreen extends StatefulWidget {
  final bool standalone;
  const OrgMenuScreen({super.key, this.standalone = true});

  @override
  State<OrgMenuScreen> createState() => _OrgMenuScreenState();
}

class _OrgMenuScreenState extends State<OrgMenuScreen> {
  String _orgName = '';
  String _orgCode = 'Loading...';
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

      final referralDoc = await FirestoreService.referralDoc.get();

      String? code;
      if (referralDoc.exists) {
        final refData = referralDoc.data()!;
        code =
            refData['orgReferralCode'] as String? ??
            refData['referralCode'] as String?;
      }

      if (code == null || code.isEmpty) {
        final rootDoc = await FirestoreService.rootOrgDoc.get();
        if (rootDoc.exists) {
          final rootData = rootDoc.data()!;
          code =
              rootData['orgReferralCode'] as String? ??
              rootData['referralCode'] as String?;
        }
      }

      if (mounted) {
        setState(() {
          _orgCode = (code != null && code.isNotEmpty) ? code : 'Not Set';
        });
      }

      final subDoc = await FirestoreService.subscriptionDoc.get();

      if (subDoc.exists && mounted) {
        final subData = subDoc.data()!;
        setState(() {
          _subscriptionPlan = subData['subscriptionPlan'] ?? 'No Plan';
          _isSubscriptionActive = subData['isSubscriptionActive'] ?? false;

          final expiry = subData['subscriptionEndDate'];
          if (expiry is Timestamp) {
            _subscriptionExpiry = DateFormat(
              'dd MMM yyyy',
            ).format(expiry.toDate());
          } else {
            _subscriptionExpiry = 'Never';
          }
        });
      } else if (mounted) {
        final rootDoc = await FirestoreService.rootOrgDoc.get();
        if (rootDoc.exists && mounted) {
          final rootData = rootDoc.data()!;
          setState(() {
            _subscriptionPlan = rootData['subscriptionPlan'] ?? 'No Plan';
            _isSubscriptionActive = rootData['isSubscriptionActive'] ?? false;
            final expiry = rootData['subscriptionEndDate'];
            if (expiry is Timestamp) {
              _subscriptionExpiry = DateFormat(
                'dd MMM yyyy',
              ).format(expiry.toDate());
            } else {
              _subscriptionExpiry = 'Never';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      if (mounted) {
        setState(() {
          _orgCode = 'Not Available';
          _subscriptionPlan = 'Error';
        });
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              _buildReferralSection(theme),
              const SizedBox(height: 20),
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
      return content;
    }

    return GlassScaffold(
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection(ThemeData theme) {
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Referral Program',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Share these codes with your team members to register them under your organization.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _buildCodeRow('REFERRAL', _orgCode, theme),
        ],
      ),
    );
  }

  Widget _buildCodeRow(String label, String code, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF0A183D),
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppTheme.showSuccessToast(context, '$label code copied!');
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
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
              fontSize: 17,
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
              if (context.mounted) {
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
              fontSize: 17,
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
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: const Text(
          'LOGOUT',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/authSelection',
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
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkCardBg.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCBD5E1),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 20,
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
