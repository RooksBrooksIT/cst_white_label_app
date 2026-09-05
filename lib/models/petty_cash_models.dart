import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Supervisor's centralized petty cash account balance and state.
class PettyCashAccount {
  final String accountId;
  final String orgId;
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final double totalAllocated;
  final double totalUsed;
  final double availableBalance;
  final double lowBalanceThresholdPercent;
  final bool lowBalanceTriggered;
  final double currentCycleAllocated;
  final String currentCycleId;
  final DateTime? lastTransactionAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashAccount({
    required this.accountId,
    required this.orgId,
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    this.totalAllocated = 0.0,
    this.totalUsed = 0.0,
    this.availableBalance = 0.0,
    this.lowBalanceThresholdPercent = 10.0,
    this.lowBalanceTriggered = false,
    this.currentCycleAllocated = 0.0,
    this.currentCycleId = '',
    this.lastTransactionAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Computed 10% (or configured threshold) amount in currency
  double get lowBalanceThresholdAmount =>
      (currentCycleAllocated > 0 ? currentCycleAllocated : totalAllocated) *
      (lowBalanceThresholdPercent / 100.0);

  /// True when the current available balance is at or below the low balance threshold
  bool get isLowBalance =>
      totalAllocated > 0 && availableBalance <= lowBalanceThresholdAmount;

  factory PettyCashAccount.fromMap(String id, Map<String, dynamic> data) {
    final alloc = (data['totalAllocated'] is num)
        ? (data['totalAllocated'] as num).toDouble()
        : double.tryParse(data['totalAllocated']?.toString() ?? '') ?? 0.0;

    final used = (data['totalUsed'] is num)
        ? (data['totalUsed'] as num).toDouble()
        : double.tryParse(data['totalUsed']?.toString() ?? '') ?? 0.0;

    final rawBal = (data['availableBalance'] is num)
        ? (data['availableBalance'] as num).toDouble()
        : double.tryParse(data['availableBalance']?.toString() ?? '') ??
            (alloc - used);

    final avail = rawBal.clamp(0.0, double.infinity);

    return PettyCashAccount(
      accountId: id,
      orgId: (data['orgId'] ?? '').toString(),
      supervisorId: (data['supervisorId'] ?? id).toString(),
      supervisorName: (data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      totalAllocated: alloc,
      totalUsed: used,
      availableBalance: avail,
      lowBalanceThresholdPercent: (data['lowBalanceThresholdPercent'] is num)
          ? (data['lowBalanceThresholdPercent'] as num).toDouble()
          : 10.0,
      lowBalanceTriggered: data['lowBalanceTriggered'] == true,
      currentCycleAllocated: (data['currentCycleAllocated'] is num)
          ? (data['currentCycleAllocated'] as num).toDouble()
          : alloc,
      currentCycleId: (data['currentCycleId'] ?? '').toString(),
      lastTransactionAt: _parseDateTime(data['lastTransactionAt']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'orgId': orgId,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      'totalAllocated': totalAllocated,
      'totalUsed': totalUsed,
      'availableBalance': availableBalance,
      'lowBalanceThresholdPercent': lowBalanceThresholdPercent,
      'lowBalanceTriggered': lowBalanceTriggered,
      'currentCycleAllocated': currentCycleAllocated,
      'currentCycleId': currentCycleId,
      'lastTransactionAt': lastTransactionAt != null
          ? Timestamp.fromDate(lastTransactionAt!)
          : FieldValue.serverTimestamp(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents a Petty Cash Request or Replenishment Request.
class PettyCashRequest {
  final String requestId;
  final String orgId;
  final String requestType; // 'INITIAL_ALLOCATION' or 'REPLENISHMENT'
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final double requestedAmount;
  final double approvedAmount;
  final double allocatedAmount;
  final String reason;
  final String remarks;
  final String status;
  final String statusDisplay;
  final int currentStep;
  final double currentBalanceAtRequest;
  final double totalAllocatedAtRequest;
  final double totalUsedAtRequest;
  final String managerReviewRemarks;
  final String? managerReviewedBy;
  final DateTime? managerReviewedAt;
  final String orgApprovalRemarks;
  final String? orgApprovedBy;
  final DateTime? orgApprovedAt;
  final String? orgRejectedBy;
  final String rejectionReason;
  final String? allocatedBy;
  final DateTime? allocatedAt;
  final DateTime? receivedAt;
  final String? receivedBySupervisorId;
  final String? receivedBySupervisorName;
  final List<Map<String, dynamic>> approvalHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashRequest({
    required this.requestId,
    required this.orgId,
    required this.requestType,
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    required this.requestedAmount,
    this.approvedAmount = 0.0,
    this.allocatedAmount = 0.0,
    required this.reason,
    this.remarks = '',
    required this.status,
    required this.statusDisplay,
    this.currentStep = 1,
    this.currentBalanceAtRequest = 0.0,
    this.totalAllocatedAtRequest = 0.0,
    this.totalUsedAtRequest = 0.0,
    this.managerReviewRemarks = '',
    this.managerReviewedBy,
    this.managerReviewedAt,
    this.orgApprovalRemarks = '',
    this.orgApprovedBy,
    this.orgApprovedAt,
    this.orgRejectedBy,
    this.rejectionReason = '',
    this.allocatedBy,
    this.allocatedAt,
    this.receivedAt,
    this.receivedBySupervisorId,
    this.receivedBySupervisorName,
    this.approvalHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isReplenishment => requestType == 'REPLENISHMENT';
  bool get isAwaitingConfirmation =>
      status == 'awaiting_confirmation' || status == 'awaiting_receipt_confirmation';
  bool get isReceived =>
      status == 'received' || status == 'approved' || receivedAt != null;

  factory PettyCashRequest.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashRequest(
      requestId: id,
      orgId: (data['orgId'] ?? '').toString(),
      requestType: (data['requestType'] ?? 'INITIAL_ALLOCATION').toString(),
      supervisorId: (data['supervisorId'] ?? '').toString(),
      supervisorName: (data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      requestedAmount: (data['requestedAmount'] is num)
          ? (data['requestedAmount'] as num).toDouble()
          : double.tryParse(data['requestedAmount']?.toString() ?? '') ?? 0.0,
      approvedAmount: (data['approvedAmount'] is num)
          ? (data['approvedAmount'] as num).toDouble()
          : double.tryParse(data['approvedAmount']?.toString() ?? '') ?? 0.0,
      allocatedAmount: (data['allocatedAmount'] is num)
          ? (data['allocatedAmount'] as num).toDouble()
          : double.tryParse(data['allocatedAmount']?.toString() ?? '') ?? 0.0,
      reason: (data['reason'] ?? '').toString(),
      remarks: (data['remarks'] ?? '').toString(),
      status: (data['status'] ?? 'pending_manager_review').toString(),
      statusDisplay: (data['statusDisplay'] ?? 'Pending Manager Review').toString(),
      currentStep: (data['currentStep'] is num)
          ? (data['currentStep'] as num).toInt()
          : int.tryParse(data['currentStep']?.toString() ?? '1') ?? 1,
      currentBalanceAtRequest: (data['currentBalanceAtRequest'] is num)
          ? (data['currentBalanceAtRequest'] as num).toDouble()
          : 0.0,
      totalAllocatedAtRequest: (data['totalAllocatedAtRequest'] is num)
          ? (data['totalAllocatedAtRequest'] as num).toDouble()
          : 0.0,
      totalUsedAtRequest: (data['totalUsedAtRequest'] is num)
          ? (data['totalUsedAtRequest'] as num).toDouble()
          : 0.0,
      managerReviewRemarks: (data['managerReviewRemarks'] ?? '').toString(),
      managerReviewedBy: data['managerReviewedBy']?.toString(),
      managerReviewedAt: _parseDateTime(data['managerReviewedAt']),
      orgApprovalRemarks: (data['orgApprovalRemarks'] ?? '').toString(),
      orgApprovedBy: data['orgApprovedBy']?.toString(),
      orgApprovedAt: _parseDateTime(data['orgApprovedAt']),
      orgRejectedBy: data['orgRejectedBy']?.toString(),
      rejectionReason: (data['rejectionReason'] ?? '').toString(),
      allocatedBy: data['allocatedBy']?.toString(),
      allocatedAt: _parseDateTime(data['allocatedAt']),
      receivedAt: _parseDateTime(data['receivedAt']),
      receivedBySupervisorId: data['receivedBySupervisorId']?.toString(),
      receivedBySupervisorName: data['receivedBySupervisorName']?.toString(),
      approvalHistory: (data['approvalHistory'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['approvalHistory'] as List).whereType<Map<String, dynamic>>(),
            )
          : const [],
      createdAt: _parseDateTime(data['createdAt']) ??
          _parseDateTime(data['updatedAt']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'orgId': orgId,
      'requestType': requestType,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      'requestedAmount': requestedAmount,
      'approvedAmount': approvedAmount,
      'allocatedAmount': allocatedAmount,
      'reason': reason,
      'remarks': remarks,
      'status': status,
      'statusDisplay': statusDisplay,
      'currentStep': currentStep,
      'currentBalanceAtRequest': currentBalanceAtRequest,
      'totalAllocatedAtRequest': totalAllocatedAtRequest,
      'totalUsedAtRequest': totalUsedAtRequest,
      'managerReviewRemarks': managerReviewRemarks,
      if (managerReviewedBy != null) 'managerReviewedBy': managerReviewedBy,
      if (managerReviewedAt != null)
        'managerReviewedAt': Timestamp.fromDate(managerReviewedAt!),
      'orgApprovalRemarks': orgApprovalRemarks,
      if (orgApprovedBy != null) 'orgApprovedBy': orgApprovedBy,
      if (orgApprovedAt != null)
        'orgApprovedAt': Timestamp.fromDate(orgApprovedAt!),
      if (orgRejectedBy != null) 'orgRejectedBy': orgRejectedBy,
      'rejectionReason': rejectionReason,
      if (allocatedBy != null) 'allocatedBy': allocatedBy,
      if (allocatedAt != null) 'allocatedAt': Timestamp.fromDate(allocatedAt!),
      if (receivedAt != null) 'receivedAt': Timestamp.fromDate(receivedAt!),
      if (receivedBySupervisorId != null)
        'receivedBySupervisorId': receivedBySupervisorId,
      if (receivedBySupervisorName != null)
        'receivedBySupervisorName': receivedBySupervisorName,
      'approvalHistory': approvalHistory,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents a single immutable Petty Cash Transaction / Ledger Entry.
class PettyCashTransaction {
  final String transactionId;
  final String idempotencyKey;
  final String accountId;
  final String orgId;
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final String? siteId;
  final String? siteName;
  final bool isSiteExpense;
  final String transactionType; // 'ALLOCATION', 'EXPENSE', 'REPLENISHMENT', 'ADJUSTMENT', 'REVERSAL'
  final String expenseCategory;
  final String description;
  final double amount;
  final double previousBalance;
  final double newBalance;
  final String remarks;
  final String? attachmentUrl;
  final DateTime transactionDate;
  final String createdBy;
  final String createdRole;
  final DateTime? createdAt;

  const PettyCashTransaction({
    required this.transactionId,
    required this.idempotencyKey,
    required this.accountId,
    required this.orgId,
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    this.siteId,
    this.siteName,
    this.isSiteExpense = false,
    required this.transactionType,
    this.expenseCategory = 'Other',
    required this.description,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    this.remarks = '',
    this.attachmentUrl,
    required this.transactionDate,
    required this.createdBy,
    required this.createdRole,
    this.createdAt,
  });

  bool get isExpense => transactionType == 'EXPENSE';
  bool get isAllocation =>
      transactionType == 'ALLOCATION' || transactionType == 'REPLENISHMENT';

  factory PettyCashTransaction.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashTransaction(
      transactionId: id,
      idempotencyKey: (data['idempotencyKey'] ?? id).toString(),
      accountId: (data['accountId'] ?? '').toString(),
      orgId: (data['orgId'] ?? '').toString(),
      supervisorId: (data['supervisorId'] ?? '').toString(),
      supervisorName: (data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      siteId: data['siteId']?.toString(),
      siteName: data['siteName']?.toString(),
      isSiteExpense: data['isSiteExpense'] == true,
      transactionType: (data['transactionType'] ?? 'EXPENSE').toString(),
      expenseCategory: (data['expenseCategory'] ?? 'Other').toString(),
      description: (data['description'] ?? '').toString(),
      amount: (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : double.tryParse(data['amount']?.toString() ?? '') ?? 0.0,
      previousBalance: (data['previousBalance'] is num)
          ? (data['previousBalance'] as num).toDouble()
          : 0.0,
      newBalance: (data['newBalance'] is num)
          ? (data['newBalance'] as num).toDouble()
          : 0.0,
      remarks: (data['remarks'] ?? '').toString(),
      attachmentUrl: data['attachmentUrl']?.toString(),
      transactionDate: _parseDateTime(data['transactionDate']) ?? DateTime.now(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdRole: (data['createdRole'] ?? 'Supervisor').toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'idempotencyKey': idempotencyKey,
      'accountId': accountId,
      'orgId': orgId,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      'siteId': siteId ?? '',
      'siteName': siteName ?? '',
      'isSiteExpense': isSiteExpense,
      'transactionType': transactionType,
      'expenseCategory': expenseCategory,
      'description': description,
      'amount': amount,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'remarks': remarks,
      'attachmentUrl': attachmentUrl ?? '',
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdBy': createdBy,
      'createdRole': createdRole,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// Represents an immutable Audit Log Entry for Petty Cash lifecycle events.
class PettyCashAuditLog {
  final String logId;
  final String action;
  final String entityType; // 'ACCOUNT', 'REQUEST', 'TRANSACTION'
  final String entityId;
  final String actorId;
  final String actorName;
  final String actorRole; // 'Supervisor', 'Manager', 'Organization'
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> newState;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const PettyCashAuditLog({
    required this.logId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    this.previousState = const {},
    this.newState = const {},
    this.metadata = const {},
    required this.timestamp,
  });

  factory PettyCashAuditLog.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashAuditLog(
      logId: id,
      action: (data['action'] ?? '').toString(),
      entityType: (data['entityType'] ?? 'REQUEST').toString(),
      entityId: (data['entityId'] ?? '').toString(),
      actorId: (data['actorId'] ?? '').toString(),
      actorName: (data['actorName'] ?? '').toString(),
      actorRole: (data['actorRole'] ?? '').toString(),
      previousState: (data['previousState'] is Map)
          ? Map<String, dynamic>.from(data['previousState'] as Map)
          : const {},
      newState: (data['newState'] is Map)
          ? Map<String, dynamic>.from(data['newState'] as Map)
          : const {},
      metadata: (data['metadata'] is Map)
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : const {},
      timestamp: _parseDateTime(data['timestamp']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
      'previousState': previousState,
      'newState': newState,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
