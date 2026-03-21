import 'package:flutter/material.dart';
import 'package:demo_cst/screens/Customer_insights_screen.dart';
import 'package:demo_cst/screens/Customer_project_financial_statusreport.dart';
import 'package:demo_cst/screens/Customer_site_status_report.dart';
import 'package:demo_cst/screens/contractor_report_page.dart';
import 'package:demo_cst/screens/organization_insights_screen.dart';
import 'package:demo_cst/screens/projectStage_insights_dashboard.dart';
import 'package:demo_cst/screens/project_financial_status_report_page.dart';
import 'package:demo_cst/screens/site_status_report.dart';
import 'package:demo_cst/screens/site_status_reportPage.dart';

class CustomerWorkProgress extends StatelessWidget {
  const CustomerWorkProgress({
    super.key,
    required String ownername,
    required String ownerphonenumber,
    required String siteId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Insights Dashboard',
          style: TextStyle( fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFF003768),
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
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
            child: _buildSectionCard(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'Site/Project Expenses Report',
              description:
                  'View and analyze all expenses related to your site or project in detail.',
              color: Color(0xFF003768),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Customerprojectinsightscreen(),
                ),
              );
            },
            child: _buildSectionCard(
              context,
              icon: Icons.timeline_rounded,
              title: 'Site/Project Stage Expenses Report',
              description:
                  'Track expenses by project stage for better cost management.',
              color: Color(0xFF003768),
            ),
          ),
          // const SizedBox(height: 16),
          // InkWell(
          //   borderRadius: BorderRadius.circular(16),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const SiteStatusReportScreen()),
          //     );
          //   },
          //   child: _buildSectionCard(
          //     context,
          //     icon: Icons.bar_chart_rounded,
          //     title: 'Site/Project Status Report',
          //     description:
          //         'Monitor the current status and progress of your site or project.',
          //     color: Color(0xFF772323),
          //   ),
          // ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      customerProjectFinancialStatusReportPage(),
                ),
              );
            },
            child: _buildSectionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Project Financial Status Report',
              description:
                  'Get a detailed overview of your project’s financial health and budget utilization.',
              color: Color(0xFF003768),
            ),
          ),
          // const SizedBox(height: 16),
          // InkWell(
          //   borderRadius: BorderRadius.circular(16),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => ContractorReportPage(),
          //       ),
          //     );
          //   },
          //   child: _buildSectionCard(
          //     context,
          //     icon: Icons.assignment_turned_in_rounded,
          //     title: 'Contractor Report',
          //     description:
          //         'View contractor-wise entries and totals saved via Contractor Entry.',
          //     color: Color(0xFF772323),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
