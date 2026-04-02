import 'package:flutter/material.dart';
import 'Supervisor_material_information.dart';
import 'material_at_site_entry_page.dart';
import 'material_request_form.dart';
import 'supervisor_login_page.dart';
import 'supervisor_material_view_request_screen.dart';
import 'supervisor_tool_movement.dart';
import 'supervisor_verification_page.dart';
import 'supervisor_view_request_screen.dart';
import 'supervisor_work_schedule_page.dart';
import 'supervisor_worker_att_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

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

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  late Map<String, List<DashboardItem>> groupedItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colorScheme = Theme.of(context).colorScheme;
    groupedItems = {
      "Expenses": [
        DashboardItem(
          'Site Supervisor Expenses',
          Icons.monetization_on_outlined,
          colorScheme.primary,
          () => _navigate(
            context,
            SupervisorVerificationPage(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
      ],
      "Requests": [
        DashboardItem(
          'Materials Request Form',
          Icons.inventory_2_outlined,
          colorScheme.secondary,
          () => _navigate(
            context,
            MaterialRequestForm(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
        DashboardItem(
          'Work Schedule Request',
          Icons.schedule_outlined,
          colorScheme.tertiary,
          () => _navigate(
            context,
            SupervisorWorkSchedulePage(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
      ],
      "Site Info": [
        DashboardItem(
          'Materials',
          Icons.warehouse_outlined,
          colorScheme.primary,
          () => _navigate(
            context,
            MaterialAtSiteEntryPage(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
        DashboardItem(
          'Materials information',
          Icons.info_outline,
          colorScheme.primary,
          () => _navigate(context, SupervisorMaterialInfoScreen()),
        ),
        DashboardItem(
          'Tools Movement',
          Icons.handyman_outlined,
          colorScheme.secondary,
          () => _navigate(
            context,
            SiteToCompanyReturn(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
      ],
      "Others": [
        DashboardItem(
          'Site Approvals',
          Icons.check_circle_outline,
          colorScheme.primary,
          () => _navigate(
            context,
            ViewApprovalScreen(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
        DashboardItem(
          'Materials Approvals',
          Icons.fact_check_outlined,
          colorScheme.secondary,
          () {
            _navigate(
              context,
              SupervisorMaterialViewRequestScreen(
                supervisorId: widget.supervisorId,
                supervisorName: widget.supervisorName,
              ),
            );
          },
        ),
        DashboardItem(
          'Workers Attendance',
          Icons.people_alt_rounded,
          colorScheme.tertiary,
          () {
            _navigate(context, AttendanceManagementPage());
          },
        ),
      ],
    };
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          "Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No", style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SupervisorLoginPage()),
                (route) => false,
              );
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Supervisor Dashboard',
      onBack: () => _showLogoutDialog(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.isMobile(context) ? 16 : 32,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            const SizedBox(height: 32),
            ...groupedItems.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(entry.key),
                  ...entry.value.map((item) => _buildMenuCard(item)),
                ],
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supervisorName,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Site Supervisor • ID: ${widget.supervisorId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(DashboardItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: item.onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.outlineVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DashboardItem(this.title, this.icon, this.color, this.onTap);
}
