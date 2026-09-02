import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/organization/org_sites_list_page.dart';
import 'package:demo_cst/screens/organization/org_finance_page.dart';
import 'package:demo_cst/screens/reports/insights_dashboard.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  static Route<T> _createSmoothPageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
        final scale = Tween<double>(begin: 0.975, end: 1.0).animate(curvedAnimation);

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    HapticFeedback.lightImpact();

    if (onTap != null) {
      onTap!(index);
      return;
    }

    if (index == currentIndex) {
      return;
    }

    Widget? destinationPage;
    switch (index) {
      case 0:
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      case 1:
        destinationPage = const OrgSitesListPage();
        break;
      case 2:
        destinationPage = const OrgFinancePage();
        break;
      case 3:
        destinationPage = InsightsDashboard();
        break;
      case 4:
        destinationPage = const OrgMenuScreen(standalone: true);
        break;
    }

    if (destinationPage != null) {
      if (currentIndex == 0) {
        Navigator.push(
          context,
          _createSmoothPageRoute(destinationPage),
        );
      } else {
        Navigator.pushReplacement(
          context,
          _createSmoothPageRoute(destinationPage),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    darkAccent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.38),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    label: 'Home',
                    primaryColor: primaryColor,
                    isSelected: currentIndex == 0,
                    onTap: () => _handleNavigation(context, 0),
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.domain_rounded,
                    label: 'Sites',
                    primaryColor: primaryColor,
                    isSelected: currentIndex == 1,
                    onTap: () => _handleNavigation(context, 1),
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Finance',
                    primaryColor: primaryColor,
                    isSelected: currentIndex == 2,
                    onTap: () => _handleNavigation(context, 2),
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.insights_rounded,
                    label: 'Reports',
                    primaryColor: primaryColor,
                    isSelected: currentIndex == 3,
                    onTap: () => _handleNavigation(context, 3),
                  ),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.menu_rounded,
                    label: 'More',
                    primaryColor: primaryColor,
                    isSelected: currentIndex == 4,
                    onTap: () => _handleNavigation(context, 4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color primaryColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? primaryColor
                  : Colors.white.withValues(alpha: 0.85),
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.9),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
