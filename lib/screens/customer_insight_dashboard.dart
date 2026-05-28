import 'package:flutter/material.dart';
import 'customer_insights_screen.dart';
import 'customer_project_financial_statusreport.dart';
import 'customer_site_status_report.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class CustomerWorkProgress extends StatelessWidget {
  const CustomerWorkProgress({
    super.key,
    required String ownername,
    required String ownerphonenumber,
    required String siteId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Insights Dashboard',
      appBarBackgroundColor: Theme.of(context).colorScheme.primary,
      appBarForegroundColor: Theme.of(context).colorScheme.onPrimary,
      onBack: () => Navigator.pop(context),
      body: ListView(
        padding: EdgeInsets.all(Responsive.isMobile(context) ? 20.0 : 32.0),
        children: [
          _buildInsightItem(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Site/Project Expenses Report',
            description: 'View and analyze all expenses related to your site or project in detail.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerInsightsScreen(
                    loggedInUserName: '',
                    ownerphonenumber: '',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            context,
            icon: Icons.timeline_rounded,
            title: 'Site/Project Stage Expenses Report',
            description: 'Track expenses by project stage for better cost management.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Customerprojectinsightscreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: 'Project Financial Status Report',
            description: 'Get a detailed overview of your project’s financial health and budget utilization.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => customerProjectFinancialStatusReportPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

}
