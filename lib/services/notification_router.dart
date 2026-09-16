import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../screens/manager/manager_material_approval_screen.dart';
import '../screens/manager/material_screen.dart';
import '../screens/supervisor/tools_movement_page.dart';
import '../screens/manager/manager_site_payment_approval_page.dart';
import '../screens/manager/manager_approval_screen.dart';
import '../screens/manager/workers_config_page.dart';
import '../screens/supervisor/supervisor_petty_cash_page.dart';
import '../screens/manager/manager_petty_cash_page.dart';
import '../screens/organization/org_petty_cash_page.dart';
import '../screens/organization/organization_expenses.dart';
import '../screens/manager/manager_expenses.dart';
import '../screens/supervisor/site_entry_page.dart';
import '../screens/manager/manager_notification_screen.dart';
import '../screens/organization/org_notification_page.dart';
import '../screens/common/notification_page.dart';
import '../screens/organization/org_sites_list_page.dart';
import '../screens/manager/manager_sites_list_page.dart';

/// Centralized Decoupled Notification Router.
/// Resolves incoming FCM push notification payloads and in-app notification records
/// into specific deep-linked screens, complete with fallback navigation paths.
class NotificationRouter {
  static DateTime? _lastNavigationTime;

  /// Routes to the appropriate screen based on NotificationModel or raw data map.
  static void navigate(BuildContext context, dynamic payload) {
    if (!context.mounted) return;

    // Debounce rapid multiple taps (within 600ms)
    final now = DateTime.now();
    if (_lastNavigationTime != null &&
        now.difference(_lastNavigationTime!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastNavigationTime = now;

    NotificationModel model;
    Map<String, dynamic> rawMap = {};
    if (payload is NotificationModel) {
      model = payload;
      rawMap = payload.actionData ?? {};
    } else if (payload is Map<String, dynamic>) {
      rawMap = payload;
      model = NotificationModel.fromMap(payload);
    } else if (payload is Map) {
      rawMap = Map<String, dynamic>.from(payload);
      model = NotificationModel.fromMap(rawMap);
    } else {
      return;
    }

    // Automatically synchronize read status with Firestore
    if (model.notificationId.isNotEmpty) {
      NotificationService.markAsRead(model.notificationId);
    }

    try {
      final role = AuthService().userRole;
      final ud = AuthService().userData;

      // Check raw request type & keywords for dynamic routing
      final reqType = (rawMap['requestType'] ?? rawMap['type'] ?? rawMap['module'] ?? rawMap['category'] ?? '')
          .toString()
          .toLowerCase();
      final title = model.title.toLowerCase();

      // 1. Site-related
      final isSite = model.type == NotificationType.siteAssignment ||
          model.type == NotificationType.siteCreated ||
          model.type == NotificationType.projectCreated ||
          model.type == NotificationType.projectUpdated ||
          reqType.contains('site') ||
          reqType.contains('project') ||
          title.contains('site') ||
          title.contains('project');

      // 2. Petty Cash-related
      final isPettyCash = model.type == NotificationType.pettyCashRequest ||
          model.type == NotificationType.pettyCashTopup ||
          model.type == NotificationType.pettyCashDispatched ||
          reqType.contains('petty') ||
          reqType.contains('cash') ||
          title.contains('petty cash') ||
          title.contains('pettycash');

      // 3. Material-related
      final isMaterial = model.type == NotificationType.materialRequisition ||
          reqType.contains('material') ||
          title.contains('material');

      // 4. Tool-related
      final isTool = model.type == NotificationType.toolsRequisition ||
          model.type == NotificationType.toolMovement ||
          reqType.contains('tool') ||
          title.contains('tool');

      // 5. Workforce-related
      final isWorkforce = model.type == NotificationType.workforceSchedule ||
          model.type == NotificationType.dailyWorkSchedule ||
          reqType.contains('workforce') ||
          reqType.contains('worker') ||
          reqType.contains('labour') ||
          reqType.contains('sched') ||
          title.contains('workforce') ||
          title.contains('worker') ||
          title.contains('labour');

      // 6. Expense-related
      final isExpense = model.type == NotificationType.managerExpense ||
          model.type == NotificationType.organizationExpense ||
          reqType.contains('expense') ||
          title.contains('expense');

      // 7. Payment-related
      final isPayment = model.type == NotificationType.paymentRequisition ||
          reqType.contains('payment') ||
          title.contains('payment');

      if (role == UserRole.manager) {
        if (isPettyCash) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagerPettyCashPage()),
          );
          return;
        }

        if (isMaterial) {
          if (reqType.contains('approval') || reqType.contains('requisition')) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerMaterialApprovalScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialScreen()),
            );
          }
          return;
        }

        if (isTool) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ToolsMovementPage()),
          );
          return;
        }

        if (isPayment) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagerSitePaymentApprovalPage()),
          );
          return;
        }

        if (isWorkforce) {
          if (reqType.contains('approval') || reqType.contains('requisition')) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerApprovalScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkersConfigPage()),
            );
          }
          return;
        }

        if (isExpense) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagerExpenses()),
          );
          return;
        }

        if (isSite) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagerSitesListPage(initialFilter: 'All')),
          );
          return;
        }

        // Default / General fallback for manager
        _navigateToNotificationInbox(context);
        return;
      }

      // Supervisor or Organization roles
      switch (model.type) {
        case NotificationType.materialRequisition:
          if (role == UserRole.supervisor) {
            final supName = (ud['FullName'] ?? ud['fullName'] ?? ud['username'] ?? 'Supervisor').toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationPage(supervisorName: supName),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerMaterialApprovalScreen(),
              ),
            );
          }
          break;
        case NotificationType.toolsRequisition:
        case NotificationType.toolMovement:
          if (role == UserRole.supervisor) {
            final supName = (ud['FullName'] ?? ud['fullName'] ?? ud['username'] ?? 'Supervisor').toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationPage(supervisorName: supName),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ToolsMovementPage(),
              ),
            );
          }
          break;
        case NotificationType.paymentRequisition:
          if (role == UserRole.supervisor) {
            final supName = (ud['FullName'] ?? ud['fullName'] ?? ud['username'] ?? 'Supervisor').toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationPage(supervisorName: supName),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerSitePaymentApprovalPage(),
              ),
            );
          }
          break;
        case NotificationType.workforceSchedule:
        case NotificationType.dailyWorkSchedule:
          if (role == UserRole.supervisor) {
            final supName = (ud['FullName'] ?? ud['fullName'] ?? ud['username'] ?? 'Supervisor').toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationPage(supervisorName: supName),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WorkersConfigPage(),
              ),
            );
          }
          break;
        case NotificationType.pettyCashRequest:
        case NotificationType.pettyCashTopup:
        case NotificationType.pettyCashDispatched:
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
          if (role == UserRole.supervisor) {
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
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerSitesListPage(initialFilter: 'All'),
              ),
            );
          }
          break;
        case NotificationType.projectCreated:
        case NotificationType.projectUpdated:
          if (role == UserRole.organization) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgSitesListPage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerSitesListPage(initialFilter: 'All')),
            );
          }
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
    } else if (role == UserRole.supervisor) {
      final ud = AuthService().userData;
      final supName = (ud['FullName'] ?? ud['fullName'] ?? ud['username'] ?? 'Supervisor').toString();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NotificationPage(supervisorName: supName)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagerNotificationScreen()),
      );
    }
  }
}
