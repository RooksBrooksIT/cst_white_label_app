import 'package:flutter/material.dart';
import '../services/project_alert_service.dart';

/// Compact visual badge / chip widget for project cards in list views
class ProjectAlertBadge extends StatelessWidget {
  final Map<String, dynamic>? projectData;
  final List<ProjectAlert>? alerts;
  final String? docId;
  final bool compact;

  const ProjectAlertBadge({
    super.key,
    this.projectData,
    this.alerts,
    this.docId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeAlerts = alerts ??
        (projectData != null
            ? ProjectAlertService.getAlertsForProject(projectData!, docId: docId)
            : <ProjectAlert>[]);

    if (activeAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Trigger notification check asynchronously without blocking build
    if (projectData != null) {
      Future.microtask(() {
        ProjectAlertService.checkAndTriggerProjectNotifications(
          projectData!,
          docId: docId,
        );
      });
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: activeAlerts.map((alert) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: alert.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: alert.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                alert.icon,
                size: compact ? 12 : 14,
                color: alert.textColor,
              ),
              const SizedBox(width: 4),
              Text(
                alert.indicatorLabel,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: alert.textColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Detailed alert banner widget for project details and financial pages
class ProjectAlertBanner extends StatelessWidget {
  final Map<String, dynamic> projectData;
  final String? docId;

  const ProjectAlertBanner({
    super.key,
    required this.projectData,
    this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final activeAlerts = ProjectAlertService.getAlertsForProject(
      projectData,
      docId: docId,
    );

    if (activeAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Background trigger for notifications
    Future.microtask(() {
      ProjectAlertService.checkAndTriggerProjectNotifications(
        projectData,
        docId: docId,
      );
    });

    return Column(
      children: activeAlerts.map((alert) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: alert.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: alert.primaryColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: alert.primaryColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alert.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  alert.icon,
                  color: alert.textColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: alert.textColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: alert.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            alert.severity.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: alert.textColor.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
