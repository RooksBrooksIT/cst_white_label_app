import 'package:flutter/material.dart';
import 'Organisation_LoginPage.dart';
import 'config_login.dart';
import 'customer_login_page.dart';
import 'supervisor_login_page.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return GlassScaffold(
      onBack: () => Navigator.of(context).pop(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Your Role',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you\'d like to sign in',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 48),

              // Role Cards wrapped in a single column or glass group if helpful
              _buildRoleCard(
                context: context,
                title: 'Organization',
                subtitle: 'Manage org details & data',
                icon: Icons.account_balance_rounded,
                accentColor: primary,
                destination: const Organisation_LoginPage(),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Manager',
                subtitle: 'Configure settings & control',
                icon: Icons.manage_accounts_rounded,
                accentColor: const Color(0xFF5C6BC0),
                destination: const ConfigLoginPage(),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Supervisor',
                subtitle: 'Manage site activities',
                icon: Icons.supervisor_account_rounded,
                accentColor: const Color(0xFF00897B),
                destination: const SupervisorLoginPage(),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Customer',
                subtitle: 'View your project status',
                icon: Icons.person_rounded,
                accentColor: const Color(0xFFF59E0B),
                destination: const CustomerLoginPage(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget destination,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 20),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
