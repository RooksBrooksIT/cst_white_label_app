import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/screens/supervisor/supervisor_work_schedule_page.dart';
import 'package:ebricks/screens/supervisor/supervisor_view_request_screen.dart';

/// Combined workflow page for Workforce & Site Approvals:
/// Allows supervisors to submit workforce requirements and view/manage site approval statuses in one unified screen.
class SupervisorWorkforceWorkflowPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final int initialTabIndex;

  const SupervisorWorkforceWorkflowPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    this.initialTabIndex = 0,
  });

  @override
  State<SupervisorWorkforceWorkflowPage> createState() =>
      _SupervisorWorkforceWorkflowPageState();
}

class _SupervisorWorkforceWorkflowPageState
    extends State<SupervisorWorkforceWorkflowPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToTab(int index) {
    HapticFeedback.selectionClick();
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Workforce & Site Approvals',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      darkAccent,
                      Color.alphaBlend(
                        primaryColor.withValues(alpha: 0.35),
                        darkAccent,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: darkAccent,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.88),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Site Approvals'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Request Workforce'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: View Approval Screen (Pending / History tabs for Work Schedule Approvals)
                ViewApprovalScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                  hideAppBar: true,
                  onNewRequestPressed: () => _switchToTab(1),
                ),

                // Tab 1: Submit Work Schedule & Workforce Request
                SupervisorWorkSchedulePage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                  hideAppBar: true,
                  onRequestSubmitted: () => _switchToTab(0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
