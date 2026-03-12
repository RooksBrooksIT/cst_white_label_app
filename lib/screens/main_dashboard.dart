import 'package:flutter/material.dart';
import 'package:demo_cst/screens/Organisation_LoginPage.dart';
import 'package:demo_cst/screens/config_login.dart';
import 'package:demo_cst/screens/customer_login_page.dart';
import 'package:demo_cst/screens/supervisor_login_page.dart';

class AppColors {
  static const primaryColor = Color(0xFF003768);
  static const primaryGradientStart = Color(0xFF003768);
  static const primaryGradientEnd = Color.fromARGB(
    255,
    1,
    127,
    223,
  ); // Slightly lighter for gradient
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/letsStart');
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryGradientStart,
                AppColors.primaryGradientEnd,
              ],
              stops: [0.0, 0.9],
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (!_controller.isAnimating && !_controller.isCompleted) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth > 600
                                ? screenWidth * 0.1
                                : 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(theme),
                              SizedBox(height: screenWidth > 600 ? 30 : 20),
                              Expanded(
                                child: ListView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 20),
                                  children: [
                                    _buildDashboardCard(
                                      context: context,
                                      theme: theme,
                                      title: 'Organization',
                                      subtitle:
                                          'Manage organizations and their details',
                                      icon: Icons.account_balance_rounded,
                                      colors: [
                                        AppColors.primaryColor,
                                        AppColors.primaryGradientEnd,
                                      ],
                                      destination:
                                          const Organisation_LoginPage(),
                                    ),
                                    SizedBox(
                                      height: screenWidth > 600 ? 30 : 20,
                                    ),
                                    _buildDashboardCard(
                                      context: context,
                                      theme: theme,
                                      title: 'Manager',
                                      subtitle:
                                          'Configure system settings and preferences',
                                      icon: Icons.settings_rounded,
                                      colors: [
                                        AppColors.primaryColor,
                                        AppColors.primaryGradientEnd,
                                      ],
                                      destination: const ConfigLoginPage(),
                                    ),
                                    SizedBox(
                                      height: screenWidth > 600 ? 30 : 20,
                                    ),
                                    _buildDashboardCard(
                                      context: context,
                                      theme: theme,
                                      title: 'Supervisor',
                                      subtitle:
                                          'Manage supervisors and their activities',
                                      icon: Icons.supervisor_account_rounded,
                                      colors: [
                                        AppColors.primaryColor,
                                        AppColors.primaryGradientEnd,
                                      ],
                                      destination: const Supervisor_LoginPage(),
                                    ),
                                    SizedBox(
                                      height: screenWidth > 600 ? 30 : 20,
                                    ),
                                    _buildDashboardCard(
                                      context: context,
                                      theme: theme,
                                      title: 'Customers',
                                      subtitle: 'See your beautiful creation',
                                      icon: Icons.dashboard_customize,
                                      colors: [
                                        const Color.fromARGB(255, 19, 126, 219),
                                        const Color.fromARGB(255, 3, 48, 83),
                                      ],
                                      destination: const CustomerLoginPage(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'CST Dashboard',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 24,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/letsStart');
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Welcome to CST',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your role to continue',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget destination,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = screenWidth > 600 ? 180.0 : 140.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 16,
                top: 16,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    icon,
                    size: cardHeight * 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 28, color: Colors.white),
                    ),
                    SizedBox(width: screenWidth > 600 ? 24 : 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 20,
                      color: Colors.white,
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
