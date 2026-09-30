import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Enum representing the category of project alert
enum ProjectAlertType {
  budgetExpense,   // Expenses approaching or exceeding received amount / budget
  customerPayment, // Customer received amount reaching project budget threshold
  endDate,         // Planned project end date coming soon or overdue
}

/// Enum representing the alert severity level
enum ProjectAlertSeverity {
  info,
  warning,
  critical,
}

/// Model for a calculated project alert
class ProjectAlert {
  final ProjectAlertType type;
  final ProjectAlertSeverity severity;
  final String title;
  final String message;
  final String indicatorLabel;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  final double percentage;
  final int daysRemaining;

  const ProjectAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.indicatorLabel,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    this.percentage = 0.0,
    this.daysRemaining = 0,
  });
}

/// Service class for calculating and triggering Budget, Expense, Payment, and End-Date alerts.
class ProjectAlertService {
  // Configurable threshold constants
  static const double expenseVsReceivedWarningThreshold = 0.80; // 80%
  static const double expenseVsReceivedCriticalThreshold = 1.00; // 100%
  static const double expenseVsBudgetWarningThreshold = 0.80;   // 80%
  static const double expenseVsBudgetCriticalThreshold = 1.00;  // 100%
  static const double paymentVsBudgetWarningThreshold = 0.80;   // 80%
  static const double paymentVsBudgetHighThreshold = 0.90;      // 90%
  static const int endDateWarningDays = 5;                       // Days before end date to trigger alert

  // Track dispatched notification keys in memory to prevent duplicate notifications within the same day
  static final Set<String> _dispatchedNotificationKeys = {};

  /// Parses date from dynamic inputs (Timestamp, DateTime, String, int)
  static DateTime? parseProjectDate(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is DateTime) return rawDate;
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is int) return DateTime.fromMillisecondsSinceEpoch(rawDate);

    final str = rawDate.toString().trim();
    if (str.isEmpty) return null;

    // Try standard ISO 8601
    try {
      return DateTime.parse(str);
    } catch (_) {}

    // Format patterns to try
    final formats = [
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'd-M-yyyy',
      'yyyy-M-d',
      'dd MMM yyyy',
      'yyyy-MM-ddTHH:mm:ss',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(str);
      } catch (_) {}
    }

    return null;
  }

  /// Safely extracts numeric value from dynamic project map
  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? 0.0;
  }

  /// Evaluates all active alerts for a given project data map
  static List<ProjectAlert> getAlertsForProject(
    Map<String, dynamic> projectData, {
    String? docId,
  }) {
    final List<ProjectAlert> alerts = [];

    // Safely extract project financial and date fields
    final double budget = _parseNum(
      projectData['projectBudget'] ??
          projectData['estimatedBudget'] ??
          projectData['contractorBudget'] ??
          projectData['budget'],
    );

    final double amountReceived = _parseNum(
      projectData['amountReceived'] ??
          projectData['amountPaid'] ??
          projectData['receivedPayments'] ??
          projectData['paid'],
    );

    final double amountSpent = _parseNum(
      projectData['amountSpent'] ??
          projectData['totalExpense'] ??
          projectData['expenses'] ??
          projectData['spent'] ??
          projectData['totalExpenses'],
    );

    final stage = (projectData['projectStage'] ??
            projectData['status'] ??
            projectData['stage'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    final isCompleted = stage == 'completed' ||
        stage == 'closed' ||
        stage == 'finished' ||
        stage == 'archived';

    // -------------------------------------------------------------------------
    // 1. BUDGET EXPENSE ALERT
    // -------------------------------------------------------------------------
    if (amountSpent > 0) {
      // Check 1A: Expenses vs Amount Received
      if (amountReceived > 0) {
        final ratio = amountSpent / amountReceived;
        final pct = (ratio * 100).clamp(0.0, 999.0);

        if (ratio >= expenseVsReceivedCriticalThreshold) {
          alerts.add(ProjectAlert(
            type: ProjectAlertType.budgetExpense,
            severity: ProjectAlertSeverity.critical,
            title: 'Expense Exceeded Received Amount',
            message:
                'Expenses (₹${amountSpent.toStringAsFixed(0)}) have exceeded Customer Received Amount (₹${amountReceived.toStringAsFixed(0)}).',
            indicatorLabel: '⚠️ Expense > Received (${pct.toStringAsFixed(0)}%)',
            icon: Icons.warning_amber_rounded,
            primaryColor: const Color(0xFFDC2626), // Red
            backgroundColor: const Color(0xFFFEE2E2),
            textColor: const Color(0xFF991B1B),
            percentage: pct,
          ));
        } else if (ratio >= expenseVsReceivedWarningThreshold) {
          alerts.add(ProjectAlert(
            type: ProjectAlertType.budgetExpense,
            severity: ProjectAlertSeverity.warning,
            title: 'High Expense Warning',
            message:
                'Expenses (₹${amountSpent.toStringAsFixed(0)}) reached ${pct.toStringAsFixed(0)}% of Customer Received Amount (₹${amountReceived.toStringAsFixed(0)}).',
            indicatorLabel: '⚠️ High Expense (${pct.toStringAsFixed(0)}% Recv)',
            icon: Icons.error_outline_rounded,
            primaryColor: const Color(0xFFEA580C), // Orange
            backgroundColor: const Color(0xFFFFEDD5),
            textColor: const Color(0xFF9A3412),
            percentage: pct,
          ));
        }
      }

      // Check 1B: Expenses vs Project Budget
      if (budget > 0) {
        final bRatio = amountSpent / budget;
        final bPct = (bRatio * 100).clamp(0.0, 999.0);

        // Only add if not already flagged by Critical 1A or to add specific budget alert
        final hasExpenseAlert = alerts.any((a) => a.type == ProjectAlertType.budgetExpense);
        if (!hasExpenseAlert) {
          if (bRatio >= expenseVsBudgetCriticalThreshold) {
            alerts.add(ProjectAlert(
              type: ProjectAlertType.budgetExpense,
              severity: ProjectAlertSeverity.critical,
              title: 'Budget Limit Exceeded',
              message:
                  'Expenses (₹${amountSpent.toStringAsFixed(0)}) exceeded Project Budget (₹${budget.toStringAsFixed(0)}).',
              indicatorLabel: '⚠️ Budget Exceeded (${bPct.toStringAsFixed(0)}%)',
              icon: Icons.account_balance_wallet_outlined,
              primaryColor: const Color(0xFFDC2626),
              backgroundColor: const Color(0xFFFEE2E2),
              textColor: const Color(0xFF991B1B),
              percentage: bPct,
            ));
          } else if (bRatio >= expenseVsBudgetWarningThreshold) {
            alerts.add(ProjectAlert(
              type: ProjectAlertType.budgetExpense,
              severity: ProjectAlertSeverity.warning,
              title: 'Budget Utilization Warning',
              message:
                  'Expenses (₹${amountSpent.toStringAsFixed(0)}) reached ${bPct.toStringAsFixed(0)}% of Project Budget (₹${budget.toStringAsFixed(0)}).',
              indicatorLabel: '⚠️ High Budget Spent (${bPct.toStringAsFixed(0)}%)',
              icon: Icons.pie_chart_outline_rounded,
              primaryColor: const Color(0xFFD97706), // Amber
              backgroundColor: const Color(0xFFFEF3C7),
              textColor: const Color(0xFF92400E),
              percentage: bPct,
            ));
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. CUSTOMER PAYMENT / BUDGET ALERT
    // -------------------------------------------------------------------------
    if (amountReceived > 0 && budget > 0) {
      final pRatio = amountReceived / budget;
      final pPct = (pRatio * 100).clamp(0.0, 999.0);

      if (pRatio >= paymentVsBudgetHighThreshold) {
        alerts.add(ProjectAlert(
          type: ProjectAlertType.customerPayment,
          severity: ProjectAlertSeverity.info,
          title: 'Payment Threshold Milestone',
          message:
              'Customer Amount Received (₹${amountReceived.toStringAsFixed(0)}) reached ${pPct.toStringAsFixed(0)}% of Planned Project Budget (₹${budget.toStringAsFixed(0)}).',
          indicatorLabel: '💰 ${pPct.toStringAsFixed(0)}% Budget Received',
          icon: Icons.monetization_on_outlined,
          primaryColor: const Color(0xFF2563EB), // Blue
          backgroundColor: const Color(0xFFDBEAFE),
          textColor: const Color(0xFF1E40AF),
          percentage: pPct,
        ));
      } else if (pRatio >= paymentVsBudgetWarningThreshold) {
        alerts.add(ProjectAlert(
          type: ProjectAlertType.customerPayment,
          severity: ProjectAlertSeverity.info,
          title: 'Payment Progress Alert',
          message:
              'Customer Amount Received (₹${amountReceived.toStringAsFixed(0)}) reached ${pPct.toStringAsFixed(0)}% of Planned Project Budget (₹${budget.toStringAsFixed(0)}).',
          indicatorLabel: '💰 ${pPct.toStringAsFixed(0)}% Recv Threshold',
          icon: Icons.payments_outlined,
          primaryColor: const Color(0xFF0284C7), // Light Blue
          backgroundColor: const Color(0xFFE0F2FE),
          textColor: const Color(0xFF075985),
          percentage: pPct,
        ));
      }
    }

    // -------------------------------------------------------------------------
    // 3. PLANNED PROJECT END-DATE ALERT
    // -------------------------------------------------------------------------
    if (!isCompleted) {
      final endDateRaw = projectData['endDate'] ??
          projectData['plannedEndDate'] ??
          projectData['completionDate'] ??
          projectData['end_date'] ??
          projectData['targetDate'];

      final endDate = parseProjectDate(endDateRaw);

      if (endDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final targetEndDay = DateTime(endDate.year, endDate.month, endDate.day);
        final daysDiff = targetEndDay.difference(today).inDays;

        if (daysDiff < 0) {
          final overdueDays = daysDiff.abs();
          alerts.add(ProjectAlert(
            type: ProjectAlertType.endDate,
            severity: ProjectAlertSeverity.critical,
            title: 'Project Overdue',
            message:
                'Planned project end date (${DateFormat('dd-MM-yyyy').format(endDate)}) passed $overdueDays day${overdueDays > 1 ? 's' : ''} ago.',
            indicatorLabel: '🚨 Overdue by $overdueDays d',
            icon: Icons.event_busy_rounded,
            primaryColor: const Color(0xFFE11D48), // Rose / Red
            backgroundColor: const Color(0xFFFFE4E6),
            textColor: const Color(0xFF9F1239),
            daysRemaining: daysDiff,
          ));
        } else if (daysDiff == 0) {
          alerts.add(ProjectAlert(
            type: ProjectAlertType.endDate,
            severity: ProjectAlertSeverity.warning,
            title: 'Project End Date Today',
            message: 'Your planned project end date is today (${DateFormat('dd-MM-yyyy').format(endDate)}).',
            indicatorLabel: '⏰ Planned End Date Today',
            icon: Icons.alarm_on_rounded,
            primaryColor: const Color(0xFFD97706),
            backgroundColor: const Color(0xFFFEF3C7),
            textColor: const Color(0xFF92400E),
            daysRemaining: 0,
          ));
        } else if (daysDiff <= endDateWarningDays) {
          alerts.add(ProjectAlert(
            type: ProjectAlertType.endDate,
            severity: ProjectAlertSeverity.warning,
            title: 'Upcoming Project End Date',
            message: 'Your planned project end date is coming in $daysDiff day${daysDiff > 1 ? 's' : ''}.',
            indicatorLabel: '⏰ End Date in $daysDiff day${daysDiff > 1 ? 's' : ''}',
            icon: Icons.access_time_filled_rounded,
            primaryColor: const Color(0xFFD97706), // Amber
            backgroundColor: const Color(0xFFFEF3C7),
            textColor: const Color(0xFF92400E),
            daysRemaining: daysDiff,
          ));
        }
      }
    }

    return alerts;
  }

  /// Triggers in-app / FCM notifications to Manager when project alerts are active.
  /// Uses idempotency caching to prevent duplicate notifications within the same calendar day.
  static Future<void> checkAndTriggerProjectNotifications(
    Map<String, dynamic> projectData, {
    String? docId,
  }) async {
    try {
      final alerts = getAlertsForProject(projectData, docId: docId);
      if (alerts.isEmpty) return;

      final pName = (projectData['projectName'] ??
              projectData['siteName'] ??
              projectData['name'] ??
              'Project')
          .toString()
          .trim();

      final pId = (docId ??
              projectData['siteId'] ??
              projectData['projectId'] ??
              projectData['id'] ??
              pName)
          .toString()
          .trim();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (final alert in alerts) {
        // Idempotency key per project per alert type per day
        final notifKey = '${pId}_${alert.type.name}_$todayStr';
        if (_dispatchedNotificationKeys.contains(notifKey)) continue;

        _dispatchedNotificationKeys.add(notifKey);

        final title = '${alert.icon == Icons.event_busy_rounded ? "🚨" : "⚠️"} ${alert.title}: $pName';
        final body = alert.message;

        // Dispatch dual notification targeting Manager and Organization
        await NotificationService.notifyManagerAndOrganisation(
          title: title,
          body: body,
          requestType: 'project_alert_${alert.type.name}',
          requestId: 'alert_${pId}_${DateTime.now().millisecondsSinceEpoch}',
          docId: pId,
          siteId: pId,
          siteName: pName,
          status: alert.severity.name.toUpperCase(),
          senderRole: 'System Alert',
          senderName: 'eBricks Project Alert',
          remarks: alert.message,
          requiredAction: 'View Project Details',
          extraData: {
            'alertType': alert.type.name,
            'alertSeverity': alert.severity.name,
            'projectId': pId,
            'projectName': pName,
            'percentage': alert.percentage,
            'daysRemaining': alert.daysRemaining,
            'actionRoute': '/project_details',
            'idempotencyKey': notifKey,
          },
        );
      }
    } catch (e) {
      debugPrint('ProjectAlertService: Error triggering project alert notifications: $e');
    }
  }
}
