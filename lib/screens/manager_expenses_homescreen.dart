import 'package:flutter/material.dart';
import 'manager_expenses.dart';
import 'manager_site_entry_page.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class ManagerExpensesHomeScreen extends StatelessWidget {
  const ManagerExpensesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Manager Expenses',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          children: [
            GlassCard(
              title: 'Site Supervisor Entry',
              subtitle: 'Add, view, and manage site supervisor expenses and entries.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagerSiteEntryPage(
                      userName: '',
                      userDetails: {},
                    ),
                  ),
                );
              },
              child: _buildCardContent(
                context,
                icon: Icons.supervisor_account,
                label: 'Go to Supervisor Entry',
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              title: 'Manager Entry',
              subtitle: 'Add, view, and manage manager-level expenses and approvals.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerExpenses()),
                );
              },
              child: _buildCardContent(
                context,
                icon: Icons.account_balance_wallet,
                label: 'Go to Manager Entry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, {required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.white70),
      ],
    );
  }
}