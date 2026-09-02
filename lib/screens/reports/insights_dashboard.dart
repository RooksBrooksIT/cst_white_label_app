import 'package:demo_cst/screens/reports/project_stage_insights_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:demo_cst/screens/manager/contractor_report_page.dart';
import 'package:demo_cst/screens/organization/organization_insights_screen.dart';
import 'package:demo_cst/screens/reports/project_financial_status_report_page.dart';
import 'package:demo_cst/screens/reports/site_status_report.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBody: true,
      bottomNavigationBar: const BottomNav(currentIndex: 3),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Insights Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800.0 : (isTablet ? 650.0 : double.infinity),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isMobile ? 16 : 24,
                horizontalPadding,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analytics & Reports',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Access detailed reports and insights for your projects and sites',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Site/Project Expenses Report',
                    description:
                        'View and analyze all expenses related to your site or project in detail.',
                    primaryColor: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizationInsightsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: Icons.timeline_rounded,
                    title: 'Site/Project Stage Expenses',
                    description:
                        'Track expenses by project stage for better cost management.',
                    primaryColor: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProjectstageInsightsDashboard(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: Icons.bar_chart_rounded,
                    title: 'Site/Project Status Report',
                    description:
                        'Monitor the current status and progress of your site or project.',
                    primaryColor: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SiteStatusReportScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Financial Status Report',
                    description:
                        'Get a detailed overview of your project\'s financial health and budget utilization.',
                    primaryColor: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectFinancialStatusReportPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: Icons.assignment_rounded,
                    title: 'Contractor Report',
                    description:
                        'View contractor-wise entries and totals saved via Contractor Entry.',
                    primaryColor: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ContractorReportPage()),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'View Report',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryColor,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
