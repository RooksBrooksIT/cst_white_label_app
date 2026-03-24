import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/app_theme.dart';
import 'organisation_loginPage.dart';

class OrgMenuScreen extends StatefulWidget {
  const OrgMenuScreen({super.key});

  @override
  State<OrgMenuScreen> createState() => _OrgMenuScreenState();
}

class _OrgMenuScreenState extends State<OrgMenuScreen> {
  String _referralCode = 'Loading...';
  String _orgName = 'Organization User';
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
      final prefs = await SharedPreferences.getInstance();
      final String? name = prefs.getString('org_name');
      if (name != null) setState(() => _orgName = name);

      // Fetch dynamic organization and subscription data
      final String? dynamicPath = prefs.getString('org_dynamic_path');
      if (dynamicPath != null && dynamicPath.isNotEmpty) {
        final orgId = dynamicPath.split('/')[0];
        final subDoc = await FirebaseFirestore.instance
            .collection('organisation')
            .doc(orgId)
            .collection('admin')
            .doc('data')
            .get();


        if (subDoc.exists) {
          final subData = subDoc.data()!;
          setState(() {
            // Handle potentially different field names for referral code
            _referralCode =
                subData['referralCode'] ??
                subData['refferal Code'] ??
                'Not Set';

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
      }
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      setState(() {
        _referralCode = 'Error';
        _subscriptionPlan = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Menu',
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildProfileSection(),
            const SizedBox(height: 32),
            _buildReferralSection(),
            const SizedBox(height: 16),
            _buildSettingsSection(),
            const SizedBox(height: 16),
            _buildSubscriptionSection(),
            const SizedBox(height: 32),
            _buildLogoutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            border: Border.all(color: Colors.white30, width: 2),
          ),
          child: const Icon(Icons.business, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          _orgName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReferralSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share_rounded, color: Colors.blue[300], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Referral Program',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Share this code with your managers and supervisors to register them under your organization.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _referralCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral code copied!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_suggest_rounded,
                color: Colors.purple[300],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: AppTheme.themeMode,
              builder: (context, mode, _) {
                return Switch(
                  value: mode == ThemeMode.dark,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    AppTheme.updateThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildSettingsTile(
            icon: Icons.color_lens_outlined,
            title: 'Brand Color',
            onTap: () => Navigator.pushNamed(context, '/branding'),
          ),

          const Divider(color: Colors.white10, height: 24),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About App',
            onTap: () {
              // Future: About page
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber[400], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Subscription',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
              // Future: Subscription management screen
            },
          ),
          // const Divider(color: Colors.white10, height: 24),
          // _buildSettingsTile(
          //   icon: Icons.history_rounded,
          //   title: 'Billing History',
          //   onTap: () {
          //     // Future: Billing history
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection() {
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
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.8),
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const Organisation_LoginPage(),
          ),
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
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            )
          : null,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: Colors.white30),
      onTap: onTap,
    );
  }
}
