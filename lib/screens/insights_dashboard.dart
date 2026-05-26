import 'package:flutter/material.dart';
import 'contractor_report_page.dart';
import 'organization_insights_screen.dart';
import 'projectStage_insights_dashboard.dart';
import 'project_financial_status_report_page.dart';
import 'site_status_report.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Insights Dashboard',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics & Reports',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access detailed reports and insights for your projects and sites',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'Site/Project Expenses Report',
              description:
                  'View and analyze all expenses related to your site or project in detail.',
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ContractorReportPage()),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.primaryColor, size: 28),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'View Report',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      color: theme.primaryColor,
                      size: 14,
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
