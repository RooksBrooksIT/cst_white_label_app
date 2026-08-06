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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);

    return GlassScaffold(
      title: 'Contact Support',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                SizedBox(height: isMobile ? 24 : 32),
                // Hero Section
                _buildHero(theme, colorScheme, isMobile, isTablet, isDesktop),

                SizedBox(height: isMobile ? 32 : 48),

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
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),

                SizedBox(height: isMobile ? 12 : 16),

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
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),

                SizedBox(height: isMobile ? 32 : 40),

                // Working Hours Section
                _buildWorkingHours(theme, colorScheme, isMobile, isTablet, isDesktop),

                SizedBox(height: isMobile ? 40 : 60),

                // Footer Info
                Text(
                  'Thank you for being with us!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: isMobile ? 24 : 32),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme, ColorScheme colorScheme, bool isMobile, bool isTablet, bool isDesktop) {
    final heroSize = isMobile ? 100.0 : 120.0;
    final iconSize = isMobile ? 48.0 : 56.0;

    return Column(
      children: [
        Container(
          height: heroSize,
          width: heroSize,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: isMobile ? 30 : 40,
                spreadRadius: isMobile ? 3 : 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: isMobile ? 70 : 90,
                width: isMobile ? 70 : 90,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                Icons.support_agent_rounded,
                color: colorScheme.primary,
                size: iconSize,
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 24 : 32),
        Text(
          'How can we help you?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
            fontSize: isMobile ? 22 : null,
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
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
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final cardPadding = isMobile ? 16.0 : 20.0;
    final iconPadding = isMobile ? 10.0 : 12.0;

    return GlassCard(
      padding: EdgeInsets.all(cardPadding),
      margin: EdgeInsets.zero,
      borderRadius: isMobile ? 20 : 24,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                ),
                child: Icon(icon, color: iconColor, size: isMobile ? 22 : 24),
              ),
              SizedBox(width: isMobile ? 12 : 16),
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
                    SizedBox(height: isMobile ? 2 : 2),
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
          SizedBox(height: isMobile ? 16 : 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
              border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontSize: isMobile ? 13 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHours(ThemeData theme, ColorScheme colorScheme, bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
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
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 10 : 12),
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
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Monday – Saturday',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
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
