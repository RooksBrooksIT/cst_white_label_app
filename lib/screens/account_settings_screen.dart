import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';
import '../utils/terms_helper.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      title: 'Settings',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
          vertical: isDesktop ? 24 : 16,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  _buildSectionHeader('Branding & UI', isDesktop, isTablet),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            'Brand Color',
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Customize app colors',
                            style: TextStyle(
                              color: const Color(0xFF64748B),
                              fontSize: isDesktop ? 14 : 12,
                            ),
                          ),
                          leading: Icon(
                            Icons.color_lens_rounded,
                            color: const Color(0xFF64748B),
                            size: isDesktop ? 28 : 24,
                          ),
                          trailing: ValueListenableBuilder<Color>(
                            valueListenable: AppTheme.primaryColor,
                            builder: (context, color, _) {
                              return Container(
                                width: isDesktop ? 32 : 24,
                                height: isDesktop ? 32 : 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            // This will be linked to BrandingEditScreen if applicable
                            Navigator.pushNamed(context, '/branding');
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isDesktop ? 32 : 24),
                  _buildSectionHeader('General', isDesktop, isTablet),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          title: 'Edit Profile',
                          icon: Icons.person_rounded,
                          onTap: () {},
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                        _buildSettingsTile(
                          title: 'Notifications',
                          icon: Icons.notifications_rounded,
                          onTap: () {},
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                        _buildSettingsTile(
                          title: 'Help & Support',
                          icon: Icons.help_rounded,
                          onTap: () {},
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                        _buildSettingsTile(
                          title: 'Terms & Conditions',
                          icon: Icons.gavel_rounded,
                          onTap: () {
                            TermsHelper.showTermsDialog(
                              context,
                              onAccepted: () {},
                              readOnly: true,
                            );
                          },
                          isDesktop: isDesktop,
                          isTablet: isTablet,
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
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDesktop,
    required bool isTablet,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: isDesktop ? 18 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: Icon(
        icon,
        color: const Color(0xFF64748B),
        size: isDesktop ? 28 : 24,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: const Color(0xFFCBD5E1),
        size: isDesktop ? 32 : 24,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title, bool isDesktop, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: isDesktop ? 16 : 12,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: isDesktop ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
