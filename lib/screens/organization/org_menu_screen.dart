import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/organization/org_reset_password_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/organization/org_information_screen.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
import 'package:demo_cst/screens/common/about_us_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';

class OrgMenuScreen extends StatefulWidget {
  final bool standalone;
  const OrgMenuScreen({super.key, this.standalone = true});

  @override
  State<OrgMenuScreen> createState() => _OrgMenuScreenState();
}

class _OrgMenuScreenState extends State<OrgMenuScreen> {
  String _orgName = 'Organization Admin';
  String _orgEmail = '';
  String _orgPhone = '';
  String _subscriptionPlan = 'Pro Plan';
  String _subscriptionExpiry = 'Active';
  bool _isSubscriptionActive = true;

  @override
  void initState() {
    super.initState();
    _fetchOrgProfileData();
  }

  Future<void> _fetchOrgProfileData() async {
    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final prefs = await SharedPreferences.getInstance();
      String name = prefs.getString('org_name') ?? prefs.getString('org_username') ?? '';
      String email = prefs.getString('org_email') ?? '';
      String phone = '';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (email.isEmpty && currentUser != null && currentUser.email != null) {
        email = currentUser.email!;
      }

      // Fetch from rootOrgDoc or orgDataDoc
      try {
        final orgDoc = await FirestoreService.rootOrgDoc.get();
        if (orgDoc.exists) {
          final data = orgDoc.data()!;
          if (name.isEmpty || name == 'Organization Admin') {
            name = (data['organisationName'] ?? data['orgName'] ?? data['name'] ?? name).toString();
          }
          if (email.isEmpty) {
            email = (data['email'] ?? data['orgEmail'] ?? '').toString();
          }
          phone = (data['phoneNumber'] ?? data['phone'] ?? '').toString();
        }
      } catch (_) {}

      if (name.isEmpty) {
        try {
          final adminDoc = await FirestoreService.orgDataDoc.get();
          if (adminDoc.exists) {
            final data = adminDoc.data()!;
            name = (data['organisationName'] ?? data['orgName'] ?? data['name'] ?? 'Organization Admin').toString();
            if (email.isEmpty) email = (data['email'] ?? '').toString();
            if (phone.isEmpty) phone = (data['phoneNumber'] ?? data['phone'] ?? '').toString();
          }
        } catch (_) {}
      }

      // Fetch subscription status
      try {
        final subDoc = await FirestoreService.subscriptionDoc.get();
        if (subDoc.exists) {
          final data = subDoc.data();
          _subscriptionPlan = data?['planName'] ?? data?['subscriptionPlan'] ?? 'Pro Plan';
          final expiry = data?['expiresAt'] ?? data?['subscriptionEndDate'];
          if (expiry != null && expiry is Timestamp) {
            _subscriptionExpiry = DateFormat('dd MMM yyyy').format(expiry.toDate());
            _isSubscriptionActive = expiry.toDate().isAfter(DateTime.now());
          } else {
            _subscriptionExpiry = 'Active';
            _isSubscriptionActive = true;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _orgName = name.isNotEmpty ? name : 'Organization Admin';
          _orgEmail = email.isNotEmpty ? email : (currentUser?.email ?? 'admin@ebricks.app');
          _orgPhone = phone;
        });
      }
    } catch (e) {
      debugPrint('Error fetching org data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 650,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Organization Profile Hero Card ───────────────────
              _buildProfileHeaderCard(primaryColor, darkAccent),
              const SizedBox(height: 20),

              // ── 2. Account & Organization Settings ──────────────────
              _buildSectionTitle('ORGANIZATION & ACCOUNT'),
              _buildSettingsCard(
                tiles: [
                  _SettingsTileItem(
                    icon: Icons.business_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Organisation Information',
                    subtitle: 'Update company address, contact & registration details',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrgInformationScreen(),
                      ),
                    ),
                  ),
                  _SettingsTileItem(
                    icon: Icons.card_membership_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Subscription & Membership',
                    subtitle: '$_subscriptionPlan • $_subscriptionExpiry',
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isSubscriptionActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isSubscriptionActive ? 'ACTIVE' : 'RENEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isSubscriptionActive
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrganizationSubscriptionPage(),
                      ),
                    ),
                  ),
                  _SettingsTileItem(
                    icon: Icons.palette_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Brand & Theme Color',
                    subtitle: 'Customize app accent colors & visual branding',
                    onTap: () => Navigator.pushNamed(context, '/branding'),
                  ),
                  _SettingsTileItem(
                    icon: Icons.lock_reset_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Security & Password',
                    subtitle: 'Update your account security password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrgResetPasswordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. Support & About ──────────────────────────────────
              _buildSectionTitle('SUPPORT & LEGAL'),
              _buildSettingsCard(
                tiles: [
                  _SettingsTileItem(
                    icon: Icons.headset_mic_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: 'Contact Support',
                    subtitle: 'Get dedicated assistance from the technical team',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactSupportScreen(),
                      ),
                    ),
                  ),
                  _SettingsTileItem(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: const Color(0xFF64748B),
                    title: 'Privacy Policy',
                    subtitle: 'View privacy terms, data safety & security policy',
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'https://sites.google.com/view/cst-whitelabel-app/home',
                      );
                      if (!await launchUrl(url)) {
                        if (mounted && context.mounted) {
                          AppTheme.showErrorToast(context, 'Could not open privacy policy');
                        }
                      }
                    },
                  ),
                  _SettingsTileItem(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: 'About eBricks',
                    subtitle: 'Application version, features & platform details',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutUsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── 4. Logout Section ───────────────────────────────────
              _buildLogoutButton(context),
            ],
          ),
        ),
      ),
    );

    if (!widget.standalone) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true,
      bottomNavigationBar: const BottomNav(currentIndex: 4),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Menu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
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

  Widget _buildProfileHeaderCard(Color primaryColor, Color darkAccent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.2),
                  primaryColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.apartment_rounded,
                color: primaryColor,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _orgName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _orgEmail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_orgPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _orgPhone,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<_SettingsTileItem> tiles}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
          itemBuilder: (context, index) {
            final item = tiles[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),

                      // Title and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Trailing Badge or Arrow
                      if (item.trailingBadge != null)
                        item.trailingBadge!
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
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
                color: Color(0xFF64748B),
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
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFF475569),
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
                      elevation: 2,
                      shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
}

class _SettingsTileItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailingBadge;
  final VoidCallback? onTap;

  const _SettingsTileItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingBadge,
    this.onTap,
  });
}
