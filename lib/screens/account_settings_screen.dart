import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Settings',
      onBack: () => Navigator.pop(context),
      body: ListView(
        padding: EdgeInsets.all(Responsive.isMobile(context) ? 20.0 : 32.0),
        children: [
          _buildSectionHeader('Branding & UI'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Brand Color',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Customize app colors',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: Responsive.fontSize(context, 12),
                    ),
                  ),
                  leading: const Icon(Icons.color_lens_rounded,
                      color: Color(0xFF64748B)),
                  trailing: ValueListenableBuilder<Color>(
                    valueListenable: AppTheme.primaryColor,
                    builder: (context, color, _) {
                      return Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
          const SizedBox(height: 24),
          _buildSectionHeader('General'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingsTile(
                  title: 'Edit Profile',
                  icon: Icons.person_rounded,
                  onTap: () {},
                ),
                _buildSettingsTile(
                  title: 'Notifications',
                  icon: Icons.notifications_rounded,
                  onTap: () {},
                ),
                _buildSettingsTile(
                  title: 'Help & Support',
                  icon: Icons.help_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: Icon(icon, color: const Color(0xFF64748B)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 12),
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
