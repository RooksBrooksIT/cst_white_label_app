import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/responsive.dart';
import 'package:ebricks/screens/supervisor/supervisor_worker_att_page.dart';
import 'package:ebricks/screens/reports/workers_availability_report_page.dart';
import 'package:ebricks/screens/reports/worker_summary_report_page.dart';

class SupervisorWorkersPage extends StatelessWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorWorkersPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        final items = [
          _WorkforceModuleItem(
            title: 'Daily Attendance',
            icon: Icons.how_to_reg_rounded,
            accentColor: const Color(0xFF10B981),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceManagementPage(
                    supervisorId: supervisorId,
                    supervisorName: supervisorName,
                  ),
                ),
              );
            },
          ),
          _WorkforceModuleItem(
            title: 'Workforce Availability',
            icon: Icons.event_available_rounded,
            accentColor: const Color(0xFFF59E0B),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkersAvailabilityReportPage(),
                ),
              );
            },
          ),
          _WorkforceModuleItem(
            title: 'Summary & Wages',
            icon: Icons.payments_rounded,
            accentColor: const Color(0xFF3B82F6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkerAttendanceSalaryPage(),
                ),
              );
            },
          ),
        ];

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Workforce',
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
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildModuleCard(context, items[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleCard(BuildContext context, _WorkforceModuleItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    color: item.accentColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkforceModuleItem {
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _WorkforceModuleItem({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });
}
