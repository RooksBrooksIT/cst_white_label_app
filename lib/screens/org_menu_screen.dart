import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';
import 'contact_support_screen.dart';
import 'org_reset_password_screen.dart';
import 'org_subscription_page.dart';


class OrgMenuScreen extends StatefulWidget {
  /// When [standalone] is true (default), the screen is shown as a separate
  /// pushed route with its own AppBar. When false, it is embedded inside the
  /// OrganizationDashboard as the Profile tab – no AppBar is rendered.
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
      // Fetch referal codes using centralized FirestoreService path resolution
      final referalDoc = await FirestoreService.referralDoc.get();

      if (referalDoc.exists && mounted) {
        final refData = referalDoc.data()!;
        setState(() {
          _orgCode =
              refData['orgReferralCode'] ??
              refData['referralCode'] ??
              'Not Set';
        });
      }

      // Fetch subscription data
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
      }
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      if (mounted) {
        setState(() {
          _orgCode = 'Error';
          _subscriptionPlan = 'Error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 20.0 : 32.0),
      child: Column(
        children: [
          _buildProfileSection(colorScheme),
          const SizedBox(height: 32),
          _buildReferralSection(colorScheme),
          const SizedBox(height: 16),
          _buildSettingsSection(colorScheme),
          const SizedBox(height: 16),
          _buildSubscriptionSection(colorScheme),
          const SizedBox(height: 32),
          _buildLogoutSection(colorScheme),
          const SizedBox(height: 24),
        ],
      ),
    );

    // When embedded (standalone == false) just return the scrollable body.
    if (!widget.standalone) {
      return content;
    }

    // Standalone: wrap in a full Scaffold with AppBar.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Menu',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildProfileSection(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary.withOpacity(0.12),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Icon(Icons.business, color: colorScheme.primary, size: 40),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String>(
          valueListenable: AppTheme.appName,
          builder: (context, name, _) {
            return Text(
              _orgName.isNotEmpty ? _orgName : name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1E293B),
                fontSize: Responsive.fontSize(context, 24),
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReferralSection(ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share_rounded, color: colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Referral Program',
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Share these codes with your team members to register them under your organization.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildCodeRow('Referral', _orgCode, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCodeRow(String label, String code, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label code copied!')),
                  );
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

  Widget _buildSettingsSection(ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_suggest_rounded,
                color: colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Settings',
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.color_lens_outlined,
            title: 'Brand Color',
            subtitle: 'Change app theme color',
            onTap: () => Navigator.pushNamed(context, '/branding'),
          ),

          const Divider(color: Color(0xFFF1F5F9), height: 24),
          _buildSettingsTile(
            icon: Icons.lock_reset_rounded,
            title: 'Reset Password',
            subtitle: 'Update your account password',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrgResetPasswordScreen(),
              ),
            ),
          ),

          const Divider(color: Color(0xFFF1F5F9), height: 24),
          _buildSettingsTile(
            icon: Icons.headset_mic_rounded,
            title: 'Contact Support',
            subtitle: 'Get help from our team',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ContactSupportScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: colorScheme.tertiary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Subscription',
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.account_balance_wallet_outlined,
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
      ),
    );
  }

  Widget _buildLogoutSection(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutConfirmation(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        label: const Text(
          'LOGOUT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      // Clear global auth state
      await AuthService().logout();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('org_isLoggedIn');
      await prefs.remove('org_username');
      // We keep branding keys so the login screen stays branded for the org

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
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF64748B)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          : null,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
      onTap: onTap,
    );
  }
}
