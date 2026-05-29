import 'package:flutter/material.dart';
import 'manager_expenses.dart';
import 'manager_site_entry_page.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';
import '../services/auth_service.dart';

class ManagerExpensesHomeScreen extends StatelessWidget {
  const ManagerExpensesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = Responsive.isMobile(context);
    final theme = Theme.of(context);
    final userData = AuthService().userData;
    final userName = userData['username'] ?? userData['org_name'] ?? 'Manager';

    return GlassScaffold(
      title: 'Manager Expenses',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          children: [
            GlassCard(
              title: 'Site Supervisor Entry',
              subtitle:
                  'Add, view, and manage site supervisor expenses and entries.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagerSiteEntryPage(
                      userName: userName,
                      userDetails: userData,
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
              subtitle:
                  'Add, view, and manage manager-level expenses and approvals.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagerExpenses(),
                  ),
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

  Widget _buildCardContent(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}
