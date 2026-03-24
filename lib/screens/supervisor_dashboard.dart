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
  final Color primaryColor = const Color(0xFF0b3470);

  late final Map<String, List<DashboardItem>> groupedItems;

  @override
  void initState() {
    super.initState();
    groupedItems = {
      "Expenses": [
        DashboardItem(
          'Site Supervisor Expenses',
          Icons.monetization_on_outlined,
          primaryColor,
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
          primaryColor,
          () => _navigate(
            context,
            MaterialRequestForm(
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            ),
          ),
        ),
        DashboardItem(
          'Work Schedule Request Form',
          Icons.schedule_outlined,
          primaryColor,
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
          primaryColor,
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
          Icons.warehouse_outlined,
          primaryColor,
          () => _navigate(context, SupervisorMaterialInfoScreen()),
        ),
        DashboardItem(
          'Tools Movement',
          Icons.handyman_outlined,
          primaryColor,
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
          primaryColor,
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
          Icons.check_box_sharp,
          primaryColor,
          () {
            print('Navigating with supervisor: ${widget.supervisorName}');
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
          Icons.check_box_sharp,
          primaryColor,
          () {
            print('Navigating with supervisor: ${widget.supervisorName}');
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
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // Close dialog
              Navigator.pop(context);

              // Clear SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Or remove specific keys

              // Navigate to login and clear all routes
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SupervisorLoginPage()),
                (route) => false,
              );
            },
            child: const Text("Yes", style: TextStyle()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      onBack: () => _showLogoutDialog(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          // Profile Card
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.supervisorName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Site Supervisor',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...groupedItems.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(entry.key),
                _buildItemList(entry.value),
              ],
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildItemList(List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) => _buildColorfulCard(item)).toList(),
    );
  }

  Widget _buildColorfulCard(DashboardItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: item.onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ],
          ),
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
