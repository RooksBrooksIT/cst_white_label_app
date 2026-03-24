import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Branding & UI'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeMode,
            builder: (context, themeMode, _) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle between light and dark themes'),
                secondary: const Icon(Icons.dark_mode_rounded),
                value: themeMode == ThemeMode.dark,
                onChanged: (bool value) {
                  AppTheme.updateThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text('Brand Color'),
            subtitle: const Text('Customize the primary app color'),
            leading: const Icon(Icons.color_lens_rounded),
            trailing: ValueListenableBuilder<Color>(
              valueListenable: AppTheme.primaryColor,
              builder: (context, color, _) {
                return Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            onTap: () {
              // TODO: Implement color picker or link to AppThemeSettingsScreen
            },
          ),
          const Divider(),
          _buildSectionHeader('General'),
          ListTile(
            title: const Text('Edit Profile'),
            leading: const Icon(Icons.person_rounded),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Notifications'),
            leading: const Icon(Icons.notifications_rounded),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Help & Support'),
            leading: const Icon(Icons.help_rounded),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
