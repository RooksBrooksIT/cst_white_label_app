import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/responsive.dart';
import 'package:ebricks/screens/supervisor/supervisor_materials_workflow_page.dart';
import 'package:ebricks/screens/supervisor/supervisor_workforce_workflow_page.dart';
import 'package:ebricks/screens/supervisor/supervisor_tools_workflow_page.dart';

class SupervisorRequestsPage extends StatelessWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorRequestsPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  void _navigateToMaterials(BuildContext context, {int initialTabIndex = 0}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorMaterialsWorkflowPage(
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  void _navigateToWorkforce(BuildContext context, {int initialTabIndex = 0}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorWorkforceWorkflowPage(
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  void _navigateToTools(BuildContext context, {int initialTabIndex = 0}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorToolsWorkflowPage(
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
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
                'Requests & Approvals',
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
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.maxContentWidth,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      _buildWorkflowCard(
                        title: 'Materials',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF0284C7),
                        requestLabel: 'New Request',
                        approvalLabel: 'Track Approvals',
                        onCardTap: () =>
                            _navigateToMaterials(context, initialTabIndex: 0),
                        onNewRequest: () =>
                            _navigateToMaterials(context, initialTabIndex: 1),
                        onApprovals: () =>
                            _navigateToMaterials(context, initialTabIndex: 0),
                      ),
                      const SizedBox(height: 12),
                      _buildWorkflowCard(
                        title: 'Tools & Equipment',
                        icon: Icons.construction_rounded,
                        color: const Color(0xFFD97706),
                        requestLabel: 'New Request',
                        approvalLabel: 'Track Approvals',
                        onCardTap: () =>
                            _navigateToTools(context, initialTabIndex: 0),
                        onNewRequest: () =>
                            _navigateToTools(context, initialTabIndex: 1),
                        onApprovals: () =>
                            _navigateToTools(context, initialTabIndex: 0),
                      ),
                      const SizedBox(height: 12),
                      _buildWorkflowCard(
                        title: 'Workforce',
                        icon: Icons.engineering_rounded,
                        color: const Color(0xFF10B981),
                        requestLabel: 'Request Labor',
                        approvalLabel: 'Site Approvals',
                        onCardTap: () =>
                            _navigateToWorkforce(context, initialTabIndex: 0),
                        onNewRequest: () =>
                            _navigateToWorkforce(context, initialTabIndex: 1),
                        onApprovals: () =>
                            _navigateToWorkforce(context, initialTabIndex: 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkflowCard({
    required String title,
    required IconData icon,
    required Color color,
    required String requestLabel,
    required String approvalLabel,
    required VoidCallback onCardTap,
    required VoidCallback onNewRequest,
    required VoidCallback onApprovals,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onCardTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNewRequest,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(requestLabel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        backgroundColor: color.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: color.withValues(alpha: 0.28),
                          width: 1.1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprovals,
                      icon: const Icon(Icons.fact_check_rounded, size: 15),
                      label: Text(approvalLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
