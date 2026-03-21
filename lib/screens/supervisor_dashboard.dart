import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:demo_cst/screens/Supervisor_material_information.dart';
import 'package:demo_cst/screens/material_at_site_entry_page.dart';
import 'package:demo_cst/screens/material_request_form.dart';
import 'package:demo_cst/screens/supervisor_login_page.dart';
import 'package:demo_cst/screens/supervisor_material_view_request_screen.dart';
import 'package:demo_cst/screens/supervisor_tool_movement.dart';
import 'package:demo_cst/screens/supervisor_verification_page.dart';
import 'package:demo_cst/screens/supervisor_view_request_screen.dart';
import 'package:demo_cst/screens/supervisor_work_schedule_page.dart';
import 'package:demo_cst/screens/supervisor_worker_att_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          () => _navigate(context, supervisorMaterialInfoScreen()),
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
                MaterialPageRoute(builder: (context) => Supervisor_LoginPage()),
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
    return WillPopScope(
      onWillPop: () async {
        _showLogoutDialog(context);
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withOpacity(0.85),
                primaryColor.withOpacity(0.55),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                "Supervisor Dashboard",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  
                ),
              ),
              backgroundColor: primaryColor,
              centerTitle: true,
              elevation: 6,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  
                ),
                onPressed: () => _showLogoutDialog(context),
                tooltip: "Back / Logout",
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, ),
                  tooltip: "Logout",
                  onPressed: () => _showLogoutDialog(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: primaryColor,
                          child: const Icon(
                            Icons.person,
                            
                            size: 54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.supervisorName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildItemList(List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: AnimationConfiguration.toStaggeredList(
        duration: const Duration(milliseconds: 400),
        childAnimationBuilder: (widget) => SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(child: widget),
        ),
        children: items.map((item) => _buildColorfulCard(item)).toList(),
      ),
    );
  }

  Widget _buildColorfulCard(DashboardItem item) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        splashColor: primaryColor.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: primaryColor),
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
