import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical Status State Machine for Petty Cash Lifecycle
class PettyCashStatus {
  static const String draft = 'DRAFT';
  static const String submitted = 'SUBMITTED';
  static const String pendingManagerReview = 'PENDING_MANAGER_REVIEW';
  static const String rejectedByManager = 'REJECTED_BY_MANAGER';
  static const String pendingOrgApproval = 'PENDING_ORGANIZATION_APPROVAL';
  static const String rejectedByOrg = 'REJECTED_BY_ORGANIZATION';
  static const String approved = 'APPROVED';
  static const String awaitingDisbursement = 'AWAITING_DISBURSEMENT';
  static const String disbursed = 'DISBURSED';
  static const String awaitingReceiptConfirmation = 'AWAITING_RECEIPT_CONFIRMATION';
  static const String received = 'RECEIVED';
  static const String active = 'ACTIVE';

  // Expense statuses
  static const String pendingExpenseReview = 'PENDING_EXPENSE_REVIEW';
  static const String expenseApproved = 'EXPENSE_APPROVED';
  static const String expenseRejected = 'EXPENSE_REJECTED';

  // Replenishment, Reconciliation, Returns, Terminations
  static const String replenishmentRequested = 'REPLENISHMENT_REQUESTED';
  static const String reconciliationPending = 'RECONCILIATION_PENDING';
  static const String reconciliationApproved = 'RECONCILIATION_APPROVED';
  static const String discrepancyReview = 'DISCREPANCY_REVIEW';
  static const String pendingReturnConfirmation = 'PENDING_RETURN_CONFIRMATION';
  static const String returnConfirmed = 'RETURN_CONFIRMED';
  static const String closed = 'CLOSED';
  static const String cancelled = 'CANCELLED';

  /// Converts any legacy or variant status string into canonical form
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return pendingManagerReview;
    final clean = raw.trim().toUpperCase().replaceAll(' ', '_');
    switch (clean) {
      case 'PENDING_MANAGER_REVIEW':
      case 'PENDING_MANAGER':
        return pendingManagerReview;
      case 'REJECTED_BY_MANAGER':
      case 'REJECTED_MANAGER':
        return rejectedByManager;
      case 'PENDING_ORGANIZATION_APPROVAL':
      case 'PENDING_ORG_APPROVAL':
      case 'PENDING_ORG':
        return pendingOrgApproval;
      case 'REJECTED_BY_ORGANIZATION':
      case 'REJECTED_BY_ORG':
      case 'REJECTED_ORG':
        return rejectedByOrg;
      case 'APPROVED':
        return approved;
      case 'AWAITING_DISBURSEMENT':
        return awaitingDisbursement;
      case 'DISBURSED':
        return disbursed;
      case 'AWAITING_CONFIRMATION':
      case 'AWAITING_RECEIPT_CONFIRMATION':
        return awaitingReceiptConfirmation;
      case 'RECEIVED':
        return received;
      case 'ACTIVE':
        return active;
      case 'PENDING_EXPENSE_REVIEW':
      case 'SUBMITTED':
        return pendingExpenseReview;
      case 'EXPENSE_APPROVED':
        return expenseApproved;
      case 'EXPENSE_REJECTED':
        return expenseRejected;
      case 'REPLENISHMENT_REQUESTED':
        return replenishmentRequested;
      case 'RECONCILIATION_PENDING':
        return reconciliationPending;
      case 'RECONCILIATION_APPROVED':
        return reconciliationApproved;
      case 'DISCREPANCY_REVIEW':
        return discrepancyReview;
      case 'PENDING_RETURN_CONFIRMATION':
        return pendingReturnConfirmation;
      case 'RETURN_CONFIRMED':
        return returnConfirmed;
      case 'CLOSED':
        return closed;
      case 'CANCELLED':
        return cancelled;
      default:
        return clean;
    }
  }

  /// User-friendly label for UI presentation
  static String getDisplayLabel(String? status) {
    final norm = normalize(status);
    switch (norm) {
      case draft:
        return 'Draft';
      case submitted:
      case pendingManagerReview:
        return 'Pending Manager Review';
      case rejectedByManager:
        return 'Rejected by Manager';
      case pendingOrgApproval:
        return 'Pending HQ Approval';
      case rejectedByOrg:
        return 'Rejected by HQ';
      case approved:
        return 'Approved by HQ';
      case awaitingDisbursement:
        return 'Awaiting Fund Disbursement';
      case disbursed:
      case awaitingReceiptConfirmation:
        return 'Awaiting Receipt Confirmation';
      case received:
      case active:
        return 'Funds Active in Field';
      case pendingExpenseReview:
        return 'Expense Under Review';
      case expenseApproved:
        return 'Expense Approved & Posted';
      case expenseRejected:
        return 'Expense Declined';
      case replenishmentRequested:
        return 'Replenishment Requested';
      case reconciliationPending:
        return 'Reconciliation Pending';
      case reconciliationApproved:
        return 'Reconciliation Approved';
      case discrepancyReview:
        return 'Discrepancy Under Review';
      case pendingReturnConfirmation:
        return 'Return Pending Confirmation';
      case returnConfirmed:
        return 'Cash Return Confirmed';
      case closed:
        return 'Account Closed';
      case cancelled:
        return 'Cancelled';
      default:
        return norm;
    }
  }
}

/// Represents a Site-Based Petty Cash Account (with backward-compatibility for supervisor views).
class PettyCashAccount {
  final String accountId;
  final String orgId;
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final String custodianSupervisorId;
  final String custodianSupervisorName;
  final double totalAllocated;
  final double totalReceived;
  final double totalUsed;
  final double totalSpent;
  final double totalReturned;
  final double availableBalance;
  final double reservedBalance;
  final double postedExpenseBalance;
  final double fundLimit;
  final double configuredMinimumBalance;
  final double lowBalanceThresholdPercent;
  final bool lowBalanceTriggered;
  final double currentCycleAllocated;
  final String currentCycleId;
  final String status;
  final DateTime? lastTransactionAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashAccount({
    required this.accountId,
    required this.orgId,
    this.siteId = '',
    this.siteName = '',
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    this.custodianSupervisorId = '',
    this.custodianSupervisorName = '',
    this.totalAllocated = 0.0,
    this.totalReceived = 0.0,
    this.totalUsed = 0.0,
    this.totalSpent = 0.0,
    this.totalReturned = 0.0,
    this.availableBalance = 0.0,
    this.reservedBalance = 0.0,
    this.postedExpenseBalance = 0.0,
    this.fundLimit = 0.0,
    this.configuredMinimumBalance = 0.0,
    this.lowBalanceThresholdPercent = 10.0,
    this.lowBalanceTriggered = false,
    this.currentCycleAllocated = 0.0,
    this.currentCycleId = '',
    this.status = 'ACTIVE',
    this.lastTransactionAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Spendable Balance = availableBalance - reservedBalance
  double get spendableBalance =>
      (availableBalance - reservedBalance).clamp(0.0, double.infinity);

  /// Stable low-balance threshold amount in currency
  double get lowBalanceThresholdAmount {
    if (configuredMinimumBalance > 0) return configuredMinimumBalance;
    final base = fundLimit > 0
        ? fundLimit
        : (currentCycleAllocated > 0 ? currentCycleAllocated : totalAllocated);
    return base * (lowBalanceThresholdPercent / 100.0);
  }

  /// True when current available balance is at or below the low balance threshold
  bool get isLowBalance =>
      (totalAllocated > 0 || totalReceived > 0) &&
      availableBalance <= lowBalanceThresholdAmount;

  factory PettyCashAccount.fromMap(String id, Map<String, dynamic> data) {
    final alloc = (data['totalAllocated'] is num)
        ? (data['totalAllocated'] as num).toDouble()
        : double.tryParse(data['totalAllocated']?.toString() ?? '') ?? 0.0;

    final received = (data['totalReceived'] is num)
        ? (data['totalReceived'] as num).toDouble()
        : alloc;

    final used = (data['totalUsed'] is num)
        ? (data['totalUsed'] as num).toDouble()
        : double.tryParse(data['totalUsed']?.toString() ?? '') ?? 0.0;

    final spent = (data['totalSpent'] is num)
        ? (data['totalSpent'] as num).toDouble()
        : used;

    final returned = (data['totalReturned'] is num)
        ? (data['totalReturned'] as num).toDouble()
        : 0.0;

    final rawBal = (data['availableBalance'] is num)
        ? (data['availableBalance'] as num).toDouble()
        : double.tryParse(data['availableBalance']?.toString() ?? '') ??
            (alloc - used);

    final avail = rawBal.clamp(0.0, double.infinity);

    final reserved = (data['reservedBalance'] is num)
        ? (data['reservedBalance'] as num).toDouble()
        : 0.0;

    final postedExp = (data['postedExpenseBalance'] is num)
        ? (data['postedExpenseBalance'] as num).toDouble()
        : spent;

    final fLimit = (data['fundLimit'] is num)
        ? (data['fundLimit'] as num).toDouble()
        : alloc;

    final minBal = (data['configuredMinimumBalance'] is num)
        ? (data['configuredMinimumBalance'] as num).toDouble()
        : 0.0;

    final supId = (data['custodianSupervisorId'] ?? data['supervisorId'] ?? id).toString();
    final supName = (data['custodianSupervisorName'] ?? data['supervisorName'] ?? 'Supervisor').toString();

    return PettyCashAccount(
      accountId: id,
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      siteId: (data['siteId'] ?? '').toString(),
      siteName: (data['siteName'] ?? '').toString(),
      supervisorId: supId,
      supervisorName: supName,
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      custodianSupervisorId: supId,
      custodianSupervisorName: supName,
      totalAllocated: alloc > 0 ? alloc : received,
      totalReceived: received > 0 ? received : alloc,
      totalUsed: used > 0 ? used : spent,
      totalSpent: spent > 0 ? spent : used,
      totalReturned: returned,
      availableBalance: avail,
      reservedBalance: reserved,
      postedExpenseBalance: postedExp,
      fundLimit: fLimit,
      configuredMinimumBalance: minBal,
      lowBalanceThresholdPercent: (data['lowBalanceThresholdPercent'] is num)
          ? (data['lowBalanceThresholdPercent'] as num).toDouble()
          : 10.0,
      lowBalanceTriggered: data['lowBalanceTriggered'] == true,
      currentCycleAllocated: (data['currentCycleAllocated'] is num)
          ? (data['currentCycleAllocated'] as num).toDouble()
          : (alloc > 0 ? alloc : received),
      currentCycleId: (data['currentCycleId'] ?? '').toString(),
      status: (data['status'] ?? 'ACTIVE').toString().toUpperCase(),
      lastTransactionAt: _parseDateTime(data['lastTransactionAt']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'orgId': orgId,
      'organizationId': orgId,
      'siteId': siteId,
      'siteName': siteName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      'custodianSupervisorId': custodianSupervisorId.isNotEmpty ? custodianSupervisorId : supervisorId,
      'custodianSupervisorName': custodianSupervisorName.isNotEmpty ? custodianSupervisorName : supervisorName,
      'totalAllocated': totalAllocated,
      'totalReceived': totalReceived,
      'totalUsed': totalUsed,
      'totalSpent': totalSpent,
      'totalReturned': totalReturned,
      'availableBalance': availableBalance,
      'reservedBalance': reservedBalance,
      'postedExpenseBalance': postedExpenseBalance,
      'fundLimit': fundLimit,
      'configuredMinimumBalance': configuredMinimumBalance,
      'lowBalanceThresholdPercent': lowBalanceThresholdPercent,
      'lowBalanceTriggered': lowBalanceTriggered,
      'currentCycleAllocated': currentCycleAllocated,
      'currentCycleId': currentCycleId,
      'status': status,
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

/// Represents a Petty Cash Request with distinct amounts for each stage.
class PettyCashRequest {
  final String requestId;
  final String orgId;
  final String requestType; // 'INITIAL_ALLOCATION', 'REPLENISHMENT', or 'MANUAL_MANAGER'
  final String requestSource; // 'REQUEST_BASED' or 'MANUAL_MANAGER'
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final String? projectId;
  final String? projectName;
  final String? siteId;
  final String? siteName;
  final double requestedAmount;
  final double approvedAmount;
  final double disbursedAmount;
  final double allocatedAmount;
  final double receivedAmount;
  final double totalSpent;
  final double remainingBalance;
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
  final String? disbursedBy;
  final DateTime? disbursedAt;
  final DateTime? receivedAt;
  final String? receivedBySupervisorId;
  final String? receivedBySupervisorName;
  final String? linkedSitePaymentId;
  final String? linkedSitePaymentTitle;
  final List<Map<String, dynamic>> approvalHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashRequest({
    required this.requestId,
    this.orgId = '',
    this.requestType = 'INITIAL_ALLOCATION',
    this.requestSource = 'REQUEST_BASED',
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    this.projectId,
    this.projectName,
    this.siteId,
    this.siteName,
    required this.requestedAmount,
    this.approvedAmount = 0.0,
    this.disbursedAmount = 0.0,
    this.allocatedAmount = 0.0,
    this.receivedAmount = 0.0,
    this.totalSpent = 0.0,
    this.remainingBalance = 0.0,
    required this.reason,
    this.remarks = '',
    required this.status,
    this.statusDisplay = 'Pending Manager Review',
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
    this.disbursedBy,
    this.disbursedAt,
    this.receivedAt,
    this.receivedBySupervisorId,
    this.receivedBySupervisorName,
    this.linkedSitePaymentId,
    this.linkedSitePaymentTitle,
    this.approvalHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isReplenishment => requestType == 'REPLENISHMENT';
  bool get isManualManager =>
      requestSource == 'MANUAL_MANAGER' ||
      requestType == 'MANUAL_MANAGER' ||
      requestType == 'MANUAL_ALLOCATION';
  bool get isRequestBased => !isManualManager;
  bool get isAwaitingDisbursement =>
      status == PettyCashStatus.awaitingDisbursement ||
      (status == PettyCashStatus.approved && disbursedAmount == 0);
  bool get isAwaitingConfirmation =>
      status == PettyCashStatus.awaitingReceiptConfirmation ||
      status == 'awaiting_confirmation' ||
      status == PettyCashStatus.disbursed;
  bool get isReceived =>
      status == PettyCashStatus.received ||
      status == PettyCashStatus.active ||
      status == 'received' ||
      status == 'approved' ||
      receivedAt != null;
  bool get isSitePaymentLinked =>
      linkedSitePaymentId != null && linkedSitePaymentId!.isNotEmpty;

  /// Effective active remaining balance for this specific site allocation
  double get effectiveRemainingBalance {
    if (!isReceived) return 0.0;
    if (remainingBalance > 0 || totalSpent > 0) return remainingBalance;
    final effectiveAlloc = receivedAmount > 0
        ? receivedAmount
        : (disbursedAmount > 0
            ? disbursedAmount
            : (approvedAmount > 0
                ? approvedAmount
                : (allocatedAmount > 0 ? allocatedAmount : requestedAmount)));
    return (effectiveAlloc - totalSpent).clamp(0.0, double.infinity);
  }

  factory PettyCashRequest.fromMap(String id, Map<String, dynamic> data) {
    final reqType = (data['requestType'] ?? 'INITIAL_ALLOCATION').toString();
    final reqSrc = (data['requestSource'] ??
            (reqType == 'MANUAL_MANAGER' || reqType == 'MANUAL_ALLOCATION'
                ? 'MANUAL_MANAGER'
                : 'REQUEST_BASED'))
        .toString();

    final reqAmt = (data['requestedAmount'] is num)
        ? (data['requestedAmount'] as num).toDouble()
        : double.tryParse(data['requestedAmount']?.toString() ?? '') ?? 0.0;
    final appAmt = (data['approvedAmount'] is num)
        ? (data['approvedAmount'] as num).toDouble()
        : double.tryParse(data['approvedAmount']?.toString() ?? '') ?? 0.0;
    final disbAmt = (data['disbursedAmount'] is num)
        ? (data['disbursedAmount'] as num).toDouble()
        : double.tryParse(data['disbursedAmount']?.toString() ?? '') ??
            ((data['allocatedAmount'] is num) ? (data['allocatedAmount'] as num).toDouble() : 0.0);
    final allocAmt = (data['allocatedAmount'] is num)
        ? (data['allocatedAmount'] as num).toDouble()
        : disbAmt;
    final recAmt = (data['receivedAmount'] is num)
        ? (data['receivedAmount'] as num).toDouble()
        : (data['receivedAt'] != null ? (disbAmt > 0 ? disbAmt : (appAmt > 0 ? appAmt : reqAmt)) : 0.0);

    final spent = (data['totalSpent'] is num)
        ? (data['totalSpent'] as num).toDouble()
        : double.tryParse(data['totalSpent']?.toString() ?? '') ?? 0.0;

    final effectiveAlloc = recAmt > 0
        ? recAmt
        : (disbAmt > 0 ? disbAmt : (appAmt > 0 ? appAmt : (allocAmt > 0 ? allocAmt : reqAmt)));
    final rawRem = (data['remainingBalance'] is num)
        ? (data['remainingBalance'] as num).toDouble()
        : (effectiveAlloc - spent).clamp(0.0, double.infinity);

    final rawStatus = data['status']?.toString();
    final normStatus = PettyCashStatus.normalize(rawStatus);

    return PettyCashRequest(
      requestId: id,
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      requestType: reqType,
      requestSource: reqSrc,
      supervisorId: (data['supervisorId'] ?? '').toString(),
      supervisorName: (data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      projectId: data['projectId']?.toString(),
      projectName: data['projectName']?.toString(),
      siteId: data['siteId']?.toString(),
      siteName: data['siteName']?.toString(),
      requestedAmount: reqAmt,
      approvedAmount: appAmt,
      disbursedAmount: disbAmt,
      allocatedAmount: allocAmt,
      receivedAmount: recAmt,
      totalSpent: spent,
      remainingBalance: rawRem,
      reason: (data['reason'] ?? '').toString(),
      remarks: (data['remarks'] ?? '').toString(),
      status: normStatus,
      statusDisplay: PettyCashStatus.getDisplayLabel(normStatus),
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
      disbursedBy: data['disbursedBy']?.toString() ?? data['allocatedBy']?.toString(),
      disbursedAt: _parseDateTime(data['disbursedAt']) ?? _parseDateTime(data['allocatedAt']),
      receivedAt: _parseDateTime(data['receivedAt']),
      receivedBySupervisorId: data['receivedBySupervisorId']?.toString(),
      receivedBySupervisorName: data['receivedBySupervisorName']?.toString(),
      linkedSitePaymentId: data['linkedSitePaymentId']?.toString(),
      linkedSitePaymentTitle: data['linkedSitePaymentTitle']?.toString(),
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
      'organizationId': orgId,
      'requestType': requestType,
      'requestSource': requestSource,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
      if (siteId != null) 'siteId': siteId,
      if (siteName != null) 'siteName': siteName,
      'requestedAmount': requestedAmount,
      'approvedAmount': approvedAmount,
      'disbursedAmount': disbursedAmount,
      'allocatedAmount': allocatedAmount,
      'receivedAmount': receivedAmount,
      'totalSpent': totalSpent,
      'remainingBalance': remainingBalance,
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
      if (disbursedBy != null) 'disbursedBy': disbursedBy,
      if (disbursedAt != null) 'disbursedAt': Timestamp.fromDate(disbursedAt!),
      if (receivedAt != null) 'receivedAt': Timestamp.fromDate(receivedAt!),
      if (receivedBySupervisorId != null)
        'receivedBySupervisorId': receivedBySupervisorId,
      if (receivedBySupervisorName != null)
        'receivedBySupervisorName': receivedBySupervisorName,
      if (linkedSitePaymentId != null)
        'linkedSitePaymentId': linkedSitePaymentId,
      if (linkedSitePaymentTitle != null)
        'linkedSitePaymentTitle': linkedSitePaymentTitle,
      'approvalHistory': approvalHistory,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents a Petty Cash Expense awaiting Manager review / approval.
class PettyCashExpense {
  final String expenseId;
  final String idempotencyKey;
  final String accountId;
  final String orgId;
  final String siteId;
  final String siteName;
  final String? pettyCashId;
  final String submittedBy;
  final String submittedByName;
  final String managerId;
  final String managerName;
  final double amount;
  final String category;
  final String description;
  final String? vendorName;
  final String? receiptUrl;
  final String? receiptFileName;
  final DateTime? receiptUploadedAt;
  final bool receiptRequired;
  final String? noReceiptReason;
  final bool receiptVerified;
  final String? receiptVerifiedBy;
  final DateTime? receiptVerifiedAt;
  final String status; // 'PENDING_EXPENSE_REVIEW', 'EXPENSE_APPROVED', 'EXPENSE_REJECTED'
  final String? reviewedBy;
  final String? reviewRemarks;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final bool postedToLedger;
  final String? transactionId;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashExpense({
    required this.expenseId,
    required this.idempotencyKey,
    required this.accountId,
    required this.orgId,
    required this.siteId,
    required this.siteName,
    this.pettyCashId,
    required this.submittedBy,
    required this.submittedByName,
    this.managerId = '',
    this.managerName = '',
    required this.amount,
    required this.category,
    required this.description,
    this.vendorName,
    this.receiptUrl,
    this.receiptFileName,
    this.receiptUploadedAt,
    this.receiptRequired = true,
    this.noReceiptReason,
    this.receiptVerified = false,
    this.receiptVerifiedBy,
    this.receiptVerifiedAt,
    this.status = PettyCashStatus.pendingExpenseReview,
    this.reviewedBy,
    this.reviewRemarks,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.postedToLedger = false,
    this.transactionId,
    required this.transactionDate,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => status == PettyCashStatus.expenseApproved;
  bool get isPending => status == PettyCashStatus.pendingExpenseReview || status == PettyCashStatus.submitted;
  bool get isRejected => status == PettyCashStatus.expenseRejected;

  String get supervisorName => submittedByName;
  String get supervisorId => submittedBy;
  String get expenseCategory => category;
  bool get isSiteExpense => siteId.isNotEmpty;

  factory PettyCashExpense.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashExpense(
      expenseId: id,
      idempotencyKey: (data['idempotencyKey'] ?? id).toString(),
      accountId: (data['accountId'] ?? '').toString(),
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      siteId: (data['siteId'] ?? '').toString(),
      siteName: (data['siteName'] ?? '').toString(),
      pettyCashId: data['pettyCashId']?.toString(),
      submittedBy: (data['submittedBy'] ?? data['supervisorId'] ?? '').toString(),
      submittedByName: (data['submittedByName'] ?? data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      amount: (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : double.tryParse(data['amount']?.toString() ?? '') ?? 0.0,
      category: (data['category'] ?? data['expenseCategory'] ?? 'Other').toString(),
      description: (data['description'] ?? '').toString(),
      vendorName: (data['vendorName'] ?? data['vendor'] ?? data['payee'])?.toString(),
      receiptUrl: (data['receiptUrl'] ?? data['attachmentUrl'])?.toString(),
      receiptFileName: data['receiptFileName']?.toString(),
      receiptUploadedAt: _parseDateTime(data['receiptUploadedAt']),
      receiptRequired: data['receiptRequired'] != false,
      noReceiptReason: data['noReceiptReason']?.toString(),
      receiptVerified: data['receiptVerified'] == true,
      receiptVerifiedBy: data['receiptVerifiedBy']?.toString(),
      receiptVerifiedAt: _parseDateTime(data['receiptVerifiedAt']),
      status: PettyCashStatus.normalize(data['status']?.toString()),
      reviewedBy: data['reviewedBy']?.toString(),
      reviewRemarks: data['reviewRemarks']?.toString(),
      approvedAt: _parseDateTime(data['approvedAt']),
      rejectedAt: _parseDateTime(data['rejectedAt']),
      rejectionReason: data['rejectionReason']?.toString(),
      postedToLedger: data['postedToLedger'] == true,
      transactionId: data['transactionId']?.toString(),
      transactionDate: _parseDateTime(data['transactionDate']) ?? DateTime.now(),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'idempotencyKey': idempotencyKey,
      'accountId': accountId,
      'orgId': orgId,
      'organizationId': orgId,
      'siteId': siteId,
      'siteName': siteName,
      if (pettyCashId != null) 'pettyCashId': pettyCashId,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'managerId': managerId,
      'managerName': managerName,
      'amount': amount,
      'category': category,
      'description': description,
      if (vendorName != null) 'vendorName': vendorName,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (receiptFileName != null) 'receiptFileName': receiptFileName,
      if (receiptUploadedAt != null)
        'receiptUploadedAt': Timestamp.fromDate(receiptUploadedAt!),
      'receiptRequired': receiptRequired,
      if (noReceiptReason != null) 'noReceiptReason': noReceiptReason,
      'receiptVerified': receiptVerified,
      if (receiptVerifiedBy != null) 'receiptVerifiedBy': receiptVerifiedBy,
      if (receiptVerifiedAt != null)
        'receiptVerifiedAt': Timestamp.fromDate(receiptVerifiedAt!),
      'status': status,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewRemarks != null) 'reviewRemarks': reviewRemarks,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'postedToLedger': postedToLedger,
      if (transactionId != null) 'transactionId': transactionId,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents an immutable Ledger Transaction entry.
class PettyCashTransaction {
  final String transactionId;
  final String idempotencyKey;
  final String? pettyCashId;
  final String? referenceId; // Expense ID, Request ID, or Return ID
  final String accountId;
  final String orgId;
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final String? projectId;
  final String? projectName;
  final String? siteId;
  final String? siteName;
  final String? vendorName;
  final String? linkedSitePaymentId;
  final bool isSiteExpense;
  final String transactionType; // 'INITIAL_FUND', 'CASH_DISBURSED', 'EXPENSE_APPROVED', 'REPLENISHMENT', 'CASH_RETURN', 'ADJUSTMENT'
  final String expenseCategory;
  final String description;
  final double amount;
  final double previousBalance;
  final double newBalance;
  final String remarks;
  final String? attachmentUrl;
  final String status; // 'POSTED'
  final DateTime transactionDate;
  final String createdBy;
  final String createdRole;
  final DateTime? createdAt;

  const PettyCashTransaction({
    required this.transactionId,
    required this.idempotencyKey,
    this.pettyCashId,
    this.referenceId,
    required this.accountId,
    required this.orgId,
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    this.projectId,
    this.projectName,
    this.siteId,
    this.siteName,
    this.vendorName,
    this.linkedSitePaymentId,
    this.isSiteExpense = false,
    required this.transactionType,
    this.expenseCategory = 'Other',
    required this.description,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    this.remarks = '',
    this.attachmentUrl,
    this.status = 'POSTED',
    required this.transactionDate,
    required this.createdBy,
    required this.createdRole,
    this.createdAt,
  });

  bool get isExpense =>
      transactionType == 'EXPENSE_APPROVED' || transactionType == 'EXPENSE';
  bool get isAllocation =>
      transactionType == 'INITIAL_FUND' ||
      transactionType == 'CASH_DISBURSED' ||
      transactionType == 'ALLOCATION' ||
      transactionType == 'REPLENISHMENT';
  bool get isReturn => transactionType == 'CASH_RETURN';
  bool get isOtherExpense =>
      expenseCategory.toLowerCase() == 'other' ||
      expenseCategory.toLowerCase() == 'miscellaneous';

  factory PettyCashTransaction.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashTransaction(
      transactionId: id,
      idempotencyKey: (data['idempotencyKey'] ?? id).toString(),
      pettyCashId: (data['pettyCashId'] ?? data['requestId'])?.toString(),
      referenceId: (data['referenceId'] ?? data['expenseId'] ?? data['pettyCashId'])?.toString(),
      accountId: (data['accountId'] ?? '').toString(),
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      supervisorId: (data['supervisorId'] ?? '').toString(),
      supervisorName: (data['supervisorName'] ?? 'Supervisor').toString(),
      managerId: (data['managerId'] ?? '').toString(),
      managerName: (data['managerName'] ?? '').toString(),
      projectId: data['projectId']?.toString(),
      projectName: data['projectName']?.toString(),
      siteId: data['siteId']?.toString(),
      siteName: data['siteName']?.toString(),
      vendorName: (data['vendorName'] ?? data['vendor'] ?? data['payee'])?.toString(),
      linkedSitePaymentId: data['linkedSitePaymentId']?.toString(),
      isSiteExpense: data['isSiteExpense'] == true || (data['siteId']?.toString().isNotEmpty == true),
      transactionType: (data['transactionType'] ?? 'EXPENSE_APPROVED').toString(),
      expenseCategory: (data['expenseCategory'] ?? data['category'] ?? 'Other').toString(),
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
      attachmentUrl: (data['attachmentUrl'] ?? data['receiptUrl'])?.toString(),
      status: (data['status'] ?? 'POSTED').toString(),
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
      if (pettyCashId != null) 'pettyCashId': pettyCashId,
      if (referenceId != null) 'referenceId': referenceId,
      'accountId': accountId,
      'orgId': orgId,
      'organizationId': orgId,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'managerId': managerId,
      'managerName': managerName,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
      'siteId': siteId ?? '',
      'siteName': siteName ?? '',
      if (vendorName != null) 'vendorName': vendorName,
      if (linkedSitePaymentId != null)
        'linkedSitePaymentId': linkedSitePaymentId,
      'isSiteExpense': isSiteExpense,
      'transactionType': transactionType,
      'expenseCategory': expenseCategory,
      'description': description,
      'amount': amount,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'remarks': remarks,
      'attachmentUrl': attachmentUrl ?? '',
      'status': status,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdBy': createdBy,
      'createdRole': createdRole,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// Represents a Site Cash Reconciliation entry.
class PettyCashReconciliation {
  final String reconciliationId;
  final String accountId;
  final String orgId;
  final String siteId;
  final String siteName;
  final double expectedCash;
  final double physicalCash;
  final double difference;
  final String? differenceReason;
  final String? supportingAttachment;
  final String submittedBy;
  final String submittedByName;
  final String? reviewedBy;
  final String? reviewRemarks;
  final DateTime? reviewedAt;
  final String status; // 'RECONCILIATION_PENDING', 'RECONCILIATION_APPROVED', 'DISCREPANCY_REVIEW'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PettyCashReconciliation({
    required this.reconciliationId,
    required this.accountId,
    required this.orgId,
    required this.siteId,
    required this.siteName,
    required this.expectedCash,
    required this.physicalCash,
    required this.difference,
    this.differenceReason,
    this.supportingAttachment,
    required this.submittedBy,
    required this.submittedByName,
    this.reviewedBy,
    this.reviewRemarks,
    this.reviewedAt,
    this.status = PettyCashStatus.reconciliationPending,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasDiscrepancy => difference.abs() > 0.01;
  String get supervisorName => submittedByName;
  String get supervisorId => submittedBy;

  factory PettyCashReconciliation.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashReconciliation(
      reconciliationId: id,
      accountId: (data['accountId'] ?? '').toString(),
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      siteId: (data['siteId'] ?? '').toString(),
      siteName: (data['siteName'] ?? '').toString(),
      expectedCash: (data['expectedCash'] is num)
          ? (data['expectedCash'] as num).toDouble()
          : double.tryParse(data['expectedCash']?.toString() ?? '') ?? 0.0,
      physicalCash: (data['physicalCash'] is num)
          ? (data['physicalCash'] as num).toDouble()
          : double.tryParse(data['physicalCash']?.toString() ?? '') ?? 0.0,
      difference: (data['difference'] is num)
          ? (data['difference'] as num).toDouble()
          : double.tryParse(data['difference']?.toString() ?? '') ?? 0.0,
      differenceReason: data['differenceReason']?.toString(),
      supportingAttachment: data['supportingAttachment']?.toString(),
      submittedBy: (data['submittedBy'] ?? '').toString(),
      submittedByName: (data['submittedByName'] ?? 'Supervisor').toString(),
      reviewedBy: data['reviewedBy']?.toString(),
      reviewRemarks: data['reviewRemarks']?.toString(),
      reviewedAt: _parseDateTime(data['reviewedAt']),
      status: PettyCashStatus.normalize(data['status']?.toString()),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reconciliationId': reconciliationId,
      'accountId': accountId,
      'orgId': orgId,
      'organizationId': orgId,
      'siteId': siteId,
      'siteName': siteName,
      'expectedCash': expectedCash,
      'physicalCash': physicalCash,
      'difference': difference,
      if (differenceReason != null) 'differenceReason': differenceReason,
      if (supportingAttachment != null)
        'supportingAttachment': supportingAttachment,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewRemarks != null) 'reviewRemarks': reviewRemarks,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents a Petty Cash Return entry.
class PettyCashReturn {
  final String returnId;
  final String accountId;
  final String orgId;
  final String siteId;
  final String siteName;
  final double returnAmount;
  final String returnedBy;
  final String returnedByName;
  final String? receivedBy;
  final String? receivedByName;
  final DateTime returnDate;
  final String? proofUrl;
  final String reason;
  final String status; // 'PENDING_RETURN_CONFIRMATION', 'RETURN_CONFIRMED', 'RETURN_REJECTED'
  final String? transactionId;
  final DateTime? createdAt;

  const PettyCashReturn({
    required this.returnId,
    required this.accountId,
    required this.orgId,
    required this.siteId,
    required this.siteName,
    required this.returnAmount,
    required this.returnedBy,
    required this.returnedByName,
    this.receivedBy,
    this.receivedByName,
    required this.returnDate,
    this.proofUrl,
    required this.reason,
    this.status = PettyCashStatus.pendingReturnConfirmation,
    this.transactionId,
    this.createdAt,
  });

  String get supervisorName => returnedByName;
  String get supervisorId => returnedBy;

  factory PettyCashReturn.fromMap(String id, Map<String, dynamic> data) {
    return PettyCashReturn(
      returnId: id,
      accountId: (data['accountId'] ?? '').toString(),
      orgId: (data['orgId'] ?? data['organizationId'] ?? '').toString(),
      siteId: (data['siteId'] ?? '').toString(),
      siteName: (data['siteName'] ?? '').toString(),
      returnAmount: (data['returnAmount'] is num)
          ? (data['returnAmount'] as num).toDouble()
          : double.tryParse(data['returnAmount']?.toString() ?? '') ?? 0.0,
      returnedBy: (data['returnedBy'] ?? '').toString(),
      returnedByName: (data['returnedByName'] ?? 'Supervisor').toString(),
      receivedBy: data['receivedBy']?.toString(),
      receivedByName: data['receivedByName']?.toString(),
      returnDate: _parseDateTime(data['returnDate']) ?? DateTime.now(),
      proofUrl: data['proofUrl']?.toString(),
      reason: (data['reason'] ?? '').toString(),
      status: PettyCashStatus.normalize(data['status']?.toString()),
      transactionId: data['transactionId']?.toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'returnId': returnId,
      'accountId': accountId,
      'orgId': orgId,
      'organizationId': orgId,
      'siteId': siteId,
      'siteName': siteName,
      'returnAmount': returnAmount,
      'returnedBy': returnedBy,
      'returnedByName': returnedByName,
      if (receivedBy != null) 'receivedBy': receivedBy,
      if (receivedByName != null) 'receivedByName': receivedByName,
      'returnDate': Timestamp.fromDate(returnDate),
      if (proofUrl != null) 'proofUrl': proofUrl,
      'reason': reason,
      'status': status,
      if (transactionId != null) 'transactionId': transactionId,
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
  final String entityType; // 'ACCOUNT', 'REQUEST', 'EXPENSE', 'TRANSACTION', 'RECONCILIATION', 'RETURN'
  final String entityId;
  final String actorId;
  final String actorName;
  final String actorRole; // 'Supervisor', 'Manager', 'Organization', 'System'
  final String? organizationId;
  final String? siteId;
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
    this.organizationId,
    this.siteId,
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
      organizationId: data['organizationId']?.toString() ?? data['orgId']?.toString(),
      siteId: data['siteId']?.toString(),
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
      if (organizationId != null) 'organizationId': organizationId,
      if (siteId != null) 'siteId': siteId,
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

/// Represents a site-wise aggregate summary of petty cash allocations, expenses, and remaining balances.
class SitePettyCashSummary {
  final String siteId;
  final String siteName;
  final String? projectId;
  final String? projectName;
  final String supervisorId;
  final String supervisorName;
  final String managerId;
  final String managerName;
  final double totalReceived; // Sum of confirmed received/approved allocations for this site
  final double totalExpenses; // Sum of all posted/approved expenses for this site
  final double otherExpenses; // Sum of Other/Miscellaneous expenses for this site
  final double remainingBalance; // totalReceived - totalExpenses
  final int transactionCount;
  final int allocationCount;
  final DateTime? lastActivityAt;
  final String status; // 'Active', 'Low Balance', 'Depleted', 'Pending Receipt'
  final List<PettyCashRequest> allocations;
  final List<PettyCashTransaction> transactions;

  const SitePettyCashSummary({
    required this.siteId,
    required this.siteName,
    this.projectId,
    this.projectName,
    required this.supervisorId,
    required this.supervisorName,
    this.managerId = '',
    this.managerName = '',
    required this.totalReceived,
    required this.totalExpenses,
    required this.otherExpenses,
    required this.remainingBalance,
    this.transactionCount = 0,
    this.allocationCount = 0,
    this.lastActivityAt,
    required this.status,
    this.allocations = const [],
    this.transactions = const [],
  });

  double get utilizationPercent =>
      totalReceived > 0 ? ((totalExpenses / totalReceived) * 100.0).clamp(0.0, 100.0) : 0.0;

  bool get isLowBalance =>
      totalReceived > 0 && remainingBalance <= (totalReceived * 0.1);
}
