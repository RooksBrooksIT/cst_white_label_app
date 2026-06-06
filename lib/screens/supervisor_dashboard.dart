import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Supervisor_material_information.dart';
import 'material_at_site_entry_page.dart';
import 'material_request_form.dart';
import 'supervisor_material_view_request_screen.dart';
import 'supervisor_tool_movement.dart';
import 'supervisor_verification_page.dart';
import 'supervisor_view_request_screen.dart';
import 'supervisor_work_schedule_page.dart';
import 'supervisor_worker_att_page.dart';
import '../widgets/glass_scaffold.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

import 'org_sub_menu_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorDashboard({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required String username,
  });

  @override
  _SupervisorDashboardState createState() => _SupervisorDashboardState();
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<SubMenuItem> items;

  _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.items,
  });
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastBackPressTime;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[300], size: 28),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/authSelection',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : (screenWidth < 900 ? 3 : 4);

    final categories = _getCategories(colorScheme);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Press back again to exit'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: GlassScaffold(
        title: 'Supervisor Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
        padding: EdgeInsets.zero,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            ..._buildGridSections(context, theme, categories, crossAxisCount),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridSections(
    BuildContext context,
    ThemeData theme,
    List<_CategoryData> categories,
    int crossAxisCount,
  ) {
    List<Widget> slivers = [];

    for (var category in categories) {
      if (category.items.isEmpty) continue;

      // Section Header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [category.color, category.color.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${category.items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Items Grid for this section
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = category.items[index];
              return _buildGridItem(context, item);
            }, childCount: category.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildGridItem(BuildContext context, SubMenuItem item) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.cardColor,
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [item.color, item.color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_CategoryData> _getCategories(ColorScheme colorScheme) {
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;

    return [
      _CategoryData(
        title: "Expenses & Finance",
        subtitle: "Manage site expenses and verifications",
        icon: Icons.account_balance_wallet_rounded,
        color: primary,
        gradientColors: [primary, primary.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: 'Site Supervisor Expenses',
            subtitle: 'Log and track daily site expenses',
            icon: Icons.monetization_on_rounded,
            color: primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorVerificationPage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Material Requests",
        subtitle: "Request and track materials and tools",
        icon: Icons.inventory_2_rounded,
        color: primary.withBlue(150), // Use a variation of brand color
        gradientColors: [
          primary.withBlue(150),
          primary.withBlue(150).withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: 'Materials Request Form',
            subtitle: 'Submit new material requests',
            icon: Icons.add_shopping_cart_rounded,
            color: primary.withBlue(150),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialRequestForm(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Materials Approvals',
            subtitle: 'Check status of material requests',
            icon: Icons.fact_check_rounded,
            color: primary.withBlue(180),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorMaterialViewRequestScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Site Operations",
        subtitle: "Schedules, attendance and site info",
        icon: Icons.engineering_rounded,
        color: secondary,
        gradientColors: [secondary, secondary.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: 'Work Schedule Request',
            subtitle: 'Manage site work schedules',
            icon: Icons.calendar_today_rounded,
            color: secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorWorkSchedulePage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Site Approvals',
            subtitle: 'View pending site approvals',
            icon: Icons.check_circle_rounded,
            color: secondary.withOpacity(0.8).withBlue(200),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewApprovalScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Workers Attendance',
            subtitle: 'Track worker daily attendance',
            icon: Icons.people_rounded,
            color: secondary.withOpacity(0.9),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceManagementPage(),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Inventory & Tools",
        subtitle: "Manage materials and tool movements",
        icon: Icons.construction_rounded,
        color: primary.withGreen(150),
        gradientColors: [
          primary.withGreen(150),
          primary.withGreen(150).withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: 'Materials at Site',
            subtitle: 'Current material stock at site',
            icon: Icons.warehouse_rounded,
            color: primary.withGreen(150),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialAtSiteEntryPage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Materials Information',
            subtitle: 'General material specifications',
            icon: Icons.info_rounded,
            color: primary.withGreen(180),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorMaterialInfoScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Tools Movement',
            subtitle: 'Track tools return and movement',
            icon: Icons.handyman_rounded,
            color: primary.withGreen(200),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SiteToCompanyReturn(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
