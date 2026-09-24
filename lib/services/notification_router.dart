import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
import '../screens/manager/manager_notification_screen.dart';
import '../screens/organization/org_notification_page.dart';
import '../screens/common/notification_page.dart';
import '../screens/organization/org_sites_list_page.dart';
import '../screens/manager/manager_sites_list_page.dart';
import '../screens/supervisor/supervisor_material_information.dart';

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

      final reqType = (rawMap['requestType'] ?? rawMap['type'] ?? rawMap['module'] ?? rawMap['category'] ?? '')
          .toString()
          .toLowerCase();
      final title = model.title.toLowerCase();

      // Check for Welcome / Account Registration notifications
      final isWelcome = model.type == NotificationType.supervisorAccountCreated ||
          model.type == NotificationType.managerAccountCreated ||
          reqType.contains('supervisor_config') ||
          reqType.contains('manager_config') ||
          title.contains('welcome');

      if (isWelcome) {
        WelcomeNotificationDetailsDialog.show(context, model: model, rawData: rawMap);
        return;
      }

      // Check for New Site Assignment notifications
      final isSiteAssignment = model.type == NotificationType.siteAssignment ||
          reqType == 'site_assignment' ||
          title.contains('site assignment') ||
          title.contains('assigned to site');

      if (isSiteAssignment) {
        SiteAssignmentDetailsDialog.show(context, model: model, rawData: rawMap);
        return;
      }

      // Check for Material Allocation notifications
      final isMaterialAllocation = reqType == 'material_allocation' ||
          reqType == 'material_assignment' ||
          title.contains('material allocated') ||
          title.contains('materials assigned');

      if (isMaterialAllocation) {
        MaterialAllocationDetailsDialog.show(context, model: model, rawData: rawMap);
        return;
      }

      // Check raw request type & keywords for dynamic routing
      final isSite = model.type == NotificationType.siteCreated ||
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
          SiteAssignmentDetailsDialog.show(context, model: model, rawData: rawMap);
          break;
        case NotificationType.siteCreated:
          if (role == UserRole.supervisor) {
            SiteAssignmentDetailsDialog.show(context, model: model, rawData: rawMap);
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
          WelcomeNotificationDetailsDialog.show(context, model: model, rawData: rawMap);
          break;
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

// =============================================================================
// DEDICATED DIALOG 1: SITE ASSIGNMENT DETAILS
// =============================================================================

class SiteAssignmentDetailsDialog extends StatelessWidget {
  final NotificationModel model;
  final Map<String, dynamic> rawData;

  const SiteAssignmentDetailsDialog({
    super.key,
    required this.model,
    required this.rawData,
  });

  static void show(
    BuildContext context, {
    required NotificationModel model,
    required Map<String, dynamic> rawData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SiteAssignmentDetailsDialog(model: model, rawData: rawData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final siteId = (rawData['siteId'] ?? rawData['siteCode'] ?? rawData['siteDocId'] ?? model.siteId ?? '').toString().trim();
    final siteName = (rawData['siteName'] ?? rawData['site'] ?? model.siteName ?? 'Site Assignment').toString().trim();
    final location = (rawData['location'] ?? rawData['siteLocation'] ?? '').toString().trim();
    final address = (rawData['address'] ?? rawData['siteAddress'] ?? rawData['completeAddress'] ?? location).toString().trim();
    final projectName = (rawData['projectName'] ?? rawData['project'] ?? '').toString().trim();
    final managerName = (rawData['managerName'] ?? rawData['senderName'] ?? model.senderName ?? 'Manager').toString().trim();
    final supervisorName = (rawData['supervisorName'] ?? rawData['supervisor'] ?? model.recipientId ?? AuthService().userData['FullName'] ?? AuthService().userData['username'] ?? 'Supervisor').toString().trim();

    String formattedDate = '';
    final createdAt = rawData['createdAt'] ?? model.createdAt;
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
    } else if (createdAt is String && createdAt.isNotEmpty) {
      formattedDate = createdAt;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    Color.alphaBlend(primaryColor.withValues(alpha: 0.8), const Color(0xFF0F172A)),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Site Assignment Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'New site allocated to your profile',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Active Site Assignment',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Information Fields
                    _buildInfoCard([
                      _InfoRow(
                        icon: Icons.tag_rounded,
                        label: 'Site ID',
                        value: siteId.isNotEmpty ? siteId : 'N/A',
                        isHighlight: true,
                        primaryColor: primaryColor,
                      ),
                      _InfoRow(
                        icon: Icons.apartment_rounded,
                        label: 'Site Name',
                        value: siteName.isNotEmpty ? siteName : 'N/A',
                        isBold: true,
                      ),
                      if (projectName.isNotEmpty)
                        _InfoRow(
                          icon: Icons.folder_special_rounded,
                          label: 'Project Name',
                          value: projectName,
                        ),
                      _InfoRow(
                        icon: Icons.place_rounded,
                        label: 'Site Location',
                        value: location.isNotEmpty ? location : 'Not specified',
                      ),
                      _InfoRow(
                        icon: Icons.map_rounded,
                        label: 'Complete Address',
                        value: address.isNotEmpty ? address : (location.isNotEmpty ? location : 'Not specified'),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // Assignment Metadata Card
                    _buildInfoCard([
                      _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Assigned Supervisor',
                        value: supervisorName,
                      ),
                      _InfoRow(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Assigned By',
                        value: managerName,
                      ),
                      if (formattedDate.isNotEmpty)
                        _InfoRow(
                          icon: Icons.access_time_filled_rounded,
                          label: 'Assigned Date',
                          value: formattedDate,
                        ),
                    ]),
                  ],
                ),
              ),
            ),

            // Footer Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close Details',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// DEDICATED DIALOG 2: WELCOME NOTIFICATION DETAILS
// =============================================================================

class WelcomeNotificationDetailsDialog extends StatelessWidget {
  final NotificationModel model;
  final Map<String, dynamic> rawData;

  const WelcomeNotificationDetailsDialog({
    super.key,
    required this.model,
    required this.rawData,
  });

  static void show(
    BuildContext context, {
    required NotificationModel model,
    required Map<String, dynamic> rawData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WelcomeNotificationDetailsDialog(model: model, rawData: rawData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final ud = AuthService().userData;
    final title = model.title.isNotEmpty ? model.title : 'Welcome to eBricks';
    final supervisorName = (rawData['supervisorName'] ?? rawData['FullName'] ?? rawData['name'] ?? ud['FullName'] ?? ud['username'] ?? 'Supervisor').toString().trim();
    final supervisorId = (rawData['supervisorId'] ?? rawData['Supervisor ID'] ?? rawData['requestId'] ?? ud['supervisorId'] ?? 'N/A').toString().trim();
    final managerName = (rawData['managerName'] ?? rawData['senderName'] ?? model.senderName ?? 'Manager Admin').toString().trim();
    final designation = (rawData['designation'] ?? ud['designation'] ?? 'Site Supervisor').toString().trim();
    final username = (rawData['username'] ?? ud['username'] ?? '').toString().trim();

    String formattedDate = '';
    final createdAt = rawData['createdAt'] ?? model.createdAt;
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
    } else if (createdAt is String && createdAt.isNotEmpty) {
      formattedDate = createdAt;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0284C7),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Account Registration Confirmation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF0284C7),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Welcome to eBricks Construction Management. Your account is verified and ready for daily operations.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF0C4A6E),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Information Details Card
                    _buildInfoCard([
                      _InfoRow(
                        icon: Icons.badge_rounded,
                        label: 'Notification Title',
                        value: title,
                        isBold: true,
                      ),
                      _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Supervisor Name',
                        value: supervisorName,
                        isHighlight: true,
                        primaryColor: primaryColor,
                      ),
                      _InfoRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'Supervisor ID',
                        value: supervisorId,
                      ),
                      if (designation.isNotEmpty)
                        _InfoRow(
                          icon: Icons.work_rounded,
                          label: 'Designation / Role',
                          value: designation,
                        ),
                      if (username.isNotEmpty)
                        _InfoRow(
                          icon: Icons.account_circle_rounded,
                          label: 'Username',
                          value: username,
                        ),
                      _InfoRow(
                        icon: Icons.how_to_reg_rounded,
                        label: 'Registered By (Manager)',
                        value: managerName,
                      ),
                      if (formattedDate.isNotEmpty)
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Registration Date',
                          value: formattedDate,
                        ),
                    ]),
                  ],
                ),
              ),
            ),

            // Footer Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// DEDICATED DIALOG 3: MATERIAL ALLOCATION DETAILS
// =============================================================================

class MaterialAllocationDetailsDialog extends StatelessWidget {
  final NotificationModel model;
  final Map<String, dynamic> rawData;

  const MaterialAllocationDetailsDialog({
    super.key,
    required this.model,
    required this.rawData,
  });

  static void show(
    BuildContext context, {
    required NotificationModel model,
    required Map<String, dynamic> rawData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MaterialAllocationDetailsDialog(model: model, rawData: rawData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final siteId = (rawData['siteId'] ?? rawData['siteCode'] ?? model.siteId ?? '').toString().trim();
    final siteName = (rawData['siteName'] ?? rawData['site'] ?? model.siteName ?? 'Site Allocation').toString().trim();
    final projectName = (rawData['projectName'] ?? rawData['project'] ?? '').toString().trim();
    final materialName = (rawData['materialName'] ?? rawData['displayName'] ?? 'Material').toString().trim();
    final displayName = (rawData['displayName'] ?? materialName).toString().trim();

    final dynamic rawQty = rawData['quantity'] ?? rawData['qty'];
    final String qtyStr = rawData['quantityStr']?.toString() ??
        (rawQty != null
            ? (rawQty is num
                ? (rawQty.truncateToDouble() == rawQty ? rawQty.toInt().toString() : rawQty.toString())
                : rawQty.toString())
            : '');
    final String unitStr = (rawData['unit'] ?? '').toString().trim();
    final String quantityDisplay = qtyStr.isNotEmpty
        ? (unitStr.isNotEmpty ? '$qtyStr $unitStr' : qtyStr)
        : 'Allocated';

    final dynamic rawRate = rawData['unitRate'] ?? rawData['rate'];
    final double? unitRate = (rawRate is num && rawRate > 0) ? rawRate.toDouble() : null;
    final dynamic rawAmt = rawData['allocatedAmount'] ?? rawData['amount'];
    final double? totalAmount = (rawAmt is num && rawAmt > 0) ? rawAmt.toDouble() : null;

    final managerName = (rawData['managerName'] ??
            rawData['allocatedBy'] ??
            rawData['senderName'] ??
            model.senderName ??
            'Manager')
        .toString()
        .trim();
    final remarks = (rawData['remarks'] ?? model.remarks ?? '').toString().trim();

    String formattedDate = '';
    final rawDate = rawData['allocationDateTime'] ?? rawData['allocationDate'];
    if (rawDate != null && rawDate.toString().isNotEmpty) {
      formattedDate = rawDate.toString();
    } else {
      final createdAt = rawData['createdAt'] ?? model.createdAt;
      if (createdAt is Timestamp) {
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
      } else if (createdAt is String && createdAt.isNotEmpty) {
        formattedDate = createdAt;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF059669), // Emerald
                    Color.alphaBlend(primaryColor.withValues(alpha: 0.7), const Color(0xFF047857)),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Material Allocation',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stock allocated by Manager to your site',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Active Stock Allocated',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Material & Site Details Card
                    _buildInfoCard([
                      _InfoRow(
                        icon: Icons.apartment_rounded,
                        label: 'Site',
                        value: siteName.isNotEmpty ? siteName : 'N/A',
                        isBold: true,
                      ),
                      if (siteId.isNotEmpty)
                        _InfoRow(
                          icon: Icons.tag_rounded,
                          label: 'Site ID',
                          value: siteId,
                          isHighlight: true,
                          primaryColor: primaryColor,
                        ),
                      if (projectName.isNotEmpty)
                        _InfoRow(
                          icon: Icons.folder_special_rounded,
                          label: 'Project',
                          value: projectName,
                        ),
                      _InfoRow(
                        icon: Icons.category_rounded,
                        label: 'Material Name',
                        value: displayName.isNotEmpty ? displayName : materialName,
                        isBold: true,
                      ),
                      _InfoRow(
                        icon: Icons.production_quantity_limits_rounded,
                        label: 'Allocated Qty',
                        value: quantityDisplay,
                        isHighlight: true,
                        primaryColor: const Color(0xFF059669),
                      ),
                      if (unitRate != null)
                        _InfoRow(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Unit Rate',
                          value:
                              '₹${unitRate.truncateToDouble() == unitRate ? unitRate.toInt() : unitRate.toStringAsFixed(2)} / $unitStr',
                        ),
                      if (totalAmount != null)
                        _InfoRow(
                          icon: Icons.receipt_long_rounded,
                          label: 'Total Amount',
                          value:
                              '₹${NumberFormat.currency(symbol: '', decimalDigits: 0).format(totalAmount).trim()}',
                          isBold: true,
                        ),
                    ]),

                    const SizedBox(height: 12),

                    // Allocation Metadata Card
                    _buildInfoCard([
                      _InfoRow(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Allocated By',
                        value: managerName.isNotEmpty ? managerName : 'Manager',
                      ),
                      if (formattedDate.isNotEmpty)
                        _InfoRow(
                          icon: Icons.access_time_filled_rounded,
                          label: 'Allocation Date',
                          value: formattedDate,
                        ),
                      if (remarks.isNotEmpty)
                        _InfoRow(
                          icon: Icons.notes_rounded,
                          label: 'Remarks',
                          value: remarks,
                        ),
                    ]),
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupervisorMaterialInfoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text(
                        'View Site Stock',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// REUSABLE INFO ROW WIDGET
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isHighlight;
  final bool isBold;
  final Color? primaryColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.isBold = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (isHighlight || isBold) ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
                  ? (primaryColor ?? const Color(0xFF0F172A))
                  : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
