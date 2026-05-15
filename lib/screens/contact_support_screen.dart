import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const String _email = 'support@rookstechnologies.com';
  static const String _phone = '+918925633099';
  static const String _phoneDisplay = '+91 89256 33099';

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'Support Request'},
    );
    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('Could not launch email');
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: _phone);
    if (!await launchUrl(phoneLaunchUri)) {
      debugPrint('Could not launch phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      title: 'Contact Support',
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Hero Section
            _buildHero(theme, colorScheme),

            const SizedBox(height: 48),

            // Email Card
            _buildContactCard(
              context,
              theme: theme,
              colorScheme: colorScheme,
              icon: Icons.alternate_email_rounded,
              title: 'Email Us',
              subtitle: 'Our support team will respond shortly',
              value: _email,
              iconBgColor: Colors.blue.withOpacity(0.1),
              iconColor: Colors.blue,
              onTap: _launchEmail,
            ),

            const SizedBox(height: 16),

            // Phone Card
            _buildContactCard(
              context,
              theme: theme,
              colorScheme: colorScheme,
              icon: Icons.phone_iphone_rounded,
              title: 'Call Us',
              subtitle: 'Available for urgent inquiries',
              value: _phoneDisplay,
              iconBgColor: Colors.green.withOpacity(0.1),
              iconColor: Colors.green,
              onTap: _launchPhone,
            ),

            const SizedBox(height: 40),

            // Working Hours Section
            _buildWorkingHours(theme, colorScheme),

            const SizedBox(height: 60),

            // Footer Info
            Text(
              'Thank you for being with us!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                Icons.support_agent_rounded,
                color: colorScheme.primary,
                size: 56,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'How can we help you?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Get in touch with Rooks And Brooks Technologies. We are dedicated to providing you the best support.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.zero,
      borderRadius: 24,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHours(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'WORKING HOURS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Monday – Saturday',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '9:00 AM – 6:00 PM IST',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
