import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../screens/manager/manager_material_approval_screen.dart';
import '../screens/manager/manager_tools_approval_screen.dart';
import '../screens/manager/manager_site_payment_approval_page.dart';
import '../screens/manager/manager_approval_screen.dart';
import '../screens/supervisor/supervisor_petty_cash_page.dart';
import '../screens/manager/manager_petty_cash_page.dart';
import '../screens/organization/org_petty_cash_page.dart';
import '../screens/organization/organization_expenses.dart';
import '../screens/manager/manager_expenses.dart';
import '../screens/supervisor/site_entry_page.dart';
import '../screens/manager/manager_notification_screen.dart';
import '../screens/organization/org_notification_page.dart';

/// Centralized Decoupled Notification Router.
/// Resolves incoming FCM push notification payloads and in-app notification records
/// into specific deep-linked screens, complete with fallback navigation paths.
class NotificationRouter {
  /// Routes to the appropriate screen based on NotificationModel or raw data map.
  static void navigate(BuildContext context, dynamic payload) {
    if (!context.mounted) return;

    NotificationModel model;
    if (payload is NotificationModel) {
      model = payload;
    } else if (payload is Map<String, dynamic>) {
      model = NotificationModel.fromMap(payload);
    } else if (payload is Map) {
      model = NotificationModel.fromMap(Map<String, dynamic>.from(payload));
    } else {
      return;
    }

    // Automatically synchronize read status with Firestore
    if (model.notificationId.isNotEmpty) {
      NotificationService.markAsRead(model.notificationId);
    }

    try {
      switch (model.type) {
        case NotificationType.materialRequisition:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManagerMaterialApprovalScreen(),
            ),
          );
          break;
        case NotificationType.toolsRequisition:
        case NotificationType.toolMovement:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManagerToolsApprovalScreen(),
            ),
          );
          break;
        case NotificationType.paymentRequisition:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManagerSitePaymentApprovalPage(),
            ),
          );
          break;
        case NotificationType.workforceSchedule:
        case NotificationType.dailyWorkSchedule:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManagerApprovalScreen(),
            ),
          );
          break;
        case NotificationType.pettyCashRequest:
        case NotificationType.pettyCashTopup:
        case NotificationType.pettyCashDispatched:
          final role = AuthService().userRole;
          final ud = AuthService().userData;
          if (role == UserRole.supervisor) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupervisorPettyCashPage(
                  supervisorId: (ud['supervisorId'] ?? '').toString(),
                  supervisorName:
                      (ud['supervisorName'] ?? 'Supervisor').toString(),
                ),
              ),
            );
          } else if (role == UserRole.organization) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgPettyCashPage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerPettyCashPage()),
            );
          }
          break;
        case NotificationType.organizationExpense:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrganizationExpenses()),
          );
          break;
        case NotificationType.managerExpense:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagerExpenses()),
          );
          break;
        case NotificationType.siteAssignment:
        case NotificationType.siteCreated:
          final ud = AuthService().userData;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SiteEntryPage(
                userName: (ud['FullName'] ??
                        ud['fullName'] ??
                        ud['username'] ??
                        'Supervisor')
                    .toString(),
                userDetails: ud,
              ),
            ),
          );
          break;
        case NotificationType.managerAccountCreated:
        case NotificationType.supervisorAccountCreated:
        case NotificationType.scheduledReminder:
        case NotificationType.subscriptionExpiry:
        case NotificationType.general:
          _navigateToNotificationInbox(context);
          break;
      }
    } catch (e) {
      debugPrint('NotificationRouter: Deep-link routing error: $e');
      _navigateToNotificationInbox(context);
    }
  }

  /// Safe fallback to the user's role-appropriate notification center.
  static void _navigateToNotificationInbox(BuildContext context) {
    if (!context.mounted) return;
    final role = AuthService().userRole;
    if (role == UserRole.organization) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrgNotificationPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerNotificationScreen()),
      );
    }
  }
}
