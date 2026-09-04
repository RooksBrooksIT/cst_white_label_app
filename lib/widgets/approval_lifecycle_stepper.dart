import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:demo_cst/services/approval_workflow_service.dart';
import 'package:intl/intl.dart';

class ApprovalLifecycleStepper extends StatelessWidget {
  final String? status;
  final List<dynamic>? history;
  final bool isCompact;
  final String? rejectionReason;

  const ApprovalLifecycleStepper({
    super.key,
    required this.status,
    this.history,
    this.isCompact = false,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final stage = ApprovalWorkflowService.parseStatus(status);
    final isRejected = stage == ApprovalStage.rejectedByManager ||
        stage == ApprovalStage.rejectedByOrg;
    final activeStep = ApprovalWorkflowService.getStepNumber(status);

    if (isRejected) {
      return _buildRejectedBanner(context, stage);
    }

    if (isCompact) {
      return _buildCompactStepper(context, activeStep);
    }

    return _buildFullStepper(context, activeStep);
  }

  // --- REJECTED BANNER ---
  Widget _buildRejectedBanner(BuildContext context, ApprovalStage stage) {
    final isOrg = stage == ApprovalStage.rejectedByOrg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrg ? 'Rejected by Organization' : 'Rejected by Manager',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                ),
                if (rejectionReason != null && rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reason: $rejectionReason',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (history != null && history!.isNotEmpty)
            InkWell(
              onTap: () => _showAuditHistorySheet(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Logs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- COMPACT STEPPER ---
  Widget _buildCompactStepper(BuildContext context, int activeStep) {
    return InkWell(
      onTap: () => _showAuditHistorySheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            for (int i = 1; i <= 4; i++) ...[
              _buildStepCircle(i, activeStep, isSmall: true),
              if (i < 4)
                Expanded(
                  child: Container(
                    height: 2,
                    color: activeStep > i
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(activeStep).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ApprovalWorkflowService.getStatusDisplayText(status),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _getStatusColor(activeStep),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FULL STEPPER ---
  Widget _buildFullStepper(BuildContext context, int activeStep) {
    final steps = [
      {'num': 1, 'title': 'Supervisor', 'sub': 'Submitted'},
      {'num': 2, 'title': 'Manager', 'sub': 'Review'},
      {'num': 3, 'title': 'Org HQ', 'sub': 'Approved'},
      {'num': 4, 'title': 'Clearance', 'sub': 'Dispatched'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(activeStep),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Approval Pipeline (Stage $activeStep/4)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (history != null && history!.isNotEmpty)
                InkWell(
                  onTap: () => _showAuditHistorySheet(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Audit Trail',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      _buildStepCircle(steps[i]['num'] as int, activeStep),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 14,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            steps[i]['title'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: activeStep >= (steps[i]['num'] as int)
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      SizedBox(
                        height: 13,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            steps[i]['sub'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: activeStep >= (steps[i]['num'] as int)
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFFCBD5E1),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    margin: const EdgeInsets.only(top: 11),
                    width: 14,
                    height: 2,
                    color: activeStep > (steps[i]['num'] as int)
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int stepNum, int activeStep, {bool isSmall = false}) {
    final isDone = activeStep > stepNum || activeStep == 4;
    final isCurrent = activeStep == stepNum && activeStep < 4;
    final size = isSmall ? 18.0 : 24.0;

    if (isDone) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, color: Colors.white, size: isSmall ? 11 : 15),
      );
    }

    if (isCurrent) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFBFDBFE), width: 3),
        ),
        child: Center(
          child: Text(
            '$stepNum',
            style: TextStyle(
              fontSize: isSmall ? 9 : 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Center(
        child: Text(
          '$stepNum',
          style: TextStyle(
            fontSize: isSmall ? 9 : 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(int activeStep) {
    if (activeStep == 4) return const Color(0xFF10B981);
    if (activeStep == 3) return const Color(0xFF8B5CF6);
    if (activeStep == 2) return const Color(0xFFF59E0B);
    return const Color(0xFF2563EB);
  }

  // --- AUDIT HISTORY BOTTOM SHEET ---
  void _showAuditHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final logs = List<Map<String, dynamic>>.from(history ?? []);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Approval Chain Audit Trail',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No audit history records available yet.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final item = logs[i];
                      final role = item['actorRole'] ?? item['role'] ?? 'User';
                      final name = item['actorName'] ?? item['performedBy'] ?? 'Unknown';
                      final action = item['action'] ?? 'Action Recorded';
                      final remarks = item['remarks'] ?? '';
                      final formattedDate = item['formattedDate'] ??
                          (item['timestamp'] is Timestamp
                              ? DateFormat('dd MMM yyyy, hh:mm a').format((item['timestamp'] as Timestamp).toDate())
                              : '');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(role).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role.toString().toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: _getRoleColor(role),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            if (remarks.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Remarks: "$remarks"',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    final r = role.toLowerCase();
    if (r.contains('org')) return const Color(0xFF8B5CF6);
    if (r.contains('man')) return const Color(0xFF2563EB);
    if (r.contains('sup')) return const Color(0xFF059669);
    return const Color(0xFF64748B);
  }
}
