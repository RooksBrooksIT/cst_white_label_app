import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_models.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'approval_workflow_service.dart';

class PettyCashService {
  static final PettyCashService _instance = PettyCashService._internal();
  factory PettyCashService() => _instance;
  PettyCashService._internal();

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static String formatCurrency(num amount) {
    return _currencyFormat.format(amount);
  }

  // ---------------------------------------------------------------------------
  // 1. ACCOUNT STREAM & RETRIEVAL
  // ---------------------------------------------------------------------------

  /// Streams the real-time account data for a specific supervisor.
  Stream<PettyCashAccount?> streamAccount(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashAccounts.doc(cleanId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return PettyCashAccount.fromMap(doc.id, doc.data()!);
    });
  }

  /// Streams all petty cash accounts for Manager / Org dashboards.
  Stream<List<PettyCashAccount>> streamAllAccounts() {
    return FirestoreService.pettyCashAccounts.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PettyCashAccount.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Fetches or initializes an account document for a supervisor.
  Future<PettyCashAccount> getOrCreateAccount({
    required String supervisorId,
    required String supervisorName,
    String? managerId,
    String? managerName,
  }) async {
    final cleanId = supervisorId.trim().toLowerCase();
    final docRef = FirestoreService.pettyCashAccounts.doc(cleanId);
    final snap = await docRef.get();

    if (snap.exists && snap.data() != null) {
      return PettyCashAccount.fromMap(snap.id, snap.data()!);
    }

    final newAccount = PettyCashAccount(
      accountId: cleanId,
      orgId: FirestoreService.currentOrgId,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: managerId ?? '',
      managerName: managerName ?? '',
      totalAllocated: 0.0,
      totalUsed: 0.0,
      availableBalance: 0.0,
      lowBalanceThresholdPercent: 10.0,
      lowBalanceTriggered: false,
      currentCycleAllocated: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newAccount.toMap(), SetOptions(merge: true));
    return newAccount;
  }

  // ---------------------------------------------------------------------------
  // 2. ASSIGNED SITES RESOLUTION
  // ---------------------------------------------------------------------------

  /// Fetches sites assigned to the supervisor from `siteSupervisorMap` & `Site`.
  Future<List<Map<String, String>>> fetchSupervisorAssignedSites({
    required String supervisorId,
    required String supervisorName,
  }) async {
    final List<Map<String, String>> assignedSites = [];
    final Set<String> seenSiteIds = {};

    try {
      final cleanSupId = supervisorId.trim().toLowerCase();
      final cleanSupName = supervisorName.trim().toLowerCase();

      final mapSnap = await FirestoreService.siteSupervisorMap.get();
      for (final doc in mapSnap.docs) {
        final data = doc.data();
        final sSupId = (data['Supervisor ID'] ?? data['supervisorId'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final sSupName = (data['supervisor'] ?? data['supervisorName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final isMatch = (cleanSupId.isNotEmpty && sSupId == cleanSupId) ||
            (cleanSupName.isNotEmpty && sSupName == cleanSupName) ||
            cleanSupId.isEmpty;

        if (isMatch) {
          final sId = (data['siteId'] ?? data['site'] ?? data['site_id'] ?? doc.id)
              .toString()
              .trim();
          final sName = (data['siteName'] ?? data['site'] ?? sId).toString().trim();

          if (sId.isNotEmpty && !seenSiteIds.contains(sId.toLowerCase())) {
            seenSiteIds.add(sId.toLowerCase());
            assignedSites.add({'siteId': sId, 'siteName': sName});
          }
        }
      }

      // Fallback: If empty, load active sites from `Site` collection
      if (assignedSites.isEmpty) {
        final siteSnap = await FirestoreService.sites.get();
        for (final doc in siteSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? doc.id).toString().trim();
          final sName = (data['siteName'] ?? data['name'] ?? sId).toString().trim();
          if (sId.isNotEmpty && !seenSiteIds.contains(sId.toLowerCase())) {
            seenSiteIds.add(sId.toLowerCase());
            assignedSites.add({'siteId': sId, 'siteName': sName});
          }
        }
      }
    } catch (e) {
      debugPrint('PettyCashService: Error fetching assigned sites: $e');
    }

    return assignedSites;
  }

  // ---------------------------------------------------------------------------
  // 3. REQUEST LIFECYCLE: STAGE 1 (SUBMIT)
  // ---------------------------------------------------------------------------

  /// Supervisor submits a new Petty Cash Request or Replenishment Request.
  Future<String> submitRequest({
    required String supervisorId,
    required String supervisorName,
    required double requestedAmount,
    required String reason,
    String? remarks,
    String? managerId,
    String? managerName,
    bool isReplenishment = false,
  }) async {
    if (requestedAmount <= 0) {
      throw Exception('Requested amount must be greater than zero.');
    }

    final orgId = FirestoreService.currentOrgId;

    // Resolve Manager info if not supplied
    String resolvedManagerId = (managerId ?? '').trim();
    String resolvedManagerName = (managerName ?? '').trim();

    if (resolvedManagerId.isEmpty || resolvedManagerName.isEmpty) {
      try {
        final cleanSupId = supervisorId.trim().toLowerCase();
        final cleanSupName = supervisorName.trim().toLowerCase();
        final mapSnap = await FirestoreService.siteSupervisorMap.get();
        for (final doc in mapSnap.docs) {
          final data = doc.data();
          final sSupId = (data['Supervisor ID'] ?? data['supervisorId'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final sSupName = (data['supervisor'] ?? data['supervisorName'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if ((cleanSupId.isNotEmpty && sSupId == cleanSupId) ||
              (cleanSupName.isNotEmpty && sSupName == cleanSupName)) {
            if (resolvedManagerId.isEmpty) {
              resolvedManagerId = (data['managerId'] ?? data['manager_id'] ?? '')
                  .toString()
                  .trim();
            }
            if (resolvedManagerName.isEmpty) {
              resolvedManagerName =
                  (data['manager'] ?? data['managerName'] ?? '').toString().trim();
            }
            if (resolvedManagerId.isNotEmpty) break;
          }
        }
      } catch (_) {}
    }

    final account = await getOrCreateAccount(
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: resolvedManagerId,
      managerName: resolvedManagerName,
    );

    final reqDocId =
        'PCR_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';

    final requestType = isReplenishment ? 'REPLENISHMENT' : 'INITIAL_ALLOCATION';

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: isReplenishment ? '1. Replenishment Request' : '1. Supervisor Submission',
      action: isReplenishment ? 'Replenishment Requested' : 'Petty Cash Requested',
      actorRole: 'Supervisor',
      actorName: supervisorName,
      actorId: supervisorId,
      remarks: reason,
    );

    final now = DateTime.now();
    final request = PettyCashRequest(
      requestId: reqDocId,
      orgId: orgId,
      requestType: requestType,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: resolvedManagerId.isNotEmpty ? resolvedManagerId : account.managerId,
      managerName: resolvedManagerName.isNotEmpty ? resolvedManagerName : account.managerName,
      requestedAmount: requestedAmount,
      approvedAmount: 0.0,
      allocatedAmount: 0.0,
      reason: reason,
      remarks: remarks ?? '',
      status: ApprovalWorkflowService.statusPendingManagerReview,
      statusDisplay: 'Pending Manager Review',
      currentStep: 1,
      currentBalanceAtRequest: account.availableBalance,
      totalAllocatedAtRequest: account.totalAllocated,
      totalUsedAtRequest: account.totalUsed,
      approvalHistory: [auditEntry],
      createdAt: now,
      updatedAt: now,
    );

    final requestMap = request.toMap();
    requestMap['createdAt'] = Timestamp.fromDate(now);
    requestMap['updatedAt'] = Timestamp.fromDate(now);

    await FirestoreService.pettyCashRequests.doc(reqDocId).set(requestMap);

    // Write immutable audit log
    await _writeAuditLog(
      action: isReplenishment ? 'REPLENISHMENT_REQUESTED' : 'REQUEST_CREATED',
      entityType: 'REQUEST',
      entityId: reqDocId,
      actorId: supervisorId,
      actorName: supervisorName,
      actorRole: 'Supervisor',
      newState: request.toMap(),
    );

    // Notify Manager(s) in real time
    final formattedAmt = formatCurrency(requestedAmount);
    final title = isReplenishment
        ? '🔄 Petty Cash Replenishment Request'
        : '💰 New Petty Cash Request';
    final body =
        '$supervisorName requested $formattedAmt for petty cash. Reason: $reason';

    await NotificationService.notifyManager(
      title: title,
      body: body,
      requestType: 'petty_cash',
      requestId: reqDocId,
      docId: reqDocId,
      status: ApprovalWorkflowService.statusPendingManagerReview,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: reason,
      extraData: {
        'requestedAmount': requestedAmount,
        'requestType': requestType,
        'supervisorId': supervisorId,
      },
    );

    return reqDocId;
  }

  // ---------------------------------------------------------------------------
  // 4. REQUEST LIFECYCLE: STAGE 2 (MANAGER REVIEW & FORWARD / REJECT)
  // ---------------------------------------------------------------------------

  /// Manager verifies the request and forwards it to Organization HQ.
  Future<void> managerForwardToOrg({
    required String requestId,
    required String managerName,
    String? managerId,
    required String remarks,
  }) async {
    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final data = snap.data()!;
    final req = PettyCashRequest.fromMap(requestId, data);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '2. Manager Review',
      action: 'Verified & Forwarded to HQ',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: remarks.isNotEmpty ? remarks : 'Verified and forwarded for HQ approval.',
    );

    final updates = {
      'status': ApprovalWorkflowService.statusPendingOrgApproval,
      'statusDisplay': 'Pending Organization Approval',
      'currentStep': 2,
      'managerReviewedBy': managerName,
      'managerId': managerId ?? req.managerId,
      'managerName': managerName,
      'managerReviewRemarks': remarks,
      'managerReviewedAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'REQUEST_FORWARDED',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: managerId ?? '',
      actorName: managerName,
      actorRole: 'Manager',
      previousState: {'status': req.status},
      newState: updates,
    );

    // Notify Organization in real time
    final formattedAmt = formatCurrency(req.requestedAmount);
    await NotificationService.notifyOrganisation(
      title: '🏢 Petty Cash Request Awaiting Authorization',
      body:
          'Manager $managerName verified $formattedAmt petty cash request for ${req.supervisorName}. Remarks: $remarks',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusPendingOrgApproval,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: remarks,
      data: {
        'requestedAmount': req.requestedAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
      },
    );
  }

  /// Manager rejects the request during initial review.
  Future<void> managerRejectRequest({
    required String requestId,
    required String managerName,
    String? managerId,
    required String reason,
  }) async {
    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '2. Manager Review',
      action: 'Rejected by Manager',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: reason,
    );

    final updates = {
      'status': ApprovalWorkflowService.statusRejectedByManager,
      'statusDisplay': 'Rejected by Manager',
      'currentStep': -1,
      'rejectionReason': reason,
      'managerReviewedBy': managerName,
      'managerReviewedAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'REQUEST_REJECTED_MANAGER',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: managerId ?? '',
      actorName: managerName,
      actorRole: 'Manager',
      previousState: {'status': req.status},
      newState: updates,
    );

    // Notify Supervisor
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '❌ Petty Cash Request Declined',
      body:
          'Your petty cash request for ${formatCurrency(req.requestedAmount)} was declined by Manager $managerName. Reason: $reason',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusRejectedByManager,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: reason,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. REQUEST LIFECYCLE: STAGE 3 (ORGANIZATION APPROVAL / REJECTION)
  // ---------------------------------------------------------------------------

  /// Organization authorizes the request with an approved amount.
  Future<void> orgApproveRequest({
    required String requestId,
    required String orgUserName,
    String? orgUserId,
    required double approvedAmount,
    required String remarks,
  }) async {
    if (approvedAmount <= 0) {
      throw Exception('Approved amount must be greater than zero.');
    }

    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Authorized by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks:
          'Approved ${formatCurrency(approvedAmount)}. Remarks: ${remarks.isNotEmpty ? remarks : 'Approved by HQ.'}',
    );

    final updates = {
      'status': ApprovalWorkflowService.statusPendingManagerClearance,
      'statusDisplay': 'Pending Manager Allocation',
      'currentStep': 3,
      'approvedAmount': approvedAmount,
      'orgApprovedBy': orgUserName,
      'orgApprovalRemarks': remarks,
      'orgApprovedAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'ORGANIZATION_APPROVED',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: orgUserId ?? '',
      actorName: orgUserName,
      actorRole: 'Organization',
      previousState: {'status': req.status},
      newState: updates,
    );

    // Notify Manager that request is authorized and ready for allocation
    await NotificationService.notifyManager(
      title: '✅ Petty Cash Authorized by HQ',
      body:
          'HQ authorized ${formatCurrency(approvedAmount)} for ${req.supervisorName}. Manager clearance required to allocate funds.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusPendingManagerClearance,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
      extraData: {
        'approvedAmount': approvedAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
      },
    );
  }

  /// Organization rejects the request with a mandatory reason.
  Future<void> orgRejectRequest({
    required String requestId,
    required String orgUserName,
    String? orgUserId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Rejected by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks: reason,
    );

    final updates = {
      'status': ApprovalWorkflowService.statusRejectedByOrg,
      'statusDisplay': 'Rejected by Organization',
      'currentStep': -1,
      'orgRejectedBy': orgUserName,
      'rejectionReason': reason,
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'ORGANIZATION_REJECTED',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: orgUserId ?? '',
      actorName: orgUserName,
      actorRole: 'Organization',
      previousState: {'status': req.status},
      newState: updates,
    );

    // Notify Manager
    await NotificationService.notifyManager(
      title: '❌ Petty Cash Rejected by HQ',
      body:
          'Petty cash request #$requestId for ${req.supervisorName} was rejected by HQ. Reason: $reason',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusRejectedByOrg,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: reason,
    );

    // Notify Supervisor
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '❌ Petty Cash Rejected by HQ',
      body:
          'Your petty cash request for ${formatCurrency(req.requestedAmount)} was declined by HQ. Reason: $reason',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusRejectedByOrg,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: reason,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. REQUEST LIFECYCLE: STAGE 4 (MANAGER ALLOCATION - AWAITING RECEIPT)
  // ---------------------------------------------------------------------------

  /// Manager allocates the approved petty cash amount to the Supervisor.
  /// The amount is marked as allocated, but is NOT yet added to availableBalance.
  /// It awaits physical receipt confirmation from the Supervisor.
  Future<void> managerAllocatePettyCash({
    required String requestId,
    required String managerName,
    String? managerId,
    required double allocationAmount,
    String? remarks,
  }) async {
    if (allocationAmount <= 0) {
      throw Exception('Allocation amount must be greater than zero.');
    }

    final firestore = FirebaseFirestore.instance;
    final reqRef = FirestoreService.pettyCashRequests.doc(requestId);

    // Variables captured during transaction to trigger outside notifications safely
    late final String supervisorId;
    late final String supervisorName;
    late final bool isReplenishment;

    await firestore.runTransaction((txn) async {
      final reqSnap = await txn.get(reqRef);
      if (!reqSnap.exists || reqSnap.data() == null) {
        throw Exception('Request #$requestId not found.');
      }

      final reqData = reqSnap.data()!;
      final currentStatus = reqData['status']?.toString() ?? '';
      if (currentStatus != ApprovalWorkflowService.statusPendingManagerClearance &&
          currentStatus != 'org_approved') {
        throw Exception(
          'Request cannot be allocated. Current status: $currentStatus. Organization approval is required first.',
        );
      }

      final approvedAmount = (reqData['approvedAmount'] is num)
          ? (reqData['approvedAmount'] as num).toDouble()
          : (reqData['requestedAmount'] as num).toDouble();

      if (allocationAmount > approvedAmount) {
        throw Exception(
          'Allocation amount (${formatCurrency(allocationAmount)}) cannot exceed approved amount (${formatCurrency(approvedAmount)}).',
        );
      }

      supervisorId = (reqData['supervisorId'] ?? '').toString();
      supervisorName = (reqData['supervisorName'] ?? 'Supervisor').toString();
      isReplenishment = reqData['requestType'] == 'REPLENISHMENT';

      final auditEntry = ApprovalWorkflowService.createAuditEntry(
        step: '4. Manager Allocation',
        action: isReplenishment ? 'Replenishment Allocated' : 'Petty Cash Allocated',
        actorRole: 'Manager',
        actorName: managerName,
        actorId: managerId,
        remarks:
            'Allocated ${formatCurrency(allocationAmount)} to $supervisorName (Awaiting physical receipt confirmation). Remarks: ${remarks ?? 'Allocated & Awaiting Receipt'}',
      );

      // 1. Update Request Doc -> status: awaiting_confirmation
      txn.update(reqRef, {
        'status': ApprovalWorkflowService.statusAwaitingConfirmation,
        'statusDisplay': 'Awaiting Receipt Confirmation',
        'currentStep': 4,
        'allocatedAmount': allocationAmount,
        'allocatedBy': managerName,
        'allocatedAt': FieldValue.serverTimestamp(),
        'approvalHistory': FieldValue.arrayUnion([auditEntry]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Create Audit Log Entry
      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: isReplenishment
            ? 'REPLENISHMENT_ALLOCATED_AWAITING_RECEIPT'
            : 'CASH_ALLOCATED_AWAITING_RECEIPT',
        entityType: 'REQUEST',
        entityId: requestId,
        actorId: managerId ?? '',
        actorName: managerName,
        actorRole: 'Manager',
        previousState: {'status': currentStatus},
        newState: {
          'status': ApprovalWorkflowService.statusAwaitingConfirmation,
          'allocatedAmount': allocationAmount,
          'allocatedBy': managerName,
        },
        metadata: {'requestId': requestId, 'supervisorId': supervisorId},
        timestamp: DateTime.now(),
      );

      txn.set(logRef, auditLog.toMap());
    });

    // Notify Supervisor in real time that cash has been allocated and awaits confirmation
    final formattedAmt = formatCurrency(allocationAmount);
    await NotificationService.notifySupervisor(
      supervisorName: supervisorName,
      supervisorId: supervisorId,
      title: '💵 Petty Cash Allocated – Confirm Receipt',
      body:
          '$formattedAmt has been allocated by Manager $managerName. Please confirm once you have physically received the cash.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusAwaitingConfirmation,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: remarks,
      data: {
        'allocatedAmount': allocationAmount,
        'status': ApprovalWorkflowService.statusAwaitingConfirmation,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6b. SUPERVISOR CONFIRMS AMOUNT RECEIVED (BALANCE ACTIVATION)
  // ---------------------------------------------------------------------------

  /// Supervisor confirms physical receipt of the allocated petty cash.
  /// This action is atomic and idempotent: repeated clicks cannot double-credit.
  /// Credits available balance, creates ledger transaction, logs audit entry,
  /// and notifies the Manager in real time.
  Future<void> supervisorConfirmAmountReceived({
    required String requestId,
    required String supervisorId,
    required String supervisorName,
    String? remarks,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final reqRef = FirestoreService.pettyCashRequests.doc(requestId);

    late final double allocationAmount;
    late final double newAvailableBalance;
    late final String managerId;
    late final String managerName;
    late final String txnId;
    bool alreadyConfirmed = false;

    await firestore.runTransaction((txn) async {
      final reqSnap = await txn.get(reqRef);
      if (!reqSnap.exists || reqSnap.data() == null) {
        throw Exception('Request #$requestId not found.');
      }

      final reqData = reqSnap.data()!;

      // Idempotency check: if already confirmed or received, exit safely
      if (reqData['receivedAt'] != null ||
          reqData['status'] == ApprovalWorkflowService.statusReceived ||
          reqData['status'] == ApprovalWorkflowService.statusApproved) {
        alreadyConfirmed = true;
        return;
      }

      final currentStatus = reqData['status']?.toString() ?? '';
      if (currentStatus != ApprovalWorkflowService.statusAwaitingConfirmation &&
          currentStatus != 'awaiting_confirmation' &&
          currentStatus != 'awaiting_receipt_confirmation') {
        throw Exception(
          'Request is not awaiting receipt confirmation (current status: $currentStatus).',
        );
      }

      allocationAmount = (reqData['allocatedAmount'] is num)
          ? (reqData['allocatedAmount'] as num).toDouble()
          : (reqData['approvedAmount'] is num)
              ? (reqData['approvedAmount'] as num).toDouble()
              : (reqData['requestedAmount'] as num).toDouble();

      if (allocationAmount <= 0) {
        throw Exception('Invalid allocated amount on request #$requestId.');
      }

      final isReplenishment = reqData['requestType'] == 'REPLENISHMENT';
      managerId = (reqData['managerId'] ?? '').toString();
      managerName = (reqData['allocatedBy'] ?? reqData['managerName'] ?? 'Manager').toString();

      final cleanSupId = supervisorId.trim().toLowerCase();
      final accountRef = FirestoreService.pettyCashAccounts.doc(cleanSupId);
      final accountSnap = await txn.get(accountRef);

      double prevAllocated = 0.0;
      double prevUsed = 0.0;
      double prevAvailable = 0.0;
      double prevCycleAllocated = 0.0;

      if (accountSnap.exists && accountSnap.data() != null) {
        final aData = accountSnap.data()!;
        prevAllocated = (aData['totalAllocated'] is num)
            ? (aData['totalAllocated'] as num).toDouble()
            : 0.0;
        prevUsed = (aData['totalUsed'] is num)
            ? (aData['totalUsed'] as num).toDouble()
            : 0.0;
        prevAvailable = (aData['availableBalance'] is num)
            ? (aData['availableBalance'] as num).toDouble()
            : (prevAllocated - prevUsed);
        prevCycleAllocated = (aData['currentCycleAllocated'] is num)
            ? (aData['currentCycleAllocated'] as num).toDouble()
            : prevAllocated;
      }

      final newTotalAllocated = prevAllocated + allocationAmount;
      newAvailableBalance = prevAvailable + allocationAmount;
      final newCycleAllocated =
          isReplenishment ? (prevCycleAllocated + allocationAmount) : allocationAmount;

      txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}_RECV';

      final auditEntry = ApprovalWorkflowService.createAuditEntry(
        step: '5. Amount Received Confirmation',
        action: 'Amount Received Confirmed',
        actorRole: 'Supervisor',
        actorName: supervisorName,
        actorId: supervisorId,
        remarks: remarks ?? 'Physically received ${formatCurrency(allocationAmount)} in cash.',
      );

      // 1. Update Request Doc to Received / Active
      txn.update(reqRef, {
        'status': ApprovalWorkflowService.statusReceived,
        'statusDisplay': 'Received / Active',
        'currentStep': 5,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBySupervisorId': supervisorId,
        'receivedBySupervisorName': supervisorName,
        'approvalHistory': FieldValue.arrayUnion([auditEntry]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Account Doc (Now crediting availableBalance and totalAllocated)
      txn.set(
        accountRef,
        {
          'accountId': cleanSupId,
          'orgId': FirestoreService.currentOrgId,
          'supervisorId': supervisorId,
          'supervisorName': supervisorName,
          'managerId': managerId,
          'managerName': managerName,
          'totalAllocated': newTotalAllocated,
          'totalUsed': prevUsed,
          'availableBalance': newAvailableBalance,
          'lowBalanceThresholdPercent': 10.0,
          'lowBalanceTriggered': false,
          'currentCycleAllocated': newCycleAllocated,
          'currentCycleId': requestId,
          'lastTransactionAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3. Create Inflow Ledger Transaction
      final txnRef = FirestoreService.pettyCashTransactions.doc(txnId);
      final transactionRecord = PettyCashTransaction(
        transactionId: txnId,
        idempotencyKey: 'RECV_${requestId}_${allocationAmount.toInt()}',
        accountId: cleanSupId,
        orgId: FirestoreService.currentOrgId,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        managerId: managerId,
        managerName: managerName,
        isSiteExpense: false,
        transactionType: isReplenishment ? 'REPLENISHMENT' : 'ALLOCATION',
        expenseCategory: isReplenishment ? 'Replenishment' : 'Initial Allocation',
        description: isReplenishment
            ? 'Petty cash replenishment received and confirmed by $supervisorName'
            : 'Initial petty cash allocation received and confirmed by $supervisorName',
        amount: allocationAmount,
        previousBalance: prevAvailable,
        newBalance: newAvailableBalance,
        remarks: remarks ?? 'Cash received physically.',
        transactionDate: DateTime.now(),
        createdBy: supervisorName,
        createdRole: 'Supervisor',
        createdAt: DateTime.now(),
      );

      txn.set(txnRef, transactionRecord.toMap());

      // 4. Create Audit Log Entry
      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'CASH_RECEIPT_CONFIRMED',
        entityType: 'ACCOUNT',
        entityId: cleanSupId,
        actorId: supervisorId,
        actorName: supervisorName,
        actorRole: 'Supervisor',
        previousState: {
          'availableBalance': prevAvailable,
          'totalAllocated': prevAllocated,
          'status': currentStatus,
        },
        newState: {
          'availableBalance': newAvailableBalance,
          'totalAllocated': newTotalAllocated,
          'allocatedAmount': allocationAmount,
          'status': 'received',
          'receivedAt': DateTime.now().toIso8601String(),
        },
        metadata: {'requestId': requestId, 'txnId': txnId},
        timestamp: DateTime.now(),
      );

      txn.set(logRef, auditLog.toMap());
    });

    if (alreadyConfirmed) return;

    // 5. Notify Manager in real time that receipt has been confirmed
    final formattedAmt = formatCurrency(allocationAmount);
    final formattedBal = formatCurrency(newAvailableBalance);
    await NotificationService.notifyManager(
      title: '🤝 Petty Cash Receipt Confirmed',
      body:
          'Supervisor $supervisorName confirmed receipt of $formattedAmt petty cash. Available balance: $formattedBal.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusReceived,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: remarks,
      extraData: {
        'allocatedAmount': allocationAmount,
        'newBalance': newAvailableBalance,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'receivedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. EXPENSE RECORDING: ATOMIC BALANCE DEDUCTION & 10% THRESHOLD MONITOR
  // ---------------------------------------------------------------------------

  /// Records a petty cash expense (Site-wise or Other Expense).
  /// Fully atomic Firestore transaction with negative balance protection,
  /// idempotency protection, and 10% low-balance trigger.
  Future<PettyCashTransaction> recordExpense({
    required String supervisorId,
    required String supervisorName,
    String? managerId,
    String? managerName,
    String? siteId,
    String? siteName,
    required bool isSiteExpense,
    required String expenseCategory,
    required String description,
    required double amount,
    DateTime? transactionDate,
    String? remarks,
    String? attachmentUrl,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Expense amount must be greater than zero.');
    }
    if (description.trim().isEmpty) {
      throw Exception('Description is required for all petty cash expenses.');
    }
    if (isSiteExpense && (siteId == null || siteId.trim().isEmpty)) {
      throw Exception('Site selection is required for site-wise expenses.');
    }

    final firestore = FirebaseFirestore.instance;
    final cleanSupId = supervisorId.trim().toLowerCase();
    final accountRef = FirestoreService.pettyCashAccounts.doc(cleanSupId);

    final safeIdempotencyKey = idempotencyKey?.trim().isNotEmpty == true
        ? idempotencyKey!.trim()
        : 'EXP_${cleanSupId}_${DateTime.now().millisecondsSinceEpoch}_${amount.toInt()}';

    // Check if idempotencyKey already exists before starting transaction
    final existingTxnSnap = await FirestoreService.pettyCashTransactions
        .where('idempotencyKey', isEqualTo: safeIdempotencyKey)
        .limit(1)
        .get();

    if (existingTxnSnap.docs.isNotEmpty) {
      debugPrint('PettyCashService: Duplicate submission prevented by idempotency key: $safeIdempotencyKey');
      return PettyCashTransaction.fromMap(
        existingTxnSnap.docs.first.id,
        existingTxnSnap.docs.first.data(),
      );
    }

    // Capture variables from transaction to trigger notifications outside
    late final PettyCashTransaction createdTxn;
    bool shouldNotifyLowBalance = false;
    double resultingBalance = 0.0;
    double thresholdAmount = 0.0;

    await firestore.runTransaction((txn) async {
      final accountSnap = await txn.get(accountRef);
      if (!accountSnap.exists || accountSnap.data() == null) {
        throw Exception(
          'No petty cash account found for $supervisorName. Please request initial petty cash allocation.',
        );
      }

      final accountData = accountSnap.data()!;
      final double currentAllocated = (accountData['totalAllocated'] is num)
          ? (accountData['totalAllocated'] as num).toDouble()
          : 0.0;
      final double currentUsed = (accountData['totalUsed'] is num)
          ? (accountData['totalUsed'] as num).toDouble()
          : 0.0;
      final double currentAvailable = (accountData['availableBalance'] is num)
          ? (accountData['availableBalance'] as num).toDouble()
          : (currentAllocated - currentUsed);

      // PREVENT NEGATIVE BALANCE: Server-side validation
      if (amount > currentAvailable) {
        throw Exception(
          'Insufficient petty cash balance. Available balance: ${formatCurrency(currentAvailable)}.',
        );
      }

      final double newBalance = (currentAvailable - amount).clamp(0.0, double.infinity);
      final double newTotalUsed = currentUsed + amount;
      resultingBalance = newBalance;

      // 10% LOW-BALANCE CALCULATION:
      final double cycleAllocated = (accountData['currentCycleAllocated'] is num)
          ? (accountData['currentCycleAllocated'] as num).toDouble()
          : currentAllocated;
      final double thresholdPercent = (accountData['lowBalanceThresholdPercent'] is num)
          ? (accountData['lowBalanceThresholdPercent'] as num).toDouble()
          : 10.0;
      final bool alreadyTriggered = accountData['lowBalanceTriggered'] == true;

      final double baseForThreshold = cycleAllocated > 0 ? cycleAllocated : currentAllocated;
      thresholdAmount = baseForThreshold * (thresholdPercent / 100.0);

      // Check if threshold reached or dropped below
      if (newBalance <= thresholdAmount && !alreadyTriggered && currentAllocated > 0) {
        shouldNotifyLowBalance = true;
      }

      final txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}_EXP';
      final actualDate = transactionDate ?? DateTime.now();

      createdTxn = PettyCashTransaction(
        transactionId: txnId,
        idempotencyKey: safeIdempotencyKey,
        accountId: cleanSupId,
        orgId: FirestoreService.currentOrgId,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        managerId: managerId ?? (accountData['managerId'] ?? '').toString(),
        managerName: managerName ?? (accountData['managerName'] ?? '').toString(),
        siteId: isSiteExpense ? siteId : null,
        siteName: isSiteExpense ? siteName : null,
        isSiteExpense: isSiteExpense,
        transactionType: 'EXPENSE',
        expenseCategory: expenseCategory,
        description: description,
        amount: amount,
        previousBalance: currentAvailable,
        newBalance: newBalance,
        remarks: remarks ?? '',
        attachmentUrl: attachmentUrl,
        transactionDate: actualDate,
        createdBy: supervisorName,
        createdRole: 'Supervisor',
        createdAt: DateTime.now(),
      );

      // 1. Write Transaction doc
      final txnRef = FirestoreService.pettyCashTransactions.doc(txnId);
      txn.set(txnRef, createdTxn.toMap());

      // 2. Update Account doc
      txn.update(accountRef, {
        'totalUsed': newTotalUsed,
        'availableBalance': newBalance,
        if (shouldNotifyLowBalance) 'lowBalanceTriggered': true,
        'lastTransactionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Write Audit Log
      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'EXPENSE_RECORDED',
        entityType: 'TRANSACTION',
        entityId: txnId,
        actorId: supervisorId,
        actorName: supervisorName,
        actorRole: 'Supervisor',
        previousState: {'availableBalance': currentAvailable},
        newState: {
          'availableBalance': newBalance,
          'amount': amount,
          'lowBalanceTriggered': alreadyTriggered || shouldNotifyLowBalance,
        },
        metadata: {
          'isSiteExpense': isSiteExpense,
          'siteId': siteId ?? '',
          'category': expenseCategory,
        },
        timestamp: DateTime.now(),
      );
      txn.set(logRef, auditLog.toMap());
    });

    // -------------------------------------------------------------------------
    // 10% LOW-BALANCE NOTIFICATION TRIGGER
    // Dispatched only when the threshold is crossed, exactly once per cycle!
    // -------------------------------------------------------------------------
    if (shouldNotifyLowBalance) {
      final formattedBal = formatCurrency(resultingBalance);
      final formattedThreshold = formatCurrency(thresholdAmount);

      await NotificationService.notifySupervisor(
        supervisorName: supervisorName,
        supervisorId: supervisorId,
        title: '⚠️ Petty Cash Low Balance',
        body:
            'Your petty cash balance has reached $formattedBal (at or below $formattedThreshold). Please request additional petty cash from your Manager.',
        requestType: 'petty_cash',
        requestId: cleanSupId,
        docId: cleanSupId,
        status: 'low_balance',
        senderRole: 'System',
        senderName: 'Petty Cash System',
        remarks: 'Low balance threshold reached.',
        data: {
          'currentBalance': resultingBalance,
          'threshold': thresholdAmount,
        },
      );

      // Write audit record for low balance notification
      await _writeAuditLog(
        action: 'LOW_BALANCE_NOTIFIED',
        entityType: 'ACCOUNT',
        entityId: cleanSupId,
        actorId: 'system',
        actorName: 'Petty Cash Automation',
        actorRole: 'System',
        newState: {
          'balance': resultingBalance,
          'threshold': thresholdAmount,
        },
      );
    }

    return createdTxn;
  }

  // ---------------------------------------------------------------------------
  // 8. AUDIT LOGGING HELPER
  // ---------------------------------------------------------------------------

  Future<void> _writeAuditLog({
    required String action,
    required String entityType,
    required String entityId,
    required String actorId,
    required String actorName,
    required String actorRole,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = FirestoreService.pettyCashAuditLogs.doc();
      final log = PettyCashAuditLog(
        logId: docRef.id,
        action: action,
        entityType: entityType,
        entityId: entityId,
        actorId: actorId,
        actorName: actorName,
        actorRole: actorRole,
        previousState: previousState ?? const {},
        newState: newState ?? const {},
        metadata: metadata ?? const {},
        timestamp: DateTime.now(),
      );
      await docRef.set(log.toMap());
    } catch (e) {
      debugPrint('PettyCashService: Audit log error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 9. QUERIES & STREAM HELPERS FOR SCREENS & REPORTS
  // ---------------------------------------------------------------------------

  /// Streams transactions for a supervisor.
  Stream<List<PettyCashTransaction>> streamSupervisorTransactions(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashTransactions.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashTransaction.fromMap(d.id, d.data()))
          .where((t) {
            final tAccId = t.accountId.trim().toLowerCase();
            final tSupId = t.supervisorId.trim().toLowerCase();
            return tAccId == cleanId || tSupId == cleanId || t.supervisorId == supervisorId;
          })
          .toList();

      list.sort((a, b) {
        final tA = a.createdAt ?? a.transactionDate;
        final tB = b.createdAt ?? b.transactionDate;
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Streams requests for a supervisor.
  Stream<List<PettyCashRequest>> streamSupervisorRequests(
    String supervisorId, {
    String? supervisorName,
  }) {
    final cleanId = supervisorId.trim().toLowerCase();
    final cleanName = supervisorName?.trim().toLowerCase() ?? '';

    return FirestoreService.pettyCashRequests.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashRequest.fromMap(d.id, d.data()))
          .where((r) {
            final rSupId = r.supervisorId.trim().toLowerCase();
            final rSupName = r.supervisorName.trim().toLowerCase();

            if (cleanId.isNotEmpty && (rSupId == cleanId || r.supervisorId == supervisorId)) {
              return true;
            }
            if (cleanName.isNotEmpty && (rSupName == cleanName || r.supervisorName == supervisorName)) {
              return true;
            }
            return false;
          })
          .toList();

      list.sort((a, b) {
        final tA = a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Streams all requests for Manager / Organization.
  Stream<List<PettyCashRequest>> streamAllRequests() {
    return FirestoreService.pettyCashRequests.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashRequest.fromMap(d.id, d.data()))
          .toList();

      list.sort((a, b) {
        final tA = a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Streams all transactions for Manager / Organization.
  Stream<List<PettyCashTransaction>> streamAllTransactions() {
    return FirestoreService.pettyCashTransactions.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashTransaction.fromMap(d.id, d.data()))
          .toList();

      list.sort((a, b) {
        final tA = a.createdAt ?? a.transactionDate;
        final tB = b.createdAt ?? b.transactionDate;
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Streams audit logs.
  Stream<List<PettyCashAuditLog>> streamAuditLogs({int limit = 100}) {
    return FirestoreService.pettyCashAuditLogs
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PettyCashAuditLog.fromMap(d.id, d.data())).toList());
  }
}
