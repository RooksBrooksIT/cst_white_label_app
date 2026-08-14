import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

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
                    'About Us',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Section
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: darkCardBg.withValues(alpha: 0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo_main.png',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'eBricks App',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: darkCardBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Version 1.0.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 1. About the App Card
                        Container(
                          padding: const EdgeInsets.all(22),
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
                              _buildCardHeader(title: 'ABOUT THE APP', icon: Icons.info_outline_rounded),
                              const SizedBox(height: 14),
                              const Text(
                                'eBricks is a smart and efficient construction and operations management application developed by Rooks and Brooks Technologies Pvt Ltd. The platform is designed to simplify and streamline the management of organizational activities, including tracking operations, monitoring progress, and managing financial records such as expenses and income.\n\nAt its core, eBicks is built to serve organizations that require structured control over their workflows. The app follows a role-based system, enabling seamless collaboration between Organization Owners, Managers, Supervisors, and Customers, ensuring transparency and accountability at every level.\n\nUnlike public applications, eBicks operates on a controlled access model where accounts are created and managed by authorized administrators. This ensures data security, operational integrity, and a customized experience for each organization.\n\nOur mission is to empower businesses with reliable, scalable, and user-friendly digital solutions that enhance productivity and decision-making.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 2. About the Company Card
                        Container(
                          padding: const EdgeInsets.all(22),
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
                              _buildCardHeader(title: 'ABOUT THE COMPANY', icon: Icons.business_rounded),
                              const SizedBox(height: 14),
                              const Text(
                                'Rooks and Brooks Technologies Pvt Ltd is a technology-driven company committed to delivering high-quality software solutions tailored to modern business needs. We specialize in developing scalable applications that combine performance, security, and user-centric design.\n\nOur goal is to transform traditional processes into smart digital systems that drive efficiency and growth for our clients.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1E88E5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.email_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'OFFICIAL SUPPORT EMAIL',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF64748B),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'support@rookstechnologies.com',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A183D),
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

                        // Bottom Spacer so content is never cut off
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
