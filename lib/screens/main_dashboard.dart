import 'package:flutter/material.dart';
import 'package:demo_cst/screens/Organisation_LoginPage.dart';
import 'package:demo_cst/screens/config_login.dart';
import 'package:demo_cst/screens/customer_login_page.dart';
import 'package:demo_cst/screens/supervisor_login_page.dart';
import 'package:demo_cst/utils/responsive.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/letsStart');
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.scaleH(context, Responsive.isTablet(context) ? 0.08 : 0.06),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: Responsive.scaleV(context, 0.03)),

                          // Top bar
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(context, '/letsStart'),
                                child: Container(
                                  width: Responsive.scaleH(context, 0.11),
                                  height: Responsive.scaleH(context, 0.11),
                                  constraints: const BoxConstraints(
                                    maxWidth: 48,
                                    maxHeight: 48,
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 22,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.construction_rounded,
                                  color: primary,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: Responsive.scaleV(context, 0.04)),
                          // Heading
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnim.value,
                                child: Transform.translate(
                                  offset: Offset(0, _slideAnim.value),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Your Role',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 28),
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: Responsive.scaleV(context, 0.01)),
                                      Text(
                                        'Choose how you\'d like to sign in',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(context, 15),
                                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: Responsive.scaleV(context, 0.04)),

                          // Role cards
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnim.value,
                                child: Column(
                                  children: [
                                    _buildRoleCard(
                                      context: context,
                                      title: 'Organization',
                                      subtitle: 'Manage org details & data',
                                      icon: Icons.account_balance_rounded,
                                      accentColor: primary,
                                      destination: const Organisation_LoginPage(),
                                    ),
                                    SizedBox(height: Responsive.scaleV(context, 0.02)),
                                    _buildRoleCard(
                                      context: context,
                                      title: 'Manager',
                                      subtitle: 'Configure settings & control',
                                      icon: Icons.manage_accounts_rounded,
                                      accentColor: const Color(0xFF5C6BC0),
                                      destination: const ConfigLoginPage(),
                                    ),
                                    SizedBox(height: Responsive.scaleV(context, 0.02)),
                                    _buildRoleCard(
                                      context: context,
                                      title: 'Supervisor',
                                      subtitle: 'Manage site activities',
                                      icon: Icons.supervisor_account_rounded,
                                      accentColor: const Color(0xFF00897B),
                                      destination: const Supervisor_LoginPage(),
                                    ),
                                    SizedBox(height: Responsive.scaleV(context, 0.02)),
                                    _buildRoleCard(
                                      context: context,
                                      title: 'Customer',
                                      subtitle: 'View your project status',
                                      icon: Icons.person_rounded,
                                      accentColor: const Color(0xFFF59E0B),
                                      destination: const CustomerLoginPage(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          const Spacer(),
                          SizedBox(height: Responsive.scaleV(context, 0.03)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.scaleH(context, 0.04),
          vertical: Responsive.scaleV(context, 0.02),
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: Responsive.scaleH(context, 0.12),
              height: Responsive.scaleH(context, 0.12),
              constraints: const BoxConstraints(
                maxWidth: 52,
                maxHeight: 52,
                minWidth: 44,
                minHeight: 44,
              ),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: Responsive.fontSize(context, 24),
              ),
            ),
            SizedBox(width: Responsive.scaleH(context, 0.04)),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 13),
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
