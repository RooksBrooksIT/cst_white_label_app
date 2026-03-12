import 'package:flutter/material.dart';
import 'package:demo_cst/screens/contractor_report_page.dart';
import 'package:demo_cst/screens/organization_insights_screen.dart';
import 'package:demo_cst/screens/projectStage_insights_dashboard.dart';
import 'package:demo_cst/screens/project_financial_status_report_page.dart';
import 'package:demo_cst/screens/site_status_report.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Insights Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0b3470),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFf8f9fa),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Analytics & Reports',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2c3e50),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'Access detailed reports and insights for your projects and sites',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7f8c8d),
                ),
              ),
            ),
            _buildSectionCard(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'Site/Project Expenses Report',
              description:
                  'View and analyze all expenses related to your site or project in detail.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrganizationInsightsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              icon: Icons.timeline_rounded,
              title: 'Site/Project Stage Expenses Report',
              description:
                  'Track expenses by project stage for better cost management.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectstageInsightsDashboard(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Site/Project Status Report',
              description:
                  'Monitor the current status and progress of your site or project.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SiteStatusReportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Project Financial Status Report',
              description:
                  'Get a detailed overview of your project\'s financial health and budget utilization.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectFinancialStatusReportPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              icon: Icons.assignment_turned_in_rounded,
              title: 'Contractor Report',
              description:
                  'View contractor-wise entries and totals saved via Contractor Entry.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContractorReportPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0b3470).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0b3470).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF0b3470),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select any report to view detailed analytics and insights',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF2c3e50).withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    const primaryColor = Color(0xFF0b3470);
    const accentColor = Color(0xFF4a7cda);
    const cardColor = Colors.white;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2c3e50),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'View Report',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
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