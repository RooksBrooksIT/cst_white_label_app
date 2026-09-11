import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_models.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'approval_workflow_service.dart';
import 'offline_sync_service.dart';
import 'expense_service.dart';

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
          final rawId = (data['siteId'] ?? data['site'] ?? data['site_id'] ?? doc.id)
              .toString()
              .trim();
          final sName = (data['siteName'] ?? data['site'] ?? rawId).toString().trim();
          final sCode = (data['siteCode'] ?? data['SiteCode'])?.toString().trim();
          final canonicalId = ExpenseService.formatCanonicalSiteId(
            rawId: rawId,
            siteCode: sCode,
            siteName: sName,
          );

          final pId = (data['projectId'] ?? data['project_id'] ?? data['project'] ?? '').toString().trim();
          final pName = (data['projectName'] ?? data['project_name'] ?? data['project'] ?? '').toString().trim();

          if (canonicalId.isNotEmpty && !seenSiteIds.contains(canonicalId.toLowerCase())) {
            seenSiteIds.add(canonicalId.toLowerCase());
            assignedSites.add({
              'siteId': canonicalId,
              'siteName': sName,
              if (pId.isNotEmpty) 'projectId': pId,
              if (pName.isNotEmpty) 'projectName': pName,
            });
          }
        }
      }

      // Fallback: If empty, load active sites from `Site` collection
      if (assignedSites.isEmpty) {
        final siteSnap = await FirestoreService.sites.get();
        for (final doc in siteSnap.docs) {
          final data = doc.data();
          final rawId = (data['siteId'] ?? doc.id).toString().trim();
          final sName = (data['siteName'] ?? data['name'] ?? rawId).toString().trim();
          final sCode = (data['siteCode'] ?? data['SiteCode'])?.toString().trim();
          final pId = (data['projectId'] ?? data['project_id'] ?? data['project'] ?? '').toString().trim();
          final pName = (data['projectName'] ?? data['project_name'] ?? data['project'] ?? '').toString().trim();
          final canonicalId = ExpenseService.formatCanonicalSiteId(
            rawId: rawId,
            siteCode: sCode,
            siteName: sName,
          );
          if (canonicalId.isNotEmpty && !seenSiteIds.contains(canonicalId.toLowerCase())) {
            seenSiteIds.add(canonicalId.toLowerCase());
            assignedSites.add({
              'siteId': canonicalId,
              'siteName': sName,
              if (pId.isNotEmpty) 'projectId': pId,
              if (pName.isNotEmpty) 'projectName': pName,
            });
          }
        }
      }

      final sanitized = ExpenseService.sanitizeSiteIds(assignedSites.map((e) => e['siteId']!)).toSet();
      return assignedSites.where((e) => sanitized.contains(e['siteId'])).toList();
    } catch (e) {
      debugPrint('PettyCashService: Error fetching assigned sites: $e');
    }

    return assignedSites;
  }

  /// Fetches active/unpaid site payment requisitions for a supervisor to link to petty cash.
  Future<List<Map<String, dynamic>>> fetchPendingSitePaymentsForSupervisor({
    required String supervisorId,
    String? siteId,
  }) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final cleanSupId = supervisorId.trim().toLowerCase();
      final filterSiteId = (siteId ?? '').trim().toLowerCase();
      final siteKeys = siteId != null && siteId.trim().isNotEmpty
          ? (await ExpenseService.resolveSiteKeys(siteId)).map((k) => k.toLowerCase()).toSet()
          : <String>{};

      // 1. Query siteSupervisorEntries collection
      final entriesSnap =
          await FirestoreService.getCollection('siteSupervisorEntries').get();
      for (final doc in entriesSnap.docs) {
        final data = doc.data();
        final sSupId = (data['supervisorId'] ?? data['Supervisor ID'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final sSiteId = (data['siteId'] ?? data['site_id'] ?? data['siteCode'] ?? '')
            .toString()
            .trim();
        final status = (data['status'] ?? 'pending_manager_review')
            .toString()
            .toLowerCase();

        final isFunded = data['fundedViaPettyCash'] == true;
        final isPending = !isFunded && status != 'rejected_by_manager' && status != 'rejected_by_org';
        final matchSup = cleanSupId.isEmpty || sSupId == cleanSupId || sSupId.isEmpty;
        final matchSite = filterSiteId.isEmpty ||
            sSiteId.toLowerCase() == filterSiteId ||
            siteKeys.contains(sSiteId.toLowerCase());

        if (isPending && matchSup && matchSite) {
          final amt = (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : (data['totalAmount'] is num)
                  ? (data['totalAmount'] as num).toDouble()
                  : double.tryParse(data['amount']?.toString() ?? '') ?? 0.0;

          final sName = (data['siteName'] ?? data['site'] ?? sSiteId).toString();
          final stage = (data['projectStage'] ?? data['projectPhase'] ?? 'Site Requisition').toString();

          results.add({
            'id': doc.id,
            'source': 'siteSupervisorEntries',
            'siteId': sSiteId,
            'siteName': sName,
            'amount': amt,
            'projectStage': stage,
            'title': '$sName ($stage) - ${formatCurrency(amt)}',
            'status': status,
            'raw': data,
          });
        }
      }

      // 2. Query siteSupervisorPayments collection
      final paymentsSnap =
          await FirestoreService.getCollection('siteSupervisorPayments').get();
      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        final sSiteId = (data['siteId'] ?? '').toString().trim();
        final status = (data['status'] ?? 'pending_manager_review')
            .toString()
            .toLowerCase();

        final isFunded = data['fundedViaPettyCash'] == true;
        final isPending = !isFunded;
        final matchSite = filterSiteId.isEmpty || sSiteId.toLowerCase() == filterSiteId;

        if (isPending && matchSite) {
          final amt = (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : double.tryParse(data['amount']?.toString() ?? '') ?? 0.0;

          final stage = (data['projectStage'] ?? 'Stage Payment').toString();

          // Avoid duplicate if doc.id is already in results
          if (!results.any((r) => r['id'] == doc.id)) {
            results.add({
              'id': doc.id,
              'source': 'siteSupervisorPayments',
              'siteId': sSiteId,
              'siteName': sSiteId,
              'amount': amt,
              'projectStage': stage,
              'title': 'Site Payment #$sSiteId ($stage) - ${formatCurrency(amt)}',
              'status': status,
              'raw': data,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('PettyCashService: Error fetching pending site payments: $e');
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // 3. REQUEST LIFECYCLE: STAGE 1 (SUPERVISOR SUBMIT & MANAGER MANUAL INITIATION)
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
    String? projectId,
    String? projectName,
    required String siteId,
    required String siteName,
    String? linkedSitePaymentId,
    String? linkedSitePaymentTitle,
  }) async {
    if (requestedAmount <= 0) {
      throw Exception('Requested amount must be greater than zero.');
    }
    if (siteId.trim().isEmpty) {
      throw Exception('Site selection is mandatory for petty cash requests.');
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
      requestSource: 'REQUEST_BASED',
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: resolvedManagerId.isNotEmpty ? resolvedManagerId : account.managerId,
      managerName: resolvedManagerName.isNotEmpty ? resolvedManagerName : account.managerName,
      projectId: projectId,
      projectName: projectName,
      siteId: siteId,
      siteName: siteName,
      requestedAmount: requestedAmount,
      approvedAmount: 0.0,
      allocatedAmount: 0.0,
      totalSpent: 0.0,
      remainingBalance: 0.0,
      reason: reason,
      remarks: remarks ?? '',
      status: ApprovalWorkflowService.statusPendingManagerReview,
      statusDisplay: 'Pending Manager Review',
      currentStep: 1,
      currentBalanceAtRequest: account.availableBalance,
      totalAllocatedAtRequest: account.totalAllocated,
      totalUsedAtRequest: account.totalUsed,
      linkedSitePaymentId: linkedSitePaymentId,
      linkedSitePaymentTitle: linkedSitePaymentTitle,
      approvalHistory: [auditEntry],
      createdAt: now,
      updatedAt: now,
    );

    final requestMap = request.toMap();
    requestMap['createdAt'] = Timestamp.fromDate(now);
    requestMap['updatedAt'] = Timestamp.fromDate(now);

    if (!OfflineSyncService().isOnline) {
      final offlineMap = Map<String, dynamic>.from(requestMap);
      offlineMap['createdAt'] = now.toIso8601String();
      offlineMap['updatedAt'] = now.toIso8601String();
      await OfflineSyncService().enqueueEntry(
        type: 'petty_cash_request',
        data: offlineMap,
        idempotencyKey: reqDocId,
      );
      return reqDocId;
    }

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
        '$supervisorName requested $formattedAmt for site $siteName. Reason: $reason';

    await NotificationService.notifyManagerAndOrganisation(
      title: title,
      body: body,
      requestType: 'petty_cash',
      requestId: reqDocId,
      docId: reqDocId,
      status: ApprovalWorkflowService.statusPendingManagerReview,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: reason,
      requiredAction: 'Action Required: Review & Verification',
      forSupervisorName: supervisorName,
      forSupervisorId: supervisorId,
      forManagerName: resolvedManagerName.isNotEmpty ? resolvedManagerName : null,
      extraData: {
        'requestedAmount': requestedAmount,
        'requestType': requestType,
        'requestSource': 'REQUEST_BASED',
        'supervisorId': supervisorId,
        'siteId': siteId,
        'siteName': siteName,
      },
    );

    return reqDocId;
  }

  /// Manager manually creates and sends Petty Cash for a Supervisor & Site.
  /// This allocation requires mandatory Organization approval before funds become active.
  Future<String> managerCreateManualAllocation({
    required String managerId,
    required String managerName,
    required String supervisorId,
    required String supervisorName,
    required String siteId,
    required String siteName,
    String? projectId,
    String? projectName,
    required double amount,
    required String reason,
    String? remarks,
  }) async {
    if (amount <= 0) {
      throw Exception('Petty cash amount must be greater than zero.');
    }
    if (siteId.trim().isEmpty) {
      throw Exception('Site selection is mandatory for petty cash allocation.');
    }
    if (supervisorId.trim().isEmpty) {
      throw Exception('Supervisor selection is mandatory.');
    }

    final orgId = FirestoreService.currentOrgId;

    final account = await getOrCreateAccount(
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: managerId,
      managerName: managerName,
    );

    final reqDocId =
        'PCM_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '1. Manager Manual Allocation',
      action: 'Manual Petty Cash Initiated',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: reason,
    );

    final now = DateTime.now();
    final request = PettyCashRequest(
      requestId: reqDocId,
      orgId: orgId,
      requestType: 'MANUAL_MANAGER',
      requestSource: 'MANUAL_MANAGER',
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: managerId,
      managerName: managerName,
      projectId: projectId,
      projectName: projectName,
      siteId: siteId,
      siteName: siteName,
      requestedAmount: amount,
      approvedAmount: amount,
      allocatedAmount: amount,
      totalSpent: 0.0,
      remainingBalance: 0.0,
      reason: reason,
      remarks: remarks ?? '',
      status: ApprovalWorkflowService.statusPendingOrgApproval,
      statusDisplay: 'Pending Organization Approval',
      currentStep: 2,
      currentBalanceAtRequest: account.availableBalance,
      totalAllocatedAtRequest: account.totalAllocated,
      totalUsedAtRequest: account.totalUsed,
      managerReviewedBy: managerName,
      managerReviewedAt: now,
      managerReviewRemarks: reason,
      approvalHistory: [auditEntry],
      createdAt: now,
      updatedAt: now,
    );

    final requestMap = request.toMap();
    requestMap['createdAt'] = Timestamp.fromDate(now);
    requestMap['updatedAt'] = Timestamp.fromDate(now);

    await FirestoreService.pettyCashRequests.doc(reqDocId).set(requestMap);

    await _writeAuditLog(
      action: 'MANUAL_ALLOCATION_CREATED',
      entityType: 'REQUEST',
      entityId: reqDocId,
      actorId: managerId,
      actorName: managerName,
      actorRole: 'Manager',
      newState: requestMap,
    );

    // Notify Organization for authorization
    final formattedAmt = formatCurrency(amount);
    await NotificationService.notifyOrganisation(
      title: '🏢 Manual Petty Cash Awaiting Approval',
      body:
          'Manager $managerName initiated $formattedAmt manual petty cash for $supervisorName on site $siteName. HQ approval required.',
      requestType: 'petty_cash',
      requestId: reqDocId,
      docId: reqDocId,
      status: ApprovalWorkflowService.statusPendingOrgApproval,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: reason,
      requiredAction: 'Action Required: HQ Authorization',
      extraData: {
        'requestedAmount': amount,
        'requestSource': 'MANUAL_MANAGER',
        'supervisorName': supervisorName,
        'supervisorId': supervisorId,
        'siteName': siteName,
        'siteId': siteId,
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
      requiredAction: 'Action Required: HQ Authorization',
      extraData: {
        'requestedAmount': req.requestedAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
        'siteName': req.siteName,
        'siteId': req.siteId,
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
      requiredAction: 'Action Required: Revise or Close Request',
    );
  }

  /// Manager allocates / releases approved funds for a Petty Cash request.
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

    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '4. Manager Fund Release',
      action: 'Funds Released by Manager',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: 'Released ${formatCurrency(allocationAmount)}. Remarks: ${remarks ?? ''}',
    );

    final updates = {
      'status': ApprovalWorkflowService.statusAwaitingConfirmation,
      'statusDisplay': 'Awaiting Receipt Confirmation',
      'currentStep': 4,
      'allocatedAmount': allocationAmount,
      'allocatedBy': managerName,
      'allocatedAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'MANAGER_ALLOCATED',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: managerId ?? '',
      actorName: managerName,
      actorRole: 'Manager',
      previousState: {'status': req.status},
      newState: updates,
    );

    // Notify Supervisor to confirm receipt
    final formattedAmt = formatCurrency(allocationAmount);
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '💵 Petty Cash Released – Confirm Receipt',
      body:
          'Manager $managerName released $formattedAmt petty cash for site ${req.siteName ?? ""}. Please confirm once you have physically received the cash.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusAwaitingConfirmation,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: remarks,
      requiredAction: 'Action Required: Confirm Physical Cash Receipt',
      extraData: {
        'allocatedAmount': allocationAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
        'siteId': req.siteId,
        'siteName': req.siteName,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. REQUEST LIFECYCLE: STAGE 3 (ORGANIZATION APPROVAL / REJECTION)
  // ---------------------------------------------------------------------------

  /// Organization authorizes the request with an approved amount.
  /// Directly moves to awaiting receipt confirmation by the Supervisor.
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
      'status': ApprovalWorkflowService.statusAwaitingConfirmation,
      'statusDisplay': 'Awaiting Receipt Confirmation',
      'currentStep': 4,
      'approvedAmount': approvedAmount,
      'allocatedAmount': approvedAmount,
      'allocatedBy': orgUserName,
      'allocatedAt': FieldValue.serverTimestamp(),
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

    // Notify Supervisor to confirm receipt
    final formattedAmt = formatCurrency(approvedAmount);
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '💵 Petty Cash Approved – Confirm Receipt',
      body:
          'HQ approved $formattedAmt petty cash for site ${req.siteName ?? ""}. Please confirm once you have physically received the cash.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusAwaitingConfirmation,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
      requiredAction: 'Action Required: Confirm Physical Cash Receipt',
      extraData: {
        'approvedAmount': approvedAmount,
        'allocatedAmount': approvedAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
        'siteId': req.siteId,
        'siteName': req.siteName,
      },
    );

    // Notify Manager
    await NotificationService.notifyManager(
      title: '✅ Petty Cash Authorized by HQ',
      body:
          'HQ authorized $formattedAmt for ${req.supervisorName} on site ${req.siteName ?? ""}. Awaiting supervisor confirmation.',
      forManagerName: req.managerName,
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusAwaitingConfirmation,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
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
      forManagerName: req.managerName,
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
  // 6. SUPERVISOR CONFIRMS AMOUNT RECEIVED (BALANCE ACTIVATION)
  // ---------------------------------------------------------------------------

  /// Supervisor confirms physical receipt of the allocated petty cash.
  /// This action is atomic and idempotent: repeated clicks cannot double-credit.
  /// Credits available balance, initializes site allocation balance, creates ledger transaction,
  /// logs audit entry, and notifies Manager & Org.
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
    String? reqSiteId;
    String? reqSiteName;
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

      allocationAmount = (reqData['approvedAmount'] is num && (reqData['approvedAmount'] as num) > 0)
          ? (reqData['approvedAmount'] as num).toDouble()
          : (reqData['allocatedAmount'] is num && (reqData['allocatedAmount'] as num) > 0)
              ? (reqData['allocatedAmount'] as num).toDouble()
              : (reqData['requestedAmount'] as num).toDouble();

      if (allocationAmount <= 0) {
        throw Exception('Invalid allocated amount on request #$requestId.');
      }

      final isReplenishment = reqData['requestType'] == 'REPLENISHMENT';
      managerId = (reqData['managerId'] ?? '').toString();
      managerName = (reqData['allocatedBy'] ?? reqData['managerName'] ?? 'Manager').toString();
      reqSiteId = reqData['siteId']?.toString();
      reqSiteName = reqData['siteName']?.toString();

      final cleanSupId = supervisorId.trim().toLowerCase();
      final accountRef = FirestoreService.pettyCashAccounts.doc(cleanSupId);
      final accountSnap = await txn.get(accountRef);

      // Read linked site payment / entry before performing any writes
      final linkedSitePaymentId = reqData['linkedSitePaymentId']?.toString();
      DocumentReference<Map<String, dynamic>>? linkedDocRefToUpdate;
      if (linkedSitePaymentId != null && linkedSitePaymentId.isNotEmpty) {
        final entryRef = FirestoreService.getCollection('siteSupervisorEntries').doc(linkedSitePaymentId);
        final entrySnap = await txn.get(entryRef);
        if (entrySnap.exists) {
          linkedDocRefToUpdate = entryRef;
        } else {
          final paymentRef = FirestoreService.getCollection('siteSupervisorPayments').doc(linkedSitePaymentId);
          final paymentSnap = await txn.get(paymentRef);
          if (paymentSnap.exists) {
            linkedDocRefToUpdate = paymentRef;
          }
        }
      }

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

      // --- ALL WRITES PERFORMED HERE (AFTER ALL READS COMPLETED) ---

      // 1. Update Request Doc to Received / Active with initialized remainingBalance
      txn.update(reqRef, {
        'status': ApprovalWorkflowService.statusReceived,
        'statusDisplay': 'Received / Active',
        'currentStep': 5,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBySupervisorId': supervisorId,
        'receivedBySupervisorName': supervisorName,
        'remainingBalance': allocationAmount,
        'totalSpent': 0.0,
        'approvalHistory': FieldValue.arrayUnion([auditEntry]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Account Doc (crediting availableBalance and totalAllocated)
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
        pettyCashId: requestId,
        accountId: cleanSupId,
        orgId: FirestoreService.currentOrgId,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        managerId: managerId,
        managerName: managerName,
        projectId: reqData['projectId']?.toString(),
        projectName: reqData['projectName']?.toString(),
        siteId: reqSiteId,
        siteName: reqSiteName,
        linkedSitePaymentId: linkedSitePaymentId,
        isSiteExpense: reqSiteId != null && reqSiteId!.isNotEmpty,
        transactionType: isReplenishment ? 'REPLENISHMENT' : 'ALLOCATION',
        expenseCategory: isReplenishment ? 'Replenishment' : 'Initial Allocation',
        description: isReplenishment
            ? 'Petty cash replenishment received and confirmed for site ${reqSiteName ?? ""}'
            : 'Initial petty cash allocation received and confirmed for site ${reqSiteName ?? ""}',
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

      // 4. Update linked Site Payment status if present
      if (linkedDocRefToUpdate != null) {
        txn.update(linkedDocRefToUpdate, {
          'fundedViaPettyCash': true,
          'pettyCashRequestId': requestId,
          'pettyCashStatus': 'disbursed',
          'pettyCashConfirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. Create Audit Log Entry
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
        metadata: {
          'requestId': requestId,
          'txnId': txnId,
          'siteId': reqSiteId ?? '',
          'siteName': reqSiteName ?? '',
          if (linkedSitePaymentId != null) 'linkedSitePaymentId': linkedSitePaymentId,
        },
        timestamp: DateTime.now(),
      );

      txn.set(logRef, auditLog.toMap());
    });

    if (alreadyConfirmed) return;

    // 5. Notify Manager in real time that receipt has been confirmed
    final formattedAmt = formatCurrency(allocationAmount);
    final formattedBal = formatCurrency(newAvailableBalance);
    await NotificationService.notifyManagerAndOrganisation(
      title: '🤝 Petty Cash Receipt Confirmed',
      body:
          'Supervisor $supervisorName confirmed receipt of $formattedAmt petty cash for site ${reqSiteName ?? ""}. Available balance: $formattedBal.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: ApprovalWorkflowService.statusReceived,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: remarks,
      requiredAction: 'Funds Active in Field',
      forSupervisorName: supervisorName,
      forSupervisorId: supervisorId,
      forManagerName: managerName.isNotEmpty ? managerName : null,
      extraData: {
        'allocatedAmount': allocationAmount,
        'newBalance': newAvailableBalance,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'siteId': reqSiteId,
        'siteName': reqSiteName,
        'receivedAt': DateTime.now().toIso8601String(),
      },
    );

    // Trigger immediate Site Financial Details & Project synchronization
    if (reqSiteId != null && reqSiteId!.trim().isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(reqSiteId!.trim()).catchError((e) {
        debugPrint('Error syncing site financial details on petty cash receipt: $e');
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 7. EXPENSE RECORDING: SITE-WISE & ATOMIC BALANCE DEDUCTION
  // ---------------------------------------------------------------------------

  /// Records a petty cash expense against a specific site and petty cash allocation.
  /// Deducts from the specific allocation's remainingBalance and the supervisor's overall account.
  Future<PettyCashTransaction> recordExpense({
    required String supervisorId,
    required String supervisorName,
    String? pettyCashId, // Target parent PettyCashRequest.requestId
    String? managerId,
    String? managerName,
    String? projectId,
    String? projectName,
    String? siteId,
    String? siteName,
    String? vendorName,
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

      // PREVENT NEGATIVE BALANCE on supervisor account
      if (amount > currentAvailable) {
        throw Exception(
          'Insufficient petty cash balance. Available balance: ${formatCurrency(currentAvailable)}.',
        );
      }

      // If a specific parent PettyCashRequest ID is provided, check and calculate its allocation balance
      DocumentReference<Map<String, dynamic>>? targetReqRef;
      double? newReqSpent;
      double? newReqRemaining;
      if (pettyCashId != null && pettyCashId.trim().isNotEmpty) {
        targetReqRef = FirestoreService.pettyCashRequests.doc(pettyCashId.trim());
        final reqSnap = await txn.get(targetReqRef);
        if (reqSnap.exists && reqSnap.data() != null) {
          final reqData = reqSnap.data()!;
          final double reqAllocated = (reqData['approvedAmount'] is num && (reqData['approvedAmount'] as num) > 0)
              ? (reqData['approvedAmount'] as num).toDouble()
              : (reqData['allocatedAmount'] is num && (reqData['allocatedAmount'] as num) > 0)
                  ? (reqData['allocatedAmount'] as num).toDouble()
                  : (reqData['requestedAmount'] as num).toDouble();
          final double reqSpent = (reqData['totalSpent'] is num)
              ? (reqData['totalSpent'] as num).toDouble()
              : 0.0;
          final double reqRemaining = (reqData['remainingBalance'] is num)
              ? (reqData['remainingBalance'] as num).toDouble()
              : (reqAllocated - reqSpent).clamp(0.0, double.infinity);

          if (amount > reqRemaining) {
            throw Exception(
              'Insufficient balance in selected allocation #$pettyCashId. Available in allocation: ${formatCurrency(reqRemaining)}.',
            );
          }

          newReqSpent = reqSpent + amount;
          newReqRemaining = (reqRemaining - amount).clamp(0.0, double.infinity);
        }
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
        pettyCashId: pettyCashId,
        accountId: cleanSupId,
        orgId: FirestoreService.currentOrgId,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        managerId: managerId ?? (accountData['managerId'] ?? '').toString(),
        managerName: managerName ?? (accountData['managerName'] ?? '').toString(),
        projectId: projectId,
        projectName: projectName,
        siteId: isSiteExpense ? siteId : (siteId ?? ''),
        siteName: isSiteExpense ? siteName : (siteName ?? ''),
        vendorName: vendorName,
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

      // --- ALL WRITES PERFORMED HERE (AFTER ALL READS COMPLETED) ---

      // 1. Update target PettyCashRequest doc if present
      if (targetReqRef != null && newReqSpent != null && newReqRemaining != null) {
        txn.update(targetReqRef, {
          'totalSpent': newReqSpent,
          'remainingBalance': newReqRemaining,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Write Transaction doc
      final txnRef = FirestoreService.pettyCashTransactions.doc(txnId);
      txn.set(txnRef, createdTxn.toMap());

      // 3. Update Account doc
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
          'pettyCashId': pettyCashId ?? '',
          'isSiteExpense': isSiteExpense,
          'siteId': siteId ?? '',
          'siteName': siteName ?? '',
          'category': expenseCategory,
        },
        timestamp: DateTime.now(),
      );
      txn.set(logRef, auditLog.toMap());
    });

    // -------------------------------------------------------------------------
    // 10% LOW-BALANCE NOTIFICATION TRIGGER
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

    // Trigger immediate Site Financial Details & Project synchronization
    final effectiveSite = (siteId != null && siteId.trim().isNotEmpty)
        ? siteId.trim()
        : (createdTxn.siteId != null ? createdTxn.siteId!.trim() : '');
    if (effectiveSite.isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(effectiveSite).catchError((e) {
        debugPrint('Error syncing site financial details on petty cash expense: $e');
      });
    }

    return createdTxn;
  }

  /// Streams active received/confirmed petty cash allocations for a supervisor.
  Stream<List<PettyCashRequest>> streamActiveSiteAllocations({
    required String supervisorId,
    String? siteId,
  }) {
    final cleanSupId = supervisorId.trim().toLowerCase();
    final filterSiteId = (siteId ?? '').trim().toLowerCase();

    return FirestoreService.pettyCashRequests.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashRequest.fromMap(d.id, d.data()))
          .where((r) {
            final matchSup = r.supervisorId.trim().toLowerCase() == cleanSupId;
            final isConfirmed = r.isReceived && r.effectiveRemainingBalance > 0;
            if (!matchSup || !isConfirmed) return false;
            if (filterSiteId.isNotEmpty) {
              final rSiteId = (r.siteId ?? '').trim().toLowerCase();
              return rSiteId == filterSiteId || rSiteId.contains(filterSiteId);
            }
            return true;
          })
          .toList();

      list.sort((a, b) {
        final tA = a.receivedAt ?? a.orgApprovedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.receivedAt ?? b.orgApprovedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
      return list;
    });
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

  // ---------------------------------------------------------------------------
  // 10. SITE-WISE EXPENSE TRACKING & AGGREGATION ENGINE
  // ---------------------------------------------------------------------------

  /// Calculates site-wise petty cash summaries across requests and transactions with filtering.
  List<SitePettyCashSummary> calculateSiteWiseSummaries({
    required List<PettyCashRequest> requests,
    required List<PettyCashTransaction> transactions,
    DateTime? fromDate,
    DateTime? toDate,
    String? siteFilter,
    String? supervisorFilter,
    String? projectFilter,
    String? categoryFilter,
  }) {
    final Map<String, List<PettyCashRequest>> siteRequestsMap = {};
    final Map<String, List<PettyCashTransaction>> siteTransactionsMap = {};
    final Map<String, String> siteNameMap = {};
    final Map<String, String> siteProjectMap = {};
    final Map<String, String> siteSupervisorIdMap = {};
    final Map<String, String> siteSupervisorNameMap = {};
    final Map<String, String> siteManagerIdMap = {};
    final Map<String, String> siteManagerNameMap = {};

    final cleanSiteFilter = (siteFilter ?? '').trim().toLowerCase();
    final cleanSupFilter = (supervisorFilter ?? '').trim().toLowerCase();
    final cleanProjFilter = (projectFilter ?? '').trim().toLowerCase();
    final cleanCatFilter = (categoryFilter ?? '').trim().toLowerCase();

    // 1. Group Requests by Site
    for (final req in requests) {
      final rawSite = (req.siteId ?? '').trim();
      if (rawSite.isEmpty) continue;
      final siteKey = ExpenseService.formatCanonicalSiteId(
        rawId: rawSite,
        siteName: req.siteName,
      );

      // Apply site filter
      if (cleanSiteFilter.isNotEmpty &&
          siteKey.toLowerCase() != cleanSiteFilter &&
          (req.siteName ?? '').toLowerCase() != cleanSiteFilter &&
          !siteKey.toLowerCase().contains(cleanSiteFilter)) {
        continue;
      }

      // Apply supervisor filter
      if (cleanSupFilter.isNotEmpty &&
          req.supervisorId.toLowerCase() != cleanSupFilter &&
          req.supervisorName.toLowerCase() != cleanSupFilter &&
          !req.supervisorName.toLowerCase().contains(cleanSupFilter)) {
        continue;
      }

      // Apply project filter
      if (cleanProjFilter.isNotEmpty &&
          (req.projectId ?? '').toLowerCase() != cleanProjFilter &&
          (req.projectName ?? '').toLowerCase() != cleanProjFilter &&
          !(req.projectName ?? '').toLowerCase().contains(cleanProjFilter)) {
        continue;
      }

      siteRequestsMap.putIfAbsent(siteKey, () => []).add(req);
      if (req.siteName != null && req.siteName!.isNotEmpty) {
        siteNameMap[siteKey] = req.siteName!;
      }
      if (req.projectName != null && req.projectName!.isNotEmpty) {
        siteProjectMap[siteKey] = req.projectName!;
      }
      if (req.supervisorId.isNotEmpty) {
        siteSupervisorIdMap[siteKey] = req.supervisorId;
        siteSupervisorNameMap[siteKey] = req.supervisorName;
      }
      if (req.managerName.isNotEmpty) {
        siteManagerIdMap[siteKey] = req.managerId;
        siteManagerNameMap[siteKey] = req.managerName;
      }
    }

    // 2. Group Transactions by Site
    for (final t in transactions) {
      final rawSite = (t.siteId ?? '').trim();
      if (rawSite.isEmpty) continue;
      final siteKey = ExpenseService.formatCanonicalSiteId(
        rawId: rawSite,
        siteName: t.siteName,
      );

      // Apply site filter
      if (cleanSiteFilter.isNotEmpty &&
          siteKey.toLowerCase() != cleanSiteFilter &&
          (t.siteName ?? '').toLowerCase() != cleanSiteFilter &&
          !siteKey.toLowerCase().contains(cleanSiteFilter)) {
        continue;
      }

      // Apply supervisor filter
      if (cleanSupFilter.isNotEmpty &&
          t.supervisorId.toLowerCase() != cleanSupFilter &&
          t.supervisorName.toLowerCase() != cleanSupFilter &&
          !t.supervisorName.toLowerCase().contains(cleanSupFilter)) {
        continue;
      }

      // Apply project filter
      if (cleanProjFilter.isNotEmpty &&
          (t.projectId ?? '').toLowerCase() != cleanProjFilter &&
          (t.projectName ?? '').toLowerCase() != cleanProjFilter &&
          !(t.projectName ?? '').toLowerCase().contains(cleanProjFilter)) {
        continue;
      }

      // Apply category filter
      if (cleanCatFilter.isNotEmpty &&
          cleanCatFilter != 'all' &&
          t.expenseCategory.toLowerCase() != cleanCatFilter &&
          !t.expenseCategory.toLowerCase().contains(cleanCatFilter)) {
        continue;
      }

      // Apply date range filter
      if (fromDate != null) {
        final startOfFromDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (t.transactionDate.isBefore(startOfFromDate)) continue;
      }
      if (toDate != null) {
        final endOfToDate = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
        if (t.transactionDate.isAfter(endOfToDate)) continue;
      }

      siteTransactionsMap.putIfAbsent(siteKey, () => []).add(t);
      if (t.siteName != null && t.siteName!.isNotEmpty && !siteNameMap.containsKey(siteKey)) {
        siteNameMap[siteKey] = t.siteName!;
      }
      if (t.projectName != null && t.projectName!.isNotEmpty && !siteProjectMap.containsKey(siteKey)) {
        siteProjectMap[siteKey] = t.projectName!;
      }
      if (t.supervisorId.isNotEmpty && !siteSupervisorIdMap.containsKey(siteKey)) {
        siteSupervisorIdMap[siteKey] = t.supervisorId;
        siteSupervisorNameMap[siteKey] = t.supervisorName;
      }
      if (t.managerName.isNotEmpty && !siteManagerNameMap.containsKey(siteKey)) {
        siteManagerIdMap[siteKey] = t.managerId;
        siteManagerNameMap[siteKey] = t.managerName;
      }
    }

    final Set<String> allSiteKeys = {
      ...siteRequestsMap.keys,
      ...siteTransactionsMap.keys,
    };

    final List<SitePettyCashSummary> summaries = [];

    for (final siteKey in allSiteKeys) {
      final siteReqs = siteRequestsMap[siteKey] ?? [];
      final siteTxns = siteTransactionsMap[siteKey] ?? [];

      // Calculate total allocated / received from confirmed requests
      double totalReceived = 0.0;
      for (final r in siteReqs) {
        if (r.isReceived) {
          final alloc = r.approvedAmount > 0
              ? r.approvedAmount
              : (r.allocatedAmount > 0 ? r.allocatedAmount : r.requestedAmount);
          totalReceived += alloc;
        }
      }

      // Calculate total expenses & other expenses from transactions
      double totalExpenses = 0.0;
      double otherExpenses = 0.0;
      DateTime? lastActivity;

      for (final t in siteTxns) {
        if (t.isExpense) {
          totalExpenses += t.amount;
          if (t.isOtherExpense) {
            otherExpenses += t.amount;
          }
        }
        if (lastActivity == null || t.transactionDate.isAfter(lastActivity)) {
          lastActivity = t.transactionDate;
        }
      }

      // If transactions are empty but request has spent, use request totalSpent
      if (totalExpenses == 0 && siteReqs.isNotEmpty) {
        for (final r in siteReqs) {
          if (r.totalSpent > 0) {
            totalExpenses += r.totalSpent;
          }
        }
      }

      final remaining = (totalReceived - totalExpenses).clamp(0.0, double.infinity);

      String status = 'Active';
      if (totalReceived <= 0) {
        status = siteReqs.isNotEmpty ? 'Pending Receipt' : 'No Allocation';
      } else if (remaining <= 0) {
        status = 'Fully Utilized';
      } else if (remaining <= (totalReceived * 0.1)) {
        status = 'Low Balance';
      }

      final siteDisplayName = siteNameMap[siteKey] ?? siteKey;
      final projDisplayName = siteProjectMap[siteKey];
      final supId = siteSupervisorIdMap[siteKey] ?? (siteReqs.isNotEmpty ? siteReqs.first.supervisorId : '');
      final supName = siteSupervisorNameMap[siteKey] ?? (siteReqs.isNotEmpty ? siteReqs.first.supervisorName : 'Supervisor');
      final mgrId = siteManagerIdMap[siteKey] ?? (siteReqs.isNotEmpty ? siteReqs.first.managerId : '');
      final mgrName = siteManagerNameMap[siteKey] ?? (siteReqs.isNotEmpty ? siteReqs.first.managerName : 'Manager');

      summaries.add(SitePettyCashSummary(
        siteId: siteKey,
        siteName: siteDisplayName,
        projectId: projDisplayName != null ? siteKey : null,
        projectName: projDisplayName,
        supervisorId: supId,
        supervisorName: supName,
        managerId: mgrId,
        managerName: mgrName,
        totalReceived: totalReceived,
        totalExpenses: totalExpenses,
        otherExpenses: otherExpenses,
        remainingBalance: remaining,
        transactionCount: siteTxns.where((t) => t.isExpense).length,
        allocationCount: siteReqs.where((r) => r.isReceived).length,
        lastActivityAt: lastActivity ?? (siteReqs.isNotEmpty ? siteReqs.first.receivedAt : null),
        status: status,
        allocations: siteReqs,
        transactions: siteTxns,
      ));
    }

    // Sort by remaining balance descending or site name
    summaries.sort((a, b) => b.totalReceived.compareTo(a.totalReceived));
    return summaries;
  }
}

