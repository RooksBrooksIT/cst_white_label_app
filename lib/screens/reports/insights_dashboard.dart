import 'package:demo_cst/screens/reports/project_stage_insights_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:demo_cst/screens/manager/contractor_report_page.dart';
import 'package:demo_cst/screens/organization/organization_insights_screen.dart';
import 'package:demo_cst/screens/reports/project_financial_status_report_page.dart';
import 'package:demo_cst/screens/reports/site_status_report.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/utils/app_theme.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 16.0);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final cardAccent = AppTheme.getCardAccent(primaryColor);

        return GlassScaffold(
          title: 'Insights Dashboard',
          appBarForegroundColor: Colors.white,
          onBack: () => Navigator.pop(context),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isMobile ? 16 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics & Reports',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Access detailed reports and insights for your projects and sites',
                      style: TextStyle(
                        color: Color(0xFF5A759E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      context,
                      icon: Icons.receipt_long_outlined,
                      title: 'Site/Project Expenses Report',
                      description:
                          'View and analyze all expenses related to your site or project in detail.',
                      accentColor: cardAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrganizationInsightsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      icon: Icons.timeline_outlined,
                      title: 'Site/Project Stage Expenses',
                      description:
                          'Track expenses by project stage for better cost management.',
                      accentColor: cardAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProjectstageInsightsDashboard(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      icon: Icons.bar_chart_outlined,
                      title: 'Site/Project Status Report',
                      description:
                          'Monitor the current status and progress of your site or project.',
                      accentColor: cardAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SiteStatusReportScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Financial Status Report',
                      description:
                          'Get a detailed overview of your project\'s financial health and budget utilization.',
                      accentColor: cardAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectFinancialStatusReportPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      icon: Icons.assignment_outlined,
                      title: 'Contractor Report',
                      description:
                          'View contractor-wise entries and totals saved via Contractor Entry.',
                      accentColor: cardAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ContractorReportPage()),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1942).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'View Report',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      color: accentColor,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
