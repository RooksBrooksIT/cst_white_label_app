import 'package:flutter/material.dart';
import '../widgets/glass_scaffold.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      title: 'About Us',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isDesktop ? 24 : 16),

                // Hero Section
                Center(
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 32 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.12),
                          colorScheme.primary.withOpacity(0.04),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_main.png',
                        width: isDesktop ? 120 : (isTablet ? 100 : 94),
                        height: isDesktop ? 120 : (isTablet ? 100 : 94),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 32 : 24),

                Center(
                  child: Text(
                    'eBicks App',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: isDesktop ? 28 : (isTablet ? 24 : null),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : 32),

                // Main Content Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isDesktop ? 32 : 24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'About the App',
                        isDesktop,
                        isTablet,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'eBicks is a smart and efficient construction and operations management application developed by Rooks and Brooks Technologies Pvt Ltd. The platform is designed to simplify and streamline the management of organizational activities, including tracking operations, monitoring progress, and managing financial records such as expenses and income.\n\nAt its core, eBicks is built to serve organizations that require structured control over their workflows. The app follows a role-based system, enabling seamless collaboration between Organization Owners, Managers, Supervisors, and Customers, ensuring transparency and accountability at every level.\n\nUnlike public applications, eBicks operates on a controlled access model where accounts are created and managed by authorized administrators. This ensures data security, operational integrity, and a customized experience for each organization.\n\nOur mission is to empower businesses with reliable, scalable, and user-friendly digital solutions that enhance productivity and decision-making. With a focus on innovation and practical usability, eBicks helps organizations stay organized, efficient, and in control of their operations.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          height: 1.6,
                          color: colorScheme.onSurface.withOpacity(0.85),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 40 : 32),
                      _buildSectionHeader(
                        context,
                        'About the Company',
                        isDesktop,
                        isTablet,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Rooks and Brooks Technologies Pvt Ltd is a technology-driven company committed to delivering high-quality software solutions tailored to modern business needs. We specialize in developing scalable applications that combine performance, security, and user-centric design.\n\nOur goal is to transform traditional processes into smart digital systems that drive efficiency and growth for our clients.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          height: 1.6,
                          color: colorScheme.onSurface.withOpacity(0.85),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 40 : 32),
                      _buildSectionHeader(
                        context,
                        'Contact Us',
                        isDesktop,
                        isTablet,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 16,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isDesktop ? 12 : 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.email_rounded,
                                color: colorScheme.primary,
                                size: isDesktop ? 24 : 20,
                              ),
                            ),
                            SizedBox(width: isDesktop ? 20 : 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EMAIL',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 12 : 10,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.7),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'support@rookstechnologies.com',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 16 : 14,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : 32),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isDesktop,
    bool isTablet,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: isDesktop ? 22 : 18,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
