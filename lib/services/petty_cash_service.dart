import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_models.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'approval_workflow_service.dart';
import 'offline_sync_service.dart';
import 'expense_service.dart';

/// Central production-grade engine managing Site-Based Petty Cash,
/// Multi-Tier Approvals, Ledger Transactions, Two-Stage Expenses,
/// Cash Reconciliation, Cash Returns, and Audit Logs.
class PettyCashService {
  static final PettyCashService _instance = PettyCashService._internal();
  factory PettyCashService() => _instance;
  PettyCashService._internal();

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static String formatCurrency(num amount) {
    return _currencyFormat.format(amount);
  }

  /// Default threshold above which physical bill / receipt upload is mandatory
  static const double defaultReceiptThreshold = 500.0;

  // ---------------------------------------------------------------------------
  // 1. SITE-BASED & SUPERVISOR ACCOUNT RESOLUTION
  // ---------------------------------------------------------------------------

  /// Helper to generate standard site account ID format: `{orgId}_{siteId}`
  static String formatSiteAccountId(String orgId, String siteId) {
    final cleanOrg = orgId.trim();
    final cleanSite = siteId.trim();
    return '${cleanOrg}_$cleanSite';
  }

  /// Streams the real-time site petty cash account data.
  Stream<PettyCashAccount?> streamSiteAccount(String siteId) {
    final cleanSite = siteId.trim();
    final siteAccId = formatSiteAccountId(FirestoreService.currentOrgId, cleanSite);

    return FirestoreService.pettyCashAccounts.doc(siteAccId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return PettyCashAccount.fromMap(doc.id, doc.data()!);
      }
      return null;
    });
  }

  /// Streams account data for a specific supervisor (with site fallback).
  Stream<PettyCashAccount?> streamAccount(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashAccounts.snapshots().map((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sId = (data['custodianSupervisorId'] ?? data['supervisorId'] ?? doc.id).toString().trim().toLowerCase();
        if (sId == cleanId || doc.id.toLowerCase() == cleanId) {
          return PettyCashAccount.fromMap(doc.id, data);
        }
      }
      return null;
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

  /// Fetches or initializes a Site-Based Petty Cash Account.
  Future<PettyCashAccount> getOrCreateSiteAccount({
    required String siteId,
    required String siteName,
    required String supervisorId,
    required String supervisorName,
    String? managerId,
    String? managerName,
    double fundLimit = 0.0,
    double configuredMinimumBalance = 0.0,
  }) async {
    final orgId = FirestoreService.currentOrgId;
    final cleanSite = siteId.trim();
    final siteAccId = formatSiteAccountId(orgId, cleanSite);
    final docRef = FirestoreService.pettyCashAccounts.doc(siteAccId);
    final snap = await docRef.get();

    if (snap.exists && snap.data() != null) {
      return PettyCashAccount.fromMap(snap.id, snap.data()!);
    }

    // Check if legacy supervisor account exists
    final legacyRef = FirestoreService.pettyCashAccounts.doc(supervisorId.trim().toLowerCase());
    final legacySnap = await legacyRef.get();
    double initAlloc = 0.0;
    double initUsed = 0.0;
    double initAvail = 0.0;
    if (legacySnap.exists && legacySnap.data() != null) {
      final lData = legacySnap.data()!;
      initAlloc = (lData['totalAllocated'] is num) ? (lData['totalAllocated'] as num).toDouble() : 0.0;
      initUsed = (lData['totalUsed'] is num) ? (lData['totalUsed'] as num).toDouble() : 0.0;
      initAvail = (lData['availableBalance'] is num) ? (lData['availableBalance'] as num).toDouble() : (initAlloc - initUsed);
    }

    final newAccount = PettyCashAccount(
      accountId: siteAccId,
      orgId: orgId,
      siteId: cleanSite,
      siteName: siteName.isNotEmpty ? siteName : cleanSite,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: managerId ?? '',
      managerName: managerName ?? '',
      custodianSupervisorId: supervisorId,
      custodianSupervisorName: supervisorName,
      totalAllocated: initAlloc,
      totalReceived: initAlloc,
      totalUsed: initUsed,
      totalSpent: initUsed,
      totalReturned: 0.0,
      availableBalance: initAvail,
      reservedBalance: 0.0,
      postedExpenseBalance: initUsed,
      fundLimit: fundLimit > 0 ? fundLimit : initAlloc,
      configuredMinimumBalance: configuredMinimumBalance,
      lowBalanceThresholdPercent: 10.0,
      lowBalanceTriggered: false,
      currentCycleAllocated: initAlloc,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newAccount.toMap(), SetOptions(merge: true));
    return newAccount;
  }

  /// Backward-compatible account resolver.
  Future<PettyCashAccount> getOrCreateAccount({
    required String supervisorId,
    required String supervisorName,
    String? managerId,
    String? managerName,
    String? siteId,
    String? siteName,
  }) async {
    if (siteId != null && siteId.trim().isNotEmpty) {
      return getOrCreateSiteAccount(
        siteId: siteId,
        siteName: siteName ?? siteId,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        managerId: managerId,
        managerName: managerName,
      );
    }

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
      custodianSupervisorId: supervisorId,
      custodianSupervisorName: supervisorName,
      totalAllocated: 0.0,
      totalReceived: 0.0,
      totalUsed: 0.0,
      totalSpent: 0.0,
      totalReturned: 0.0,
      availableBalance: 0.0,
      reservedBalance: 0.0,
      postedExpenseBalance: 0.0,
      lowBalanceThresholdPercent: 10.0,
      lowBalanceTriggered: false,
      currentCycleAllocated: 0.0,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newAccount.toMap(), SetOptions(merge: true));
    return newAccount;
  }

  // ---------------------------------------------------------------------------
  // 2. ASSIGNED SITES & PENDING PAYMENTS RESOLUTION
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

  /// Fetches pending site payment requisitions to link to petty cash.
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

      final snaps = await Future.wait([
        FirestoreService.getCollection('siteSupervisorEntries').get(),
        FirestoreService.getCollection('siteSupervisorPayments').get(),
      ]);

      final entriesSnap = snaps[0];
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

      final paymentsSnap = snaps[1];
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
  // 3. STATUS TRANSITION VALIDATION & CANONICAL GUARDS
  // ---------------------------------------------------------------------------

  /// Strictly validates status transitions and prevents illegal jumps or self-approvals.
  void validateStatusTransition({
    required String currentStatus,
    required String targetStatus,
    required String actorRole,
    required String actorId,
    required String requesterId,
    String? rejectionReason,
  }) {
    final cur = PettyCashStatus.normalize(currentStatus);
    final tgt = PettyCashStatus.normalize(targetStatus);

    // Self-approval guard
    if ((tgt == PettyCashStatus.approved ||
         tgt == PettyCashStatus.pendingOrgApproval ||
         tgt == PettyCashStatus.expenseApproved ||
         tgt == PettyCashStatus.disbursed) &&
        actorId.isNotEmpty &&
        actorId.trim().toLowerCase() == requesterId.trim().toLowerCase()) {
      throw Exception('Separation of duties violation: You cannot approve your own request or expense.');
    }

    // Mandatory rejection reason guard
    if ((tgt == PettyCashStatus.rejectedByManager ||
         tgt == PettyCashStatus.rejectedByOrg ||
         tgt == PettyCashStatus.expenseRejected) &&
        (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      throw Exception('Rejection reason is mandatory.');
    }

    // Valid state transitions graph
    final validTransitions = {
      PettyCashStatus.draft: [PettyCashStatus.submitted, PettyCashStatus.pendingManagerReview, PettyCashStatus.cancelled],
      PettyCashStatus.submitted: [PettyCashStatus.pendingManagerReview, PettyCashStatus.pendingOrgApproval, PettyCashStatus.rejectedByManager, PettyCashStatus.cancelled],
      PettyCashStatus.pendingManagerReview: [PettyCashStatus.pendingOrgApproval, PettyCashStatus.approved, PettyCashStatus.rejectedByManager, PettyCashStatus.cancelled],
      PettyCashStatus.pendingOrgApproval: [PettyCashStatus.approved, PettyCashStatus.awaitingDisbursement, PettyCashStatus.disbursed, PettyCashStatus.awaitingReceiptConfirmation, PettyCashStatus.rejectedByOrg, PettyCashStatus.cancelled],
      PettyCashStatus.approved: [PettyCashStatus.awaitingDisbursement, PettyCashStatus.disbursed, PettyCashStatus.awaitingReceiptConfirmation, PettyCashStatus.cancelled],
      PettyCashStatus.awaitingDisbursement: [PettyCashStatus.disbursed, PettyCashStatus.awaitingReceiptConfirmation, PettyCashStatus.cancelled],
      PettyCashStatus.disbursed: [PettyCashStatus.awaitingReceiptConfirmation, PettyCashStatus.received, PettyCashStatus.active],
      PettyCashStatus.awaitingReceiptConfirmation: [PettyCashStatus.received, PettyCashStatus.active],
      PettyCashStatus.received: [PettyCashStatus.active, PettyCashStatus.closed],
      PettyCashStatus.active: [PettyCashStatus.replenishmentRequested, PettyCashStatus.reconciliationPending, PettyCashStatus.closed],
      PettyCashStatus.pendingExpenseReview: [PettyCashStatus.expenseApproved, PettyCashStatus.expenseRejected],
      PettyCashStatus.reconciliationPending: [PettyCashStatus.reconciliationApproved, PettyCashStatus.discrepancyReview],
      PettyCashStatus.discrepancyReview: [PettyCashStatus.reconciliationApproved, PettyCashStatus.closed],
    };

    final allowed = validTransitions[cur] ?? [];
    if (!allowed.contains(tgt) && cur != tgt) {
      throw Exception('Invalid status transition from "$cur" to "$tgt".');
    }
  }

  // ---------------------------------------------------------------------------
  // 4. REQUEST LIFECYCLE: SUBMISSION, REVIEW, APPROVAL, DISBURSEMENT & RECEIPT
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
    bool isSiteExpense = true,
    String? expenseType,
    String? expenseCategory,
    DateTime? requiredDate,
    String? documentUrl,
    String? projectId,
    String? projectName,
    String? siteId,
    String? siteName,
    String? siteCode,
    String? linkedSitePaymentId,
    String? linkedSitePaymentTitle,
  }) async {
    if (requestedAmount <= 0) {
      throw Exception('Requested amount must be greater than zero.');
    }

    final bool isOther = !isSiteExpense || expenseType == 'other';
    if (!isOther && (siteId == null || siteId.trim().isEmpty)) {
      throw Exception('Site selection is mandatory for site-wise petty cash requests.');
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
              resolvedManagerId = (data['managerId'] ?? data['manager_id'] ?? '').toString().trim();
            }
            if (resolvedManagerName.isEmpty) {
              resolvedManagerName = (data['manager'] ?? data['managerName'] ?? '').toString().trim();
            }
            if (resolvedManagerId.isNotEmpty) break;
          }
        }
      } catch (_) {}
    }

    final PettyCashAccount account = isOther
        ? await getOrCreateAccount(
            supervisorId: supervisorId,
            supervisorName: supervisorName,
            managerId: resolvedManagerId,
            managerName: resolvedManagerName,
          )
        : await getOrCreateSiteAccount(
            siteId: siteId!,
            siteName: siteName ?? '',
            supervisorId: supervisorId,
            supervisorName: supervisorName,
            managerId: resolvedManagerId,
            managerName: resolvedManagerName,
          );

    final reqDocId = 'PCR_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';
    final requestType = isOther
        ? 'OTHER_EXPENSE'
        : (isReplenishment ? 'REPLENISHMENT' : 'INITIAL_ALLOCATION');

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: isOther
          ? '1. Other Expense Request'
          : (isReplenishment ? '1. Replenishment Request' : '1. Supervisor Submission'),
      action: isOther
          ? 'Other Expense Requested'
          : (isReplenishment ? 'Replenishment Requested' : 'Petty Cash Requested'),
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
      projectId: isOther ? null : projectId,
      projectName: isOther ? null : projectName,
      siteId: isOther ? null : siteId,
      siteName: isOther ? null : siteName,
      siteCode: isOther ? null : siteCode,
      isSiteExpense: !isOther,
      expenseType: isOther ? 'other' : (expenseType ?? 'site'),
      expenseCategory: expenseCategory,
      requiredDate: requiredDate,
      documentUrl: documentUrl,
      requestedAmount: requestedAmount,
      approvedAmount: 0.0,
      disbursedAmount: 0.0,
      allocatedAmount: 0.0,
      receivedAmount: 0.0,
      totalSpent: 0.0,
      remainingBalance: 0.0,
      reason: reason,
      remarks: remarks ?? '',
      status: PettyCashStatus.pendingManagerReview,
      statusDisplay: PettyCashStatus.getDisplayLabel(PettyCashStatus.pendingManagerReview),
      currentStep: 1,
      currentBalanceAtRequest: account.availableBalance,
      totalAllocatedAtRequest: account.totalAllocated,
      totalUsedAtRequest: account.totalUsed,
      linkedSitePaymentId: isOther ? null : linkedSitePaymentId,
      linkedSitePaymentTitle: isOther ? null : linkedSitePaymentTitle,
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

    await _writeAuditLog(
      action: isOther
          ? 'OTHER_EXPENSE_REQUESTED'
          : (isReplenishment ? 'REPLENISHMENT_REQUESTED' : 'REQUEST_CREATED'),
      entityType: 'REQUEST',
      entityId: reqDocId,
      actorId: supervisorId,
      actorName: supervisorName,
      actorRole: 'Supervisor',
      organizationId: orgId,
      siteId: siteId,
      newState: request.toMap(),
    );

    final formattedAmt = formatCurrency(requestedAmount);
    final title = isReplenishment
        ? '🔄 Petty Cash Replenishment Request'
        : '💰 New Petty Cash Request';
    final body = '$supervisorName requested $formattedAmt for site $siteName. Reason: $reason';

    await NotificationService.notifyManagerAndOrganisation(
      title: title,
      body: body,
      requestType: 'petty_cash',
      requestId: reqDocId,
      docId: reqDocId,
      status: PettyCashStatus.pendingManagerReview,
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

  /// Manager proactively creates manual petty cash allocation.
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

    final orgId = FirestoreService.currentOrgId;
    final account = await getOrCreateSiteAccount(
      siteId: siteId,
      siteName: siteName,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      managerId: managerId,
      managerName: managerName,
    );

    final reqDocId = 'PCM_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';

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
      disbursedAmount: 0.0,
      allocatedAmount: amount,
      receivedAmount: 0.0,
      totalSpent: 0.0,
      remainingBalance: 0.0,
      reason: reason,
      remarks: remarks ?? '',
      status: PettyCashStatus.pendingOrgApproval,
      statusDisplay: PettyCashStatus.getDisplayLabel(PettyCashStatus.pendingOrgApproval),
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
      organizationId: orgId,
      siteId: siteId,
      newState: requestMap,
    );

    final formattedAmt = formatCurrency(amount);
    await NotificationService.notifyOrganisation(
      title: '🏢 Manual Petty Cash Awaiting Approval',
      body: 'Manager $managerName initiated $formattedAmt manual petty cash for $supervisorName on site $siteName. HQ approval required.',
      requestType: 'petty_cash',
      requestId: reqDocId,
      docId: reqDocId,
      status: PettyCashStatus.pendingOrgApproval,
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

    if (siteId.trim().isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(siteId.trim()).catchError((e) {
        debugPrint('Error syncing site totals on manual manager allocation: $e');
      });
    }

    return reqDocId;
  }

  /// Manager verifies and forwards request to HQ.
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

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    validateStatusTransition(
      currentStatus: req.status,
      targetStatus: PettyCashStatus.pendingOrgApproval,
      actorRole: 'Manager',
      actorId: managerId ?? req.managerId,
      requesterId: req.supervisorId,
    );

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '2. Manager Review',
      action: 'Verified & Forwarded to HQ',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: remarks.isNotEmpty ? remarks : 'Verified and forwarded for HQ approval.',
    );

    final updates = {
      'status': PettyCashStatus.pendingOrgApproval,
      'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.pendingOrgApproval),
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
      organizationId: req.orgId,
      siteId: req.siteId,
      previousState: {'status': req.status},
      newState: updates,
    );

    final formattedAmt = formatCurrency(req.requestedAmount);
    await NotificationService.notifyOrganisation(
      title: '🏢 Petty Cash Request Awaiting Authorization',
      body: 'Manager $managerName verified $formattedAmt petty cash request for ${req.supervisorName}. Remarks: $remarks',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.pendingOrgApproval,
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

  /// Manager rejects the request during review.
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

    validateStatusTransition(
      currentStatus: req.status,
      targetStatus: PettyCashStatus.rejectedByManager,
      actorRole: 'Manager',
      actorId: managerId ?? req.managerId,
      requesterId: req.supervisorId,
      rejectionReason: reason,
    );

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '2. Manager Review',
      action: 'Rejected by Manager',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: reason,
    );

    final updates = {
      'status': PettyCashStatus.rejectedByManager,
      'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.rejectedByManager),
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
      organizationId: req.orgId,
      siteId: req.siteId,
      previousState: {'status': req.status},
      newState: updates,
    );

    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '❌ Petty Cash Request Declined',
      body: 'Your petty cash request for ${formatCurrency(req.requestedAmount)} was declined by Manager $managerName. Reason: $reason',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.rejectedByManager,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: reason,
      requiredAction: 'Action Required: Revise or Close Request',
    );
  }

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

    validateStatusTransition(
      currentStatus: req.status,
      targetStatus: PettyCashStatus.awaitingReceiptConfirmation,
      actorRole: 'Organization',
      actorId: orgUserId ?? 'org',
      requesterId: req.supervisorId,
    );

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Authorized by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks: 'Approved ${formatCurrency(approvedAmount)}. Remarks: ${remarks.isNotEmpty ? remarks : 'Approved by HQ.'}',
    );

    final updates = {
      'status': PettyCashStatus.awaitingReceiptConfirmation,
      'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.awaitingReceiptConfirmation),
      'currentStep': 4,
      'approvedAmount': approvedAmount,
      'allocatedAmount': approvedAmount,
      'disbursedAmount': approvedAmount,
      'disbursedBy': orgUserName,
      'disbursedAt': FieldValue.serverTimestamp(),
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
      organizationId: req.orgId,
      siteId: req.siteId,
      previousState: {'status': req.status},
      newState: updates,
    );

    final formattedAmt = formatCurrency(approvedAmount);
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '💵 Petty Cash Approved – Confirm Receipt',
      body: 'HQ approved $formattedAmt petty cash for site ${req.siteName ?? ""}. Please confirm once you have physically received the cash.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.awaitingReceiptConfirmation,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
      requiredAction: 'Action Required: Confirm Physical Cash Receipt',
      extraData: {
        'approvedAmount': approvedAmount,
        'allocatedAmount': approvedAmount,
        'disbursedAmount': approvedAmount,
        'supervisorName': req.supervisorName,
        'supervisorId': req.supervisorId,
        'siteId': req.siteId,
        'siteName': req.siteName,
      },
    );

    await NotificationService.notifyManager(
      title: '✅ Petty Cash Authorized by HQ',
      body: 'HQ authorized $formattedAmt for ${req.supervisorName} on site ${req.siteName ?? ""}. Awaiting supervisor confirmation.',
      forManagerName: req.managerName,
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.awaitingReceiptConfirmation,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
    );

    if (req.siteId != null && req.siteId!.trim().isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(req.siteId!.trim()).catchError((e) {
        debugPrint('Error syncing site totals on org approval: $e');
      });
    }
  }

  /// Organization rejects the request with mandatory reason.
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

    validateStatusTransition(
      currentStatus: req.status,
      targetStatus: PettyCashStatus.rejectedByOrg,
      actorRole: 'Organization',
      actorId: orgUserId ?? 'org',
      requesterId: req.supervisorId,
      rejectionReason: reason,
    );

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Rejected by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks: reason,
    );

    final updates = {
      'status': PettyCashStatus.rejectedByOrg,
      'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.rejectedByOrg),
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
      organizationId: req.orgId,
      siteId: req.siteId,
      previousState: {'status': req.status},
      newState: updates,
    );

    await NotificationService.notifyManager(
      title: '❌ Petty Cash Rejected by HQ',
      body: 'Petty cash request #$requestId for ${req.supervisorName} was rejected by HQ. Reason: $reason',
      forManagerName: req.managerName,
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.rejectedByOrg,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: reason,
    );

    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '❌ Petty Cash Rejected by HQ',
      body: 'Your petty cash request for ${formatCurrency(req.requestedAmount)} was declined by HQ. Reason: $reason',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.rejectedByOrg,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: reason,
    );
  }

  /// Manager disburses cash for an approved request.
  Future<void> managerDisburseCash({
    required String requestId,
    required String managerName,
    String? managerId,
    required double disbursementAmount,
    String? remarks,
  }) async {
    if (disbursementAmount <= 0) {
      throw Exception('Disbursement amount must be greater than zero.');
    }

    final docRef = FirestoreService.pettyCashRequests.doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Request #$requestId not found.');
    }

    final req = PettyCashRequest.fromMap(requestId, snap.data()!);

    final auditEntry = ApprovalWorkflowService.createAuditEntry(
      step: '4. Manager Fund Disbursement',
      action: 'Cash Disbursed by Manager',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: 'Disbursed ${formatCurrency(disbursementAmount)}. Remarks: ${remarks ?? ''}',
    );

    final updates = {
      'status': PettyCashStatus.awaitingReceiptConfirmation,
      'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.awaitingReceiptConfirmation),
      'currentStep': 4,
      'disbursedAmount': disbursementAmount,
      'allocatedAmount': disbursementAmount,
      'disbursedBy': managerName,
      'disbursedAt': FieldValue.serverTimestamp(),
      'allocatedBy': managerName,
      'allocatedAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    await _writeAuditLog(
      action: 'CASH_DISBURSED',
      entityType: 'REQUEST',
      entityId: requestId,
      actorId: managerId ?? '',
      actorName: managerName,
      actorRole: 'Manager',
      organizationId: req.orgId,
      siteId: req.siteId,
      previousState: {'status': req.status},
      newState: updates,
    );

    final formattedAmt = formatCurrency(disbursementAmount);
    await NotificationService.notifySupervisor(
      supervisorName: req.supervisorName,
      supervisorId: req.supervisorId,
      title: '💵 Petty Cash Disbursed – Confirm Receipt',
      body: 'Manager $managerName disbursed $formattedAmt petty cash for site ${req.siteName ?? ""}. Please confirm physical receipt.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.awaitingReceiptConfirmation,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: remarks,
      requiredAction: 'Action Required: Confirm Physical Cash Receipt',
    );

    if (req.siteId != null && req.siteId!.trim().isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(req.siteId!.trim()).catchError((e) {
        debugPrint('Error syncing site totals on manager disburse cash: $e');
      });
    }
  }

  /// Supervisor confirms physical receipt of cash (Idempotent & Atomic).
  Future<void> supervisorConfirmAmountReceived({
    required String requestId,
    required String supervisorId,
    required String supervisorName,
    String? remarks,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final reqRef = FirestoreService.pettyCashRequests.doc(requestId);

    late final double receivedAmt;
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
          reqData['status'] == PettyCashStatus.received ||
          reqData['status'] == PettyCashStatus.active ||
          reqData['status'] == 'received') {
        alreadyConfirmed = true;
        return;
      }

      receivedAmt = (reqData['disbursedAmount'] is num && (reqData['disbursedAmount'] as num) > 0)
          ? (reqData['disbursedAmount'] as num).toDouble()
          : (reqData['approvedAmount'] is num && (reqData['approvedAmount'] as num) > 0)
              ? (reqData['approvedAmount'] as num).toDouble()
              : (reqData['allocatedAmount'] is num && (reqData['allocatedAmount'] as num) > 0)
                  ? (reqData['allocatedAmount'] as num).toDouble()
                  : (reqData['requestedAmount'] as num).toDouble();

      if (receivedAmt <= 0) {
        throw Exception('Invalid allocated amount on request #$requestId.');
      }

      final isReplenishment = reqData['requestType'] == 'REPLENISHMENT';
      managerId = (reqData['managerId'] ?? '').toString();
      managerName = (reqData['disbursedBy'] ?? reqData['allocatedBy'] ?? reqData['managerName'] ?? 'Manager').toString();
      reqSiteId = reqData['siteId']?.toString();
      reqSiteName = reqData['siteName']?.toString();

      final orgId = FirestoreService.currentOrgId;
      final siteAccId = (reqSiteId != null && reqSiteId!.trim().isNotEmpty)
          ? formatSiteAccountId(orgId, reqSiteId!)
          : supervisorId.trim().toLowerCase();

      final accountRef = FirestoreService.pettyCashAccounts.doc(siteAccId);
      final accountSnap = await txn.get(accountRef);

      // Check linked site payment
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
      double prevReceived = 0.0;

      if (accountSnap.exists && accountSnap.data() != null) {
        final aData = accountSnap.data()!;
        prevAllocated = (aData['totalAllocated'] is num) ? (aData['totalAllocated'] as num).toDouble() : 0.0;
        prevReceived = (aData['totalReceived'] is num) ? (aData['totalReceived'] as num).toDouble() : prevAllocated;
        prevUsed = (aData['totalUsed'] is num) ? (aData['totalUsed'] as num).toDouble() : 0.0;
        prevAvailable = (aData['availableBalance'] is num)
            ? (aData['availableBalance'] as num).toDouble()
            : (prevAllocated - prevUsed);
        prevCycleAllocated = (aData['currentCycleAllocated'] is num)
            ? (aData['currentCycleAllocated'] as num).toDouble()
            : prevAllocated;
      }

      final newTotalAllocated = prevAllocated + receivedAmt;
      final newTotalReceived = prevReceived + receivedAmt;
      newAvailableBalance = prevAvailable + receivedAmt;
      final newCycleAllocated = isReplenishment ? (prevCycleAllocated + receivedAmt) : receivedAmt;

      txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}_RECV';

      final auditEntry = ApprovalWorkflowService.createAuditEntry(
        step: '5. Amount Received Confirmation',
        action: 'Amount Received Confirmed',
        actorRole: 'Supervisor',
        actorName: supervisorName,
        actorId: supervisorId,
        remarks: remarks ?? 'Physically received ${formatCurrency(receivedAmt)} in cash.',
      );

      // --- ALL WRITES PERFORMED HERE (AFTER ALL READS COMPLETED) ---

      // 1. Update Request Doc
      txn.update(reqRef, {
        'status': PettyCashStatus.received,
        'statusDisplay': PettyCashStatus.getDisplayLabel(PettyCashStatus.received),
        'currentStep': 5,
        'receivedAmount': receivedAmt,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBySupervisorId': supervisorId,
        'receivedBySupervisorName': supervisorName,
        'remainingBalance': receivedAmt,
        'totalSpent': 0.0,
        'approvalHistory': FieldValue.arrayUnion([auditEntry]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Site Account Doc
      txn.set(
        accountRef,
        {
          'accountId': siteAccId,
          'orgId': orgId,
          'organizationId': orgId,
          'siteId': reqSiteId ?? '',
          'siteName': reqSiteName ?? '',
          'supervisorId': supervisorId,
          'supervisorName': supervisorName,
          'custodianSupervisorId': supervisorId,
          'custodianSupervisorName': supervisorName,
          'managerId': managerId,
          'managerName': managerName,
          'totalAllocated': newTotalAllocated,
          'totalReceived': newTotalReceived,
          'totalUsed': prevUsed,
          'totalSpent': prevUsed,
          'availableBalance': newAvailableBalance,
          'lowBalanceThresholdPercent': 10.0,
          'lowBalanceTriggered': false,
          'currentCycleAllocated': newCycleAllocated,
          'currentCycleId': requestId,
          'status': 'ACTIVE',
          'lastTransactionAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3. Create Inflow Ledger Transaction
      final txnRef = FirestoreService.pettyCashTransactions.doc(txnId);
      final transactionRecord = PettyCashTransaction(
        transactionId: txnId,
        idempotencyKey: 'RECV_${requestId}_${receivedAmt.toInt()}',
        pettyCashId: requestId,
        referenceId: requestId,
        accountId: siteAccId,
        orgId: orgId,
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
        transactionType: isReplenishment ? 'REPLENISHMENT' : 'INITIAL_FUND',
        expenseCategory: isReplenishment ? 'Replenishment' : 'Initial Fund',
        description: isReplenishment
            ? 'Petty cash replenishment received and confirmed for site ${reqSiteName ?? ""}'
            : 'Initial petty cash fund received and confirmed for site ${reqSiteName ?? ""}',
        amount: receivedAmt,
        previousBalance: prevAvailable,
        newBalance: newAvailableBalance,
        remarks: remarks ?? 'Cash received physically.',
        status: 'POSTED',
        transactionDate: DateTime.now(),
        createdBy: supervisorName,
        createdRole: 'Supervisor',
        createdAt: DateTime.now(),
      );

      txn.set(txnRef, transactionRecord.toMap());

      // 4. Update linked Site Payment
      if (linkedDocRefToUpdate != null) {
        txn.update(linkedDocRefToUpdate, {
          'fundedViaPettyCash': true,
          'pettyCashRequestId': requestId,
          'pettyCashStatus': 'disbursed',
          'pettyCashConfirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. Audit Log
      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'CASH_RECEIPT_CONFIRMED',
        entityType: 'ACCOUNT',
        entityId: siteAccId,
        actorId: supervisorId,
        actorName: supervisorName,
        actorRole: 'Supervisor',
        organizationId: orgId,
        siteId: reqSiteId,
        previousState: {'availableBalance': prevAvailable, 'status': reqData['status']},
        newState: {'availableBalance': newAvailableBalance, 'receivedAmount': receivedAmt, 'status': 'RECEIVED'},
        metadata: {'requestId': requestId, 'txnId': txnId, 'siteId': reqSiteId ?? ''},
        timestamp: DateTime.now(),
      );

      txn.set(logRef, auditLog.toMap());
    });

    if (alreadyConfirmed) return;

    final formattedAmt = formatCurrency(receivedAmt);
    final formattedBal = formatCurrency(newAvailableBalance);
    await NotificationService.notifyManagerAndOrganisation(
      title: '🤝 Petty Cash Receipt Confirmed',
      body: 'Supervisor $supervisorName confirmed receipt of $formattedAmt petty cash for site ${reqSiteName ?? ""}. Available balance: $formattedBal.',
      requestType: 'petty_cash',
      requestId: requestId,
      docId: requestId,
      status: PettyCashStatus.received,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: remarks,
      requiredAction: 'Funds Active in Field',
      forSupervisorName: supervisorName,
      forSupervisorId: supervisorId,
      forManagerName: managerName.isNotEmpty ? managerName : null,
      extraData: {
        'receivedAmount': receivedAmt,
        'newBalance': newAvailableBalance,
        'supervisorId': supervisorId,
        'siteId': reqSiteId,
        'siteName': reqSiteName,
      },
    );

    if (reqSiteId != null && reqSiteId!.trim().isNotEmpty) {
      ExpenseService.recalcTotalsAndSyncProject(reqSiteId!.trim()).catchError((e) {
        debugPrint('Error syncing site financial details on petty cash receipt: $e');
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 5. TWO-STAGE EXPENSE LIFECYCLE (SUBMIT -> MANAGER APPROVE -> POST LEDGER)
  // ---------------------------------------------------------------------------

  /// Supervisor submits a new petty cash expense for Manager review.
  Future<PettyCashExpense> submitExpense({
    required String supervisorId,
    required String supervisorName,
    String? siteId,
    String? siteName,
    String? siteCode,
    String? expenseType,
    String? projectId,
    String? projectName,
    String? pettyCashId,
    String? requestId,
    String? managerId,
    String? managerName,
    String? category,
    String? expenseCategory,
    required String description,
    required double amount,
    String? vendorName,
    bool? isSiteExpense,
    String? remarks,
    String? receiptUrl,
    String? receiptFileName,
    String? noReceiptReason,
    DateTime? transactionDate,
    DateTime? expenseDate,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Expense amount must be greater than zero.');
    }
    if (description.trim().isEmpty) {
      throw Exception('Description is required for all petty cash expenses.');
    }

    final resolvedExpenseType = (expenseType ?? ((isSiteExpense == false || (siteId == null || siteId.trim().isEmpty || siteId.trim() == 'NON_SITE_EXPENSES')) ? 'other' : 'site')).toLowerCase();
    final bool isSite = resolvedExpenseType == 'site' && (isSiteExpense ?? true);

    final resolvedCategory = (category ?? expenseCategory ?? 'Office & Site Supplies').trim();
    final resolvedSiteId = isSite ? (siteId ?? '').trim() : '';
    final resolvedSiteName = isSite ? (siteName ?? resolvedSiteId).trim() : '';
    final resolvedSiteCode = isSite ? siteCode?.trim() : null;

    final bool receiptMandatory = amount >= defaultReceiptThreshold;
    if (receiptMandatory && (receiptUrl == null || receiptUrl.trim().isEmpty)) {
      if (noReceiptReason == null || noReceiptReason.trim().isEmpty) {
        throw Exception(
          'A receipt is mandatory for expenses of ${formatCurrency(defaultReceiptThreshold)} or above. '
          'Please upload a receipt photo or provide a clear written explanation.',
        );
      }
    }

    final orgId = FirestoreService.currentOrgId;

    // Account resolution
    DocumentReference<Map<String, dynamic>> accountRef;
    PettyCashAccount? account;

    if (isSite && resolvedSiteId.isNotEmpty) {
      final siteAccId = formatSiteAccountId(orgId, resolvedSiteId);
      accountRef = FirestoreService.pettyCashAccounts.doc(siteAccId);
      final accountSnap = await accountRef.get();
      if (accountSnap.exists && accountSnap.data() != null) {
        account = PettyCashAccount.fromMap(accountSnap.id, accountSnap.data()!);
      } else {
        // Fallback: Check if supervisor has an account
        final supAcc = await getOrCreateSiteAccount(
          siteId: resolvedSiteId,
          siteName: resolvedSiteName,
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          managerId: managerId,
          managerName: managerName,
        );
        account = supAcc;
      }
    } else {
      // Non-site / Supervisor personal expense
      final cleanSupId = supervisorId.trim().toLowerCase();
      final supDocRef = FirestoreService.pettyCashAccounts.doc(cleanSupId);
      final supSnap = await supDocRef.get();
      if (supSnap.exists && supSnap.data() != null) {
        accountRef = supDocRef;
        account = PettyCashAccount.fromMap(supSnap.id, supSnap.data()!);
      } else {
        // Check if there's any active account where supervisor is custodian
        final allAccountsSnap = await FirestoreService.pettyCashAccounts.get();
        DocumentSnapshot<Map<String, dynamic>>? bestDoc;
        double maxSpendable = -1;

        for (final doc in allAccountsSnap.docs) {
          final data = doc.data();
          final sId = (data['custodianSupervisorId'] ?? data['supervisorId'] ?? doc.id).toString().trim().toLowerCase();
          if (sId == cleanSupId || doc.id.toLowerCase() == cleanSupId) {
            final a = PettyCashAccount.fromMap(doc.id, data);
            if (a.spendableBalance > maxSpendable) {
              maxSpendable = a.spendableBalance;
              bestDoc = doc;
            }
          }
        }

        if (bestDoc != null) {
          accountRef = bestDoc.reference;
          account = PettyCashAccount.fromMap(bestDoc.id, bestDoc.data()!);
        } else {
          accountRef = supDocRef;
          account = await getOrCreateAccount(
            supervisorId: supervisorId,
            supervisorName: supervisorName,
            managerId: managerId,
            managerName: managerName,
          );
        }
      }
    }

    if (amount > account.spendableBalance) {
      final avail = formatCurrency(account.availableBalance);
      final res = formatCurrency(account.reservedBalance);
      final spend = formatCurrency(account.spendableBalance);
      throw Exception(
        'Insufficient spendable balance. Available: $avail, Reserved: $res, Spendable: $spend. Please request fund replenishment first.',
      );
    }

    final safeIdempotencyKey = idempotencyKey?.trim().isNotEmpty == true
        ? idempotencyKey!.trim()
        : 'EXP_${supervisorId}_${DateTime.now().millisecondsSinceEpoch}_${amount.toInt()}';

    final expDocId = 'EXP_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';
    final now = DateTime.now();
    final effectiveDate = transactionDate ?? expenseDate ?? now;
    final effectiveReqId = pettyCashId ?? requestId;

    final expense = PettyCashExpense(
      expenseId: expDocId,
      idempotencyKey: safeIdempotencyKey,
      accountId: accountRef.id,
      orgId: orgId,
      siteId: isSite && resolvedSiteId.isNotEmpty ? resolvedSiteId : null,
      siteName: isSite && resolvedSiteName.isNotEmpty ? resolvedSiteName : null,
      siteCode: isSite ? resolvedSiteCode : null,
      expenseType: isSite ? 'site' : 'other',
      pettyCashId: effectiveReqId,
      submittedBy: supervisorId,
      submittedByName: supervisorName,
      managerId: managerId ?? account.managerId,
      managerName: managerName ?? account.managerName,
      amount: amount,
      category: resolvedCategory,
      description: description,
      vendorName: vendorName,
      receiptUrl: receiptUrl,
      receiptFileName: receiptFileName,
      receiptUploadedAt: receiptUrl != null ? now : null,
      receiptRequired: receiptMandatory,
      noReceiptReason: noReceiptReason,
      receiptVerified: false,
      status: PettyCashStatus.pendingExpenseReview,
      postedToLedger: false,
      transactionDate: effectiveDate,
      isSiteExpenseOverride: isSite,
      createdAt: now,
      updatedAt: now,
    );

    // Atomically save expense and update account reserved balance
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final aSnap = await txn.get(accountRef);
      double currentReserved = 0.0;
      if (aSnap.exists && aSnap.data() != null) {
        currentReserved = (aSnap.data()!['reservedBalance'] is num)
            ? (aSnap.data()!['reservedBalance'] as num).toDouble()
            : 0.0;
      }

      txn.set(FirestoreService.pettyCashExpenses.doc(expDocId), expense.toMap());
      txn.update(accountRef, {
        'reservedBalance': currentReserved + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _writeAuditLog(
      action: 'EXPENSE_SUBMITTED',
      entityType: 'EXPENSE',
      entityId: expDocId,
      actorId: supervisorId,
      actorName: supervisorName,
      actorRole: 'Supervisor',
      organizationId: orgId,
      siteId: isSite ? resolvedSiteId : null,
      newState: expense.toMap(),
    );

    final formattedAmt = formatCurrency(amount);
    final contextLabel = isSite ? 'on site $resolvedSiteName' : '(Non-Site / Personal Expense)';
    await NotificationService.notifyManager(
      title: '📋 Petty Cash Expense Awaiting Review',
      body: 'Supervisor $supervisorName submitted $formattedAmt ($resolvedCategory) $contextLabel. Manager review required.',
      forManagerName: expense.managerName,
      requestType: 'petty_cash_expense',
      requestId: expDocId,
      docId: expDocId,
      status: PettyCashStatus.pendingExpenseReview,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: description,
    );

    return expense;
  }

  /// Manager approves expense -> Atomically deducts available balance, posts ledger entry, releases reservation.
  Future<void> managerApproveExpense({
    required String expenseId,
    required String managerId,
    required String managerName,
    String? reviewRemarks,
    bool receiptVerified = true,
    bool verifyReceipt = true,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final expRef = FirestoreService.pettyCashExpenses.doc(expenseId);
    final isVerified = receiptVerified && verifyReceipt;

    late final PettyCashTransaction createdTxn;
    bool shouldNotifyLowBalance = false;
    double resultingBalance = 0.0;
    double thresholdAmount = 0.0;
    late final PettyCashExpense expense;

    await firestore.runTransaction((txn) async {
      final expSnap = await txn.get(expRef);
      if (!expSnap.exists || expSnap.data() == null) {
        throw Exception('Expense #$expenseId not found.');
      }

      expense = PettyCashExpense.fromMap(expSnap.id, expSnap.data()!);
      if (expense.isApproved || expense.postedToLedger) {
        return; // Idempotent exit
      }

      validateStatusTransition(
        currentStatus: expense.status,
        targetStatus: PettyCashStatus.expenseApproved,
        actorRole: 'Manager',
        actorId: managerId,
        requesterId: expense.submittedBy,
      );

      final accountRef = FirestoreService.pettyCashAccounts.doc(expense.accountId);
      final accountSnap = await txn.get(accountRef);
      if (!accountSnap.exists || accountSnap.data() == null) {
        throw Exception('Account #${expense.accountId} not found.');
      }

      final aData = accountSnap.data()!;
      final double currentAllocated = (aData['totalAllocated'] is num) ? (aData['totalAllocated'] as num).toDouble() : 0.0;
      final double currentSpent = (aData['totalSpent'] is num) ? (aData['totalSpent'] as num).toDouble() : 0.0;
      final double currentAvailable = (aData['availableBalance'] is num) ? (aData['availableBalance'] as num).toDouble() : (currentAllocated - currentSpent);
      final double currentReserved = (aData['reservedBalance'] is num) ? (aData['reservedBalance'] as num).toDouble() : 0.0;

      if (expense.amount > currentAvailable) {
        throw Exception('Insufficient available petty cash balance. Current available: ${formatCurrency(currentAvailable)}.');
      }

      final double newBalance = (currentAvailable - expense.amount).clamp(0.0, double.infinity);
      final double newSpent = currentSpent + expense.amount;
      final double newReserved = (currentReserved - expense.amount).clamp(0.0, double.infinity);
      resultingBalance = newBalance;

      // 10% Low Balance check
      final double cycleAlloc = (aData['currentCycleAllocated'] is num) ? (aData['currentCycleAllocated'] as num).toDouble() : currentAllocated;
      final double thresholdPercent = (aData['lowBalanceThresholdPercent'] is num) ? (aData['lowBalanceThresholdPercent'] as num).toDouble() : 10.0;
      final bool alreadyTriggered = aData['lowBalanceTriggered'] == true;
      thresholdAmount = cycleAlloc * (thresholdPercent / 100.0);

      if (newBalance <= thresholdAmount && !alreadyTriggered && currentAllocated > 0) {
        shouldNotifyLowBalance = true;
      }

      final txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}_EXP';

      createdTxn = PettyCashTransaction(
        transactionId: txnId,
        idempotencyKey: 'EXP_APPROVED_${expense.expenseId}',
        pettyCashId: expense.pettyCashId,
        referenceId: expense.expenseId,
        accountId: expense.accountId,
        orgId: expense.orgId,
        supervisorId: expense.submittedBy,
        supervisorName: expense.submittedByName,
        managerId: managerId,
        managerName: managerName,
        siteId: expense.isSiteExpense ? expense.siteId : null,
        siteName: expense.isSiteExpense ? expense.siteName : null,
        siteCode: expense.isSiteExpense ? expense.siteCode : null,
        expenseType: expense.expenseType,
        vendorName: expense.vendorName,
        isSiteExpense: expense.isSiteExpense,
        transactionType: 'EXPENSE_APPROVED',
        expenseCategory: expense.category,
        description: expense.description,
        amount: expense.amount,
        previousBalance: currentAvailable,
        newBalance: newBalance,
        remarks: reviewRemarks ?? expense.description,
        attachmentUrl: expense.receiptUrl,
        status: 'POSTED',
        transactionDate: expense.transactionDate,
        createdBy: managerName,
        createdRole: 'Manager',
        createdAt: DateTime.now(),
      );

      // --- ALL WRITES ---
      // 1. Post ledger transaction
      txn.set(FirestoreService.pettyCashTransactions.doc(txnId), createdTxn.toMap());

      // 2. Update Expense status to Approved & Posted
      txn.update(expRef, {
        'status': PettyCashStatus.expenseApproved,
        'reviewedBy': managerName,
        'reviewRemarks': reviewRemarks ?? 'Expense verified and approved by Manager.',
        'approvedAt': FieldValue.serverTimestamp(),
        'postedToLedger': true,
        'transactionId': txnId,
        'receiptVerified': isVerified,
        'receiptVerifiedBy': isVerified ? managerName : null,
        'receiptVerifiedAt': isVerified ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update Account balances
      txn.update(accountRef, {
        'availableBalance': newBalance,
        'totalUsed': newSpent,
        'totalSpent': newSpent,
        'reservedBalance': newReserved,
        'postedExpenseBalance': (aData['postedExpenseBalance'] is num ? (aData['postedExpenseBalance'] as num).toDouble() : currentSpent) + expense.amount,
        if (shouldNotifyLowBalance) 'lowBalanceTriggered': true,
        'lastTransactionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Audit Log
      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'EXPENSE_APPROVED',
        entityType: 'EXPENSE',
        entityId: expenseId,
        actorId: managerId,
        actorName: managerName,
        actorRole: 'Manager',
        organizationId: expense.orgId,
        siteId: expense.isSiteExpense ? expense.siteId : null,
        previousState: {'status': expense.status, 'availableBalance': currentAvailable},
        newState: {'status': PettyCashStatus.expenseApproved, 'availableBalance': newBalance, 'txnId': txnId},
        timestamp: DateTime.now(),
      );
      txn.set(logRef, auditLog.toMap());
    });

    // Post-Transaction Notifications & Sync
    final formattedAmt = formatCurrency(expense.amount);
    final notifContext = expense.isSiteExpense
        ? 'for site ${expense.siteName ?? expense.siteId}'
        : 'for non-site expense';
    await NotificationService.notifySupervisor(
      supervisorName: expense.submittedByName,
      supervisorId: expense.submittedBy,
      title: '✅ Petty Cash Expense Approved',
      body: 'Manager $managerName approved $formattedAmt (${expense.category}) $notifContext. Balance posted to ledger.',
      requestType: 'petty_cash_expense',
      requestId: expense.expenseId,
      docId: expense.expenseId,
      status: PettyCashStatus.expenseApproved,
      senderRole: 'Manager',
      senderName: managerName,
    );

    if (shouldNotifyLowBalance) {
      final formattedBal = formatCurrency(resultingBalance);
      final formattedThreshold = formatCurrency(thresholdAmount);
      await NotificationService.notifySupervisor(
        supervisorName: expense.submittedByName,
        supervisorId: expense.submittedBy,
        title: '⚠️ Petty Cash Low Balance',
        body: 'Your petty cash balance has reached $formattedBal (at or below $formattedThreshold). Please request replenishment from your Manager.',
        requestType: 'petty_cash',
        requestId: expense.accountId,
        docId: expense.accountId,
        status: 'low_balance',
        senderRole: 'System',
        senderName: 'Petty Cash Automation',
      );
    }

    if (expense.isSiteExpense && expense.siteId != null && expense.siteId!.trim().isNotEmpty && expense.siteId!.trim() != 'NON_SITE_EXPENSES') {
      ExpenseService.recalcTotalsAndSyncProject(expense.siteId!.trim()).catchError((e) {
        debugPrint('Error syncing site project financial totals: $e');
      });
    } else {
      ExpenseService.recalcNonSiteExpenses().catchError((e) {
        debugPrint('Error syncing non-site expenses: $e');
      });
    }
  }

  /// Manager rejects an expense -> Releases reservation without deducting available balance.
  Future<void> managerRejectExpense({
    required String expenseId,
    required String managerId,
    required String managerName,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final firestore = FirebaseFirestore.instance;
    final expRef = FirestoreService.pettyCashExpenses.doc(expenseId);

    late final PettyCashExpense expense;

    await firestore.runTransaction((txn) async {
      final expSnap = await txn.get(expRef);
      if (!expSnap.exists || expSnap.data() == null) {
        throw Exception('Expense #$expenseId not found.');
      }

      expense = PettyCashExpense.fromMap(expSnap.id, expSnap.data()!);
      if (expense.isRejected) return;

      validateStatusTransition(
        currentStatus: expense.status,
        targetStatus: PettyCashStatus.expenseRejected,
        actorRole: 'Manager',
        actorId: managerId,
        requesterId: expense.submittedBy,
        rejectionReason: reason,
      );

      final accountRef = FirestoreService.pettyCashAccounts.doc(expense.accountId);
      final accountSnap = await txn.get(accountRef);
      double currentReserved = 0.0;
      if (accountSnap.exists && accountSnap.data() != null) {
        currentReserved = (accountSnap.data()!['reservedBalance'] is num)
            ? (accountSnap.data()!['reservedBalance'] as num).toDouble()
            : 0.0;
      }

      final newReserved = (currentReserved - expense.amount).clamp(0.0, double.infinity);

      txn.update(expRef, {
        'status': PettyCashStatus.expenseRejected,
        'reviewedBy': managerName,
        'reviewRemarks': reason,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.update(accountRef, {
        'reservedBalance': newReserved,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'EXPENSE_REJECTED',
        entityType: 'EXPENSE',
        entityId: expenseId,
        actorId: managerId,
        actorName: managerName,
        actorRole: 'Manager',
        organizationId: expense.orgId,
        siteId: expense.isSiteExpense ? expense.siteId : null,
        previousState: {'status': expense.status},
        newState: {'status': PettyCashStatus.expenseRejected, 'rejectionReason': reason},
        timestamp: DateTime.now(),
      );
      txn.set(logRef, auditLog.toMap());
    });

    final formattedAmt = formatCurrency(expense.amount);
    await NotificationService.notifySupervisor(
      supervisorName: expense.submittedByName,
      supervisorId: expense.submittedBy,
      title: '❌ Petty Cash Expense Declined',
      body: 'Your expense for $formattedAmt (${expense.category}) was declined by Manager $managerName. Reason: $reason. No balance was deducted.',
      requestType: 'petty_cash_expense',
      requestId: expense.expenseId,
      docId: expense.expenseId,
      status: PettyCashStatus.expenseRejected,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: reason,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. CASH RECONCILIATION WORKFLOW
  // ---------------------------------------------------------------------------

  /// Calculates expected physical cash for a site account or supervisor.
  Future<double> calculateExpectedCash({
    String? siteId,
    String? supervisorId,
  }) async {
    final orgId = FirestoreService.currentOrgId;
    String target = (siteId != null && siteId.trim().isNotEmpty)
        ? siteId.trim()
        : (supervisorId?.trim() ?? '');
    if (target.isEmpty) return 0.0;

    final siteAccId = formatSiteAccountId(orgId, target);
    var accountSnap = await FirestoreService.pettyCashAccounts.doc(siteAccId).get();
    if (!accountSnap.exists || accountSnap.data() == null) {
      accountSnap = await FirestoreService.pettyCashAccounts.doc(target.toLowerCase()).get();
    }

    if (accountSnap.exists && accountSnap.data() != null) {
      final a = PettyCashAccount.fromMap(accountSnap.id, accountSnap.data()!);
      return (a.totalReceived - a.totalSpent - a.totalReturned).clamp(0.0, double.infinity);
    }
    return 0.0;
  }

  /// Supervisor submits physical cash reconciliation.
  Future<String> submitReconciliation({
    required String supervisorId,
    required String supervisorName,
    String? siteId,
    String? siteName,
    String? managerId,
    String? managerName,
    double? expectedCash,
    required double physicalCash,
    String? differenceReason,
    String? notes,
    String? supportingAttachment,
  }) async {
    final orgId = FirestoreService.currentOrgId;
    final resolvedSiteId = (siteId ?? '').trim();
    final resolvedSiteName = (siteName ?? resolvedSiteId).trim();
    final siteAccId = resolvedSiteId.isNotEmpty
        ? formatSiteAccountId(orgId, resolvedSiteId)
        : supervisorId.trim().toLowerCase();
    final calcExpected = expectedCash ?? await calculateExpectedCash(
      siteId: resolvedSiteId.isNotEmpty ? resolvedSiteId : null,
      supervisorId: supervisorId,
    );
    final difference = physicalCash - calcExpected;

    if (difference.abs() > 0.01 && (differenceReason == null || differenceReason.trim().isEmpty)) {
      throw Exception('A written explanation is mandatory when physical cash differs from expected cash.');
    }

    final reconDocId = 'REC_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';
    final now = DateTime.now();

    final reconciliation = PettyCashReconciliation(
      reconciliationId: reconDocId,
      accountId: siteAccId,
      orgId: orgId,
      siteId: resolvedSiteId,
      siteName: resolvedSiteName,
      expectedCash: calcExpected,
      physicalCash: physicalCash,
      difference: difference,
      differenceReason: differenceReason ?? notes,
      supportingAttachment: supportingAttachment,
      submittedBy: supervisorId,
      submittedByName: supervisorName,
      status: difference.abs() > 0.01 ? PettyCashStatus.discrepancyReview : PettyCashStatus.reconciliationPending,
      createdAt: now,
      updatedAt: now,
    );

    await FirestoreService.pettyCashReconciliations.doc(reconDocId).set(reconciliation.toMap());

    await _writeAuditLog(
      action: 'RECONCILIATION_SUBMITTED',
      entityType: 'RECONCILIATION',
      entityId: reconDocId,
      actorId: supervisorId,
      actorName: supervisorName,
      actorRole: 'Supervisor',
      organizationId: orgId,
      siteId: resolvedSiteId,
      newState: reconciliation.toMap(),
    );

    return reconDocId;
  }

  /// Manager or Organization approves cash reconciliation.
  Future<void> reviewReconciliation({
    required String reconciliationId,
    String? managerId,
    String? managerName,
    String? reviewerId,
    String? reviewerName,
    String reviewerRole = 'Manager',
    required bool isApproved,
    String? remarks,
  }) async {
    final reconRef = FirestoreService.pettyCashReconciliations.doc(reconciliationId);
    final snap = await reconRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Reconciliation #$reconciliationId not found.');
    }

    final targetStatus = isApproved ? PettyCashStatus.reconciliationApproved : PettyCashStatus.discrepancyReview;
    final rName = reviewerName ?? managerName ?? 'Manager';
    final rId = reviewerId ?? managerId ?? '';

    await reconRef.update({
      'status': targetStatus,
      'reviewedBy': rName,
      'reviewRemarks': remarks ?? (isApproved ? 'Reconciliation approved.' : 'Flagged for discrepancy review.'),
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _writeAuditLog(
      action: isApproved ? 'RECONCILIATION_APPROVED' : 'DISCREPANCY_FLAGGED',
      entityType: 'RECONCILIATION',
      entityId: reconciliationId,
      actorId: rId,
      actorName: rName,
      actorRole: reviewerRole,
      newState: {'status': targetStatus, 'remarks': remarks},
    );
  }

  // ---------------------------------------------------------------------------
  // 7. CASH RETURN WORKFLOW (PHYSICAL CASH SURRENDER)
  // ---------------------------------------------------------------------------

  /// Supervisor or Manager submits cash return.
  Future<String> submitCashReturn({
    required String supervisorId,
    required String supervisorName,
    String? siteId,
    String? siteName,
    String? managerId,
    String? managerName,
    required double returnAmount,
    required String reason,
    String? proofUrl,
  }) async {
    if (returnAmount <= 0) {
      throw Exception('Return amount must be greater than zero.');
    }

    final orgId = FirestoreService.currentOrgId;
    final resolvedSiteId = (siteId ?? '').trim();
    final resolvedSiteName = (siteName ?? resolvedSiteId).trim();
    final siteAccId = resolvedSiteId.isNotEmpty
        ? formatSiteAccountId(orgId, resolvedSiteId)
        : supervisorId.trim().toLowerCase();
    final accountSnap = await FirestoreService.pettyCashAccounts.doc(siteAccId).get();

    if (!accountSnap.exists || accountSnap.data() == null) {
      throw Exception('Account not found for site $resolvedSiteName.');
    }

    final a = PettyCashAccount.fromMap(accountSnap.id, accountSnap.data()!);
    if (returnAmount > a.availableBalance) {
      throw Exception('Return amount (${formatCurrency(returnAmount)}) exceeds available balance (${formatCurrency(a.availableBalance)}).');
    }

    final returnDocId = 'RET_${DateTime.now().millisecondsSinceEpoch}_${supervisorId.replaceAll(RegExp(r'\W'), '')}';
    final now = DateTime.now();

    final ret = PettyCashReturn(
      returnId: returnDocId,
      accountId: siteAccId,
      orgId: orgId,
      siteId: resolvedSiteId,
      siteName: resolvedSiteName,
      returnAmount: returnAmount,
      returnedBy: supervisorId,
      returnedByName: supervisorName,
      returnDate: now,
      proofUrl: proofUrl,
      reason: reason,
      status: PettyCashStatus.pendingReturnConfirmation,
      createdAt: now,
    );

    await FirestoreService.pettyCashReturns.doc(returnDocId).set(ret.toMap());

    await _writeAuditLog(
      action: 'CASH_RETURN_SUBMITTED',
      entityType: 'RETURN',
      entityId: returnDocId,
      actorId: supervisorId,
      actorName: supervisorName,
      actorRole: 'Supervisor',
      organizationId: orgId,
      siteId: resolvedSiteId,
      newState: ret.toMap(),
    );

    return returnDocId;
  }

  /// Manager / Org confirms cash return receipt -> Deducts balance and adds CASH_RETURN ledger transaction.
  Future<void> confirmCashReturn({
    required String returnId,
    String? managerId,
    String? managerName,
    String? receiverId,
    String? receiverName,
    String receiverRole = 'Manager',
  }) async {
    final firestore = FirebaseFirestore.instance;
    final retRef = FirestoreService.pettyCashReturns.doc(returnId);
    final rId = receiverId ?? managerId ?? '';
    final rName = receiverName ?? managerName ?? 'Manager';

    await firestore.runTransaction((txn) async {
      final retSnap = await txn.get(retRef);
      if (!retSnap.exists || retSnap.data() == null) {
        throw Exception('Return record #$returnId not found.');
      }

      final retData = retSnap.data()!;
      if (retData['status'] == PettyCashStatus.returnConfirmed) return;

      final double amt = (retData['returnAmount'] is num) ? (retData['returnAmount'] as num).toDouble() : 0.0;
      final String accId = retData['accountId']?.toString() ?? '';
      final String sId = retData['siteId']?.toString() ?? '';
      final String sName = retData['siteName']?.toString() ?? '';

      final accountRef = FirestoreService.pettyCashAccounts.doc(accId);
      final accountSnap = await txn.get(accountRef);
      if (!accountSnap.exists || accountSnap.data() == null) {
        throw Exception('Account #$accId not found.');
      }

      final aData = accountSnap.data()!;
      final double prevAvail = (aData['availableBalance'] is num) ? (aData['availableBalance'] as num).toDouble() : 0.0;
      final double prevReturned = (aData['totalReturned'] is num) ? (aData['totalReturned'] as num).toDouble() : 0.0;

      final double newAvail = (prevAvail - amt).clamp(0.0, double.infinity);
      final double newReturned = prevReturned + amt;

      final txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}_RET';
      final ledgerTxn = PettyCashTransaction(
        transactionId: txnId,
        idempotencyKey: 'RET_CONFIRMED_$returnId',
        referenceId: returnId,
        accountId: accId,
        orgId: FirestoreService.currentOrgId,
        supervisorId: retData['returnedBy']?.toString() ?? '',
        supervisorName: retData['returnedByName']?.toString() ?? 'Supervisor',
        managerId: rId,
        managerName: rName,
        siteId: sId,
        siteName: sName,
        isSiteExpense: true,
        transactionType: 'CASH_RETURN',
        expenseCategory: 'Cash Return',
        description: 'Physical cash returned and verified: ${retData['reason'] ?? ""}',
        amount: amt,
        previousBalance: prevAvail,
        newBalance: newAvail,
        status: 'POSTED',
        transactionDate: DateTime.now(),
        createdBy: rName,
        createdRole: receiverRole,
        createdAt: DateTime.now(),
      );

      // Writes
      txn.set(FirestoreService.pettyCashTransactions.doc(txnId), ledgerTxn.toMap());

      txn.update(retRef, {
        'status': PettyCashStatus.returnConfirmed,
        'receivedBy': rId,
        'receivedByName': rName,
        'transactionId': txnId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.update(accountRef, {
        'availableBalance': newAvail,
        'totalReturned': newReturned,
        'lastTransactionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final logRef = FirestoreService.pettyCashAuditLogs.doc();
      final auditLog = PettyCashAuditLog(
        logId: logRef.id,
        action: 'CASH_RETURN_CONFIRMED',
        entityType: 'RETURN',
        entityId: returnId,
        actorId: rId,
        actorName: rName,
        actorRole: receiverRole,
        organizationId: FirestoreService.currentOrgId,
        siteId: sId,
        previousState: {'availableBalance': prevAvail},
        newState: {'availableBalance': newAvail, 'totalReturned': newReturned},
        timestamp: DateTime.now(),
      );
      txn.set(logRef, auditLog.toMap());
    });
  }

  /// Manager allocates/disburses petty cash (alias).
  Future<void> managerAllocatePettyCash({
    required String requestId,
    required String managerName,
    String? managerId,
    required double allocationAmount,
    String? remarks,
  }) => managerDisburseCash(
    requestId: requestId,
    managerName: managerName,
    managerId: managerId,
    disbursementAmount: allocationAmount,
    remarks: remarks,
  );

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
    String? organizationId,
    String? siteId,
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
        organizationId: organizationId ?? FirestoreService.currentOrgId,
        siteId: siteId,
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
  // 9. STREAMS FOR EXPENSES, RECONCILIATIONS, RETURNS, REQUESTS & TRANSACTIONS
  // ---------------------------------------------------------------------------

  /// Streams all expenses across all sites.
  Stream<List<PettyCashExpense>> streamAllExpenses() {
    return FirestoreService.pettyCashExpenses.snapshots().map((snap) {
      final list = snap.docs.map((d) => PettyCashExpense.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? b.transactionDate).compareTo(a.createdAt ?? a.transactionDate));
      return list;
    });
  }

  /// Streams expenses submitted by or assigned to a specific supervisor.
  Stream<List<PettyCashExpense>> streamSupervisorExpenses(
    String supervisorId, {
    String? supervisorName,
  }) {
    final cleanId = supervisorId.trim().toLowerCase();
    final cleanName = supervisorName?.trim().toLowerCase() ?? '';

    return FirestoreService.pettyCashExpenses.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashExpense.fromMap(d.id, d.data()))
          .where((e) {
            final eSupId = e.supervisorId.trim().toLowerCase();
            final eSupName = e.supervisorName.trim().toLowerCase();

            if (cleanId.isNotEmpty && (eSupId == cleanId || e.supervisorId == supervisorId)) {
              return true;
            }
            if (cleanName.isNotEmpty && (eSupName == cleanName || e.supervisorName == supervisorName)) {
              return true;
            }
            return false;
          })
          .toList();

      list.sort((a, b) => (b.createdAt ?? b.transactionDate).compareTo(a.createdAt ?? a.transactionDate));
      return list;
    });
  }

  /// Streams all reconciliations.
  Stream<List<PettyCashReconciliation>> streamAllReconciliations() {
    return FirestoreService.pettyCashReconciliations.snapshots().map((snap) {
      final list = snap.docs.map((d) => PettyCashReconciliation.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  /// Streams reconciliations submitted by a supervisor.
  Stream<List<PettyCashReconciliation>> streamSupervisorReconciliations(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashReconciliations.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashReconciliation.fromMap(d.id, d.data()))
          .where((r) => r.submittedBy.trim().toLowerCase() == cleanId || r.submittedBy == supervisorId)
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  /// Streams all cash returns.
  Stream<List<PettyCashReturn>> streamAllReturns() {
    return FirestoreService.pettyCashReturns.snapshots().map((snap) {
      final list = snap.docs.map((d) => PettyCashReturn.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? b.returnDate).compareTo(a.createdAt ?? a.returnDate));
      return list;
    });
  }

  /// Streams cash returns submitted by a supervisor.
  Stream<List<PettyCashReturn>> streamSupervisorReturns(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashReturns.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashReturn.fromMap(d.id, d.data()))
          .where((r) => r.returnedBy.trim().toLowerCase() == cleanId || r.returnedBy == supervisorId)
          .toList();
      list.sort((a, b) => (b.createdAt ?? b.returnDate).compareTo(a.createdAt ?? a.returnDate));
      return list;
    });
  }

  /// Streams ledger transactions for a supervisor.
  Stream<List<PettyCashTransaction>> streamSupervisorTransactions(String supervisorId) {
    final cleanId = supervisorId.trim().toLowerCase();
    return FirestoreService.pettyCashTransactions.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PettyCashTransaction.fromMap(d.id, d.data()))
          .where((t) {
            final tAccId = t.accountId.trim().toLowerCase();
            final tSupId = t.supervisorId.trim().toLowerCase();
            return tAccId.contains(cleanId) || tSupId == cleanId || cleanId.isEmpty;
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
  // 10. SITE-WISE AGGREGATION ENGINE
  // ---------------------------------------------------------------------------

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

    for (final req in requests) {
      final rawSite = (req.siteId ?? '').trim();
      if (rawSite.isEmpty || rawSite == 'NON_SITE_EXPENSES') continue;
      final siteKey = ExpenseService.formatCanonicalSiteId(
        rawId: rawSite,
        siteName: req.siteName,
      );

      if (cleanSiteFilter.isNotEmpty &&
          siteKey.toLowerCase() != cleanSiteFilter &&
          (req.siteName ?? '').toLowerCase() != cleanSiteFilter &&
          !siteKey.toLowerCase().contains(cleanSiteFilter)) {
        continue;
      }

      if (cleanSupFilter.isNotEmpty &&
          req.supervisorId.toLowerCase() != cleanSupFilter &&
          req.supervisorName.toLowerCase() != cleanSupFilter &&
          !req.supervisorName.toLowerCase().contains(cleanSupFilter)) {
        continue;
      }

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

    for (final t in transactions) {
      if (!t.isSiteExpense || t.expenseType == 'other') continue;
      final rawSite = (t.siteId ?? '').trim();
      if (rawSite.isEmpty || rawSite == 'NON_SITE_EXPENSES') continue;
      final siteKey = ExpenseService.formatCanonicalSiteId(
        rawId: rawSite,
        siteName: t.siteName,
      );

      if (cleanSiteFilter.isNotEmpty &&
          siteKey.toLowerCase() != cleanSiteFilter &&
          (t.siteName ?? '').toLowerCase() != cleanSiteFilter &&
          !siteKey.toLowerCase().contains(cleanSiteFilter)) {
        continue;
      }

      if (cleanSupFilter.isNotEmpty &&
          t.supervisorId.toLowerCase() != cleanSupFilter &&
          t.supervisorName.toLowerCase() != cleanSupFilter &&
          !t.supervisorName.toLowerCase().contains(cleanSupFilter)) {
        continue;
      }

      if (cleanProjFilter.isNotEmpty &&
          (t.projectId ?? '').toLowerCase() != cleanProjFilter &&
          (t.projectName ?? '').toLowerCase() != cleanProjFilter &&
          !(t.projectName ?? '').toLowerCase().contains(cleanProjFilter)) {
        continue;
      }

      if (cleanCatFilter.isNotEmpty &&
          cleanCatFilter != 'all' &&
          t.expenseCategory.toLowerCase() != cleanCatFilter &&
          !t.expenseCategory.toLowerCase().contains(cleanCatFilter)) {
        continue;
      }

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

      double totalReceived = 0.0;
      for (final r in siteReqs) {
        if (r.isReceived) {
          final alloc = r.receivedAmount > 0
              ? r.receivedAmount
              : (r.disbursedAmount > 0
                  ? r.disbursedAmount
                  : (r.approvedAmount > 0
                      ? r.approvedAmount
                      : (r.allocatedAmount > 0 ? r.allocatedAmount : r.requestedAmount)));
          totalReceived += alloc;
        }
      }

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

    summaries.sort((a, b) => b.totalReceived.compareTo(a.totalReceived));
    return summaries;
  }
}
