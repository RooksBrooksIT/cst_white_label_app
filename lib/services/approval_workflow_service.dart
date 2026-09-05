import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/material_inventory_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:intl/intl.dart';

/// Represents the 5-stage approval lifecycle states.
enum ApprovalStage {
  pendingManagerReview, // Stage 1: Submitted by Supervisor, awaiting Manager verification
  pendingOrgApproval, // Stage 2: Verified by Manager, awaiting Org authorization
  pendingManagerClearance, // Stage 3: Approved by Org, awaiting Manager final release
  approved, // Stage 4: Final clearance completed by Manager
  rejectedByManager, // Rejected by Manager
  rejectedByOrg, // Rejected by Organization
}

class ApprovalWorkflowService {
  // Constant string representations for Firestore documents
  static const String statusPendingManagerReview = 'pending_manager_review';
  static const String statusPendingOrgApproval = 'pending_org_approval';
  static const String statusPendingManagerClearance = 'pending_manager_clearance';
  static const String statusApproved = 'approved';
  static const String statusRejectedByManager = 'rejected_by_manager';
  static const String statusRejectedByOrg = 'rejected_by_org';

  /// Helper to map collection name to a clean request type string.
  static String getRequestType(String collectionName) {
    final lower = collectionName.toLowerCase();
    if (lower.contains('material')) return 'material';
    if (lower.contains('tool')) return 'tools';
    if (lower.contains('schedule') || lower.contains('work')) return 'workforce';
    if (lower.contains('payment') || lower.contains('entry') || lower.contains('entries')) return 'payment';
    return 'general';
  }

  /// Helper to get human-friendly display name of request type.
  static String getRequestTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'material':
        return 'Material Request';
      case 'tools':
        return 'Tools Requisition';
      case 'payment':
        return 'Site Payment';
      case 'workforce':
        return 'Workforce Request';
      default:
        return 'Requisition';
    }
  }

  /// Converts any string status to the corresponding [ApprovalStage] enum.
  static ApprovalStage parseStatus(dynamic rawStatus) {
    if (rawStatus == null) return ApprovalStage.pendingManagerReview;
    final s = rawStatus.toString().toLowerCase().trim();

    if (s == statusPendingManagerReview ||
        s == 'pending' ||
        s == 'processing' ||
        s == 'submitted') {
      return ApprovalStage.pendingManagerReview;
    }
    if (s == statusPendingOrgApproval ||
        s == 'forwarded_to_org' ||
        s == 'pending org approval' ||
        s == 'manager_verified') {
      return ApprovalStage.pendingOrgApproval;
    }
    if (s == statusPendingManagerClearance ||
        s == 'org_approved' ||
        s == 'pending manager clearance' ||
        s == 'pending_clearance') {
      return ApprovalStage.pendingManagerClearance;
    }
    if (s == statusApproved || s == 'completed' || s == 'released') {
      return ApprovalStage.approved;
    }
    if (s == statusRejectedByManager || s == 'rejected_by_manager') {
      return ApprovalStage.rejectedByManager;
    }
    if (s == statusRejectedByOrg || s == 'rejected_by_org' || s == 'rejected') {
      return ApprovalStage.rejectedByOrg;
    }

    return ApprovalStage.pendingManagerReview;
  }

  /// Returns user-friendly status badge text.
  static String getStatusDisplayText(dynamic rawStatus) {
    final stage = parseStatus(rawStatus);
    switch (stage) {
      case ApprovalStage.pendingManagerReview:
        return 'Pending Manager Review';
      case ApprovalStage.pendingOrgApproval:
        return 'Pending Org Approval';
      case ApprovalStage.pendingManagerClearance:
        return 'Pending Manager Clearance';
      case ApprovalStage.approved:
        return 'Approved & Released';
      case ApprovalStage.rejectedByManager:
        return 'Rejected by Manager';
      case ApprovalStage.rejectedByOrg:
        return 'Rejected by Org';
    }
  }

  /// Returns the 1-based active pipeline step index (1 to 4), or -1 if rejected.
  static int getStepNumber(dynamic rawStatus) {
    final stage = parseStatus(rawStatus);
    switch (stage) {
      case ApprovalStage.pendingManagerReview:
        return 1;
      case ApprovalStage.pendingOrgApproval:
        return 2;
      case ApprovalStage.pendingManagerClearance:
        return 3;
      case ApprovalStage.approved:
        return 4;
      case ApprovalStage.rejectedByManager:
      case ApprovalStage.rejectedByOrg:
        return -1;
    }
  }

  /// Creates a standard audit log history map.
  static Map<String, dynamic> createAuditEntry({
    required String step,
    required String action,
    required String actorRole, // 'Supervisor', 'Manager', 'Organization'
    required String actorName,
    String? actorId,
    String? remarks,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(now);

    return {
      'step': step,
      'action': action,
      'actorRole': actorRole,
      'actorName': actorName,
      'actorId': actorId ?? '',
      'remarks': remarks ?? '',
      'timestamp': Timestamp.fromDate(now),
      'dateStr': formattedDate,
    };
  }

  // ===========================================================================
  // STAGE 1: SUPERVISOR SUBMISSION
  // ===========================================================================

  /// Call when a Supervisor submits a new request.
  static Future<void> submitRequest({
    required String collectionName,
    required String docId,
    required Map<String, dynamic> baseData,
    required String supervisorName,
    String? supervisorId,
    String? initialRemarks,
  }) async {
    final auditEntry = createAuditEntry(
      step: '1. Supervisor Submission',
      action: 'Request Submitted',
      actorRole: 'Supervisor',
      actorName: supervisorName,
      actorId: supervisorId,
      remarks: initialRemarks ?? 'Requisition created and submitted for review.',
    );

    final payload = {
      ...baseData,
      'status': statusPendingManagerReview,
      'statusDisplay': 'Pending Manager Review',
      'currentStep': 1,
      'supervisorName': supervisorName,
      'supervisorId': supervisorId ?? '',
      'approvalHistory': [auditEntry],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.getCollection(collectionName).doc(docId).set(payload, SetOptions(merge: true));

    // Real-time notification to Manager(s)
    final siteId = (baseData['siteId'] ?? 'N/A').toString();
    final reqId = (baseData['matReqId'] ?? baseData['toolReqId'] ?? baseData['wsReqId'] ?? baseData['paymentReqId'] ?? docId).toString();
    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);

    await NotificationService.notifyManager(
      title: '📋 New $reqTypeName Submitted',
      body: '$supervisorName (Site: $siteId) submitted $reqTypeName #$reqId for your review.',
      requestType: reqType,
      requestId: reqId,
      docId: docId,
      siteId: siteId,
      status: statusPendingManagerReview,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: initialRemarks,
    );
  }

  // ===========================================================================
  // STAGE 2: MANAGER INITIAL VERIFICATION & FORWARD TO ORG
  // ===========================================================================

  /// Call when a Manager verifies the request and forwards it to the Organization.
  static Future<void> managerVerifyAndForward({
    required String collectionName,
    required String docId,
    required String managerName,
    String? managerId,
    required String remarks,
    String? siteId,
    Map<String, dynamic>? additionalUpdates,
  }) async {
    final auditEntry = createAuditEntry(
      step: '2. Manager Initial Review',
      action: 'Verified & Forwarded to Organization',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: remarks.isNotEmpty ? remarks : 'Verified and forwarded for organization approval.',
    );

    final updates = {
      if (additionalUpdates != null) ...additionalUpdates,
      'status': statusPendingOrgApproval,
      'statusDisplay': 'Pending Organization Approval',
      'currentStep': 2,
      'managerName': managerName,
      'managerId': managerId ?? '',
      'managerReviewRemarks': remarks,
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.getCollection(collectionName).doc(docId).update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);

    // Real-time notification to Organization
    await NotificationService.notifyOrganisation(
      title: '🏢 $reqTypeName Forwarded for HQ Approval',
      body: 'Manager $managerName verified and forwarded $reqTypeName #$docId for HQ authorization. Remarks: $remarks',
      requestType: reqType,
      requestId: docId,
      docId: docId,
      siteId: siteId,
      status: statusPendingOrgApproval,
      senderRole: 'Manager',
      senderName: managerName,
      remarks: remarks,
    );
  }

  /// Call when a Manager rejects the request during initial review.
  static Future<void> managerReject({
    required String collectionName,
    required String docId,
    required String managerName,
    String? managerId,
    required String reason,
    String? supervisorName,
    String? siteId,
  }) async {
    final auditEntry = createAuditEntry(
      step: '2. Manager Initial Review',
      action: 'Rejected by Manager',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: reason,
    );

    final updates = {
      'status': statusRejectedByManager,
      'statusDisplay': 'Rejected by Manager',
      'currentStep': -1,
      'rejectionReason': reason,
      'rejectedBy': managerName,
      'rejectedRole': 'Manager',
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.getCollection(collectionName).doc(docId).update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);

    // Real-time notification to Supervisor
    if (supervisorName != null && supervisorName.isNotEmpty) {
      await NotificationService.notifySupervisor(
        supervisorName: supervisorName,
        title: '❌ $reqTypeName Declined by Manager',
        body: 'Your $reqTypeName #$docId was declined by Manager $managerName. Reason: $reason',
        requestType: reqType,
        requestId: docId,
        docId: docId,
        siteId: siteId,
        status: statusRejectedByManager,
        senderRole: 'Manager',
        senderName: managerName,
        remarks: reason,
      );
    }
  }

  // ===========================================================================
  // STAGE 3: ORGANIZATION APPROVAL / REJECTION
  // ===========================================================================

  /// Call when Organization Admin approves the request (returns to Manager for final clearance).
  static Future<void> orgApprove({
    required String collectionName,
    required String docId,
    required String orgUserName,
    String? orgUserId,
    required String remarks,
    String? managerName,
    String? supervisorName,
    String? siteId,
    Map<String, dynamic>? additionalUpdates,
  }) async {
    final auditEntry = createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Approved by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks: remarks.isNotEmpty ? remarks : 'Organization authorization granted. Returned to Manager for clearance.',
    );

    final updates = {
      if (additionalUpdates != null) ...additionalUpdates,
      'status': statusPendingManagerClearance,
      'statusDisplay': 'Pending Manager Clearance',
      'currentStep': 3,
      'orgApprovedBy': orgUserName,
      'orgApprovalRemarks': remarks,
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.getCollection(collectionName).doc(docId).update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);

    // Real-time notification to Manager that Org has authorized
    await NotificationService.notifyManager(
      title: '✅ $reqTypeName Authorized by HQ',
      body: 'HQ ($orgUserName) authorized $reqTypeName #$docId. Manager clearance required to release to site.',
      requestType: reqType,
      requestId: docId,
      docId: docId,
      siteId: siteId,
      status: statusPendingManagerClearance,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: remarks,
    );
  }

  /// Call when Organization Admin rejects the request.
  static Future<void> orgReject({
    required String collectionName,
    required String docId,
    required String orgUserName,
    String? orgUserId,
    required String reason,
    String? supervisorName,
    String? siteId,
  }) async {
    final auditEntry = createAuditEntry(
      step: '3. Organization Authorization',
      action: 'Rejected by Organization',
      actorRole: 'Organization',
      actorName: orgUserName,
      actorId: orgUserId,
      remarks: reason,
    );

    final updates = {
      'status': statusRejectedByOrg,
      'statusDisplay': 'Rejected by Organization',
      'currentStep': -1,
      'rejectionReason': reason,
      'rejectedBy': orgUserName,
      'rejectedRole': 'Organization',
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.getCollection(collectionName).doc(docId).update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);

    // Real-time notification to Supervisor
    if (supervisorName != null && supervisorName.isNotEmpty) {
      await NotificationService.notifySupervisor(
        supervisorName: supervisorName,
        title: '❌ $reqTypeName Declined by HQ',
        body: 'Your $reqTypeName #$docId was declined by Organization HQ. Reason: $reason',
        requestType: reqType,
        requestId: docId,
        docId: docId,
        siteId: siteId,
        status: statusRejectedByOrg,
        senderRole: 'Organization',
        senderName: orgUserName,
        remarks: reason,
      );
    }

    // Real-time notification to Manager
    await NotificationService.notifyManager(
      title: '❌ $reqTypeName Declined by HQ',
      body: '$reqTypeName #$docId was declined by HQ ($orgUserName). Reason: $reason',
      requestType: reqType,
      requestId: docId,
      docId: docId,
      siteId: siteId,
      status: statusRejectedByOrg,
      senderRole: 'Organization',
      senderName: orgUserName,
      remarks: reason,
    );
  }

  // ===========================================================================
  // STAGE 4: MANAGER FINAL CLEARANCE & DISPATCH
  // ===========================================================================

  /// Call when Manager issues the final clearance/dispatch and releases the request to the Supervisor.
  static Future<void> managerFinalClearance({
    required String collectionName,
    required String docId,
    required String managerName,
    String? managerId,
    required String remarks,
    String? supervisorName,
    String? siteId,
    List<dynamic>? materials,
    Map<String, dynamic>? additionalUpdates,
  }) async {
    final auditEntry = createAuditEntry(
      step: '4. Manager Final Clearance',
      action: 'Final Approval & Release Completed',
      actorRole: 'Manager',
      actorName: managerName,
      actorId: managerId,
      remarks: remarks.isNotEmpty ? remarks : 'Final clearance granted. Dispatched to site.',
    );

    final reqRef = FirestoreService.getCollection(collectionName).doc(docId);
    final reqSnap = await reqRef.get();
    final reqData = reqSnap.data() ?? {};

    final isAlreadyTransferred = (reqData['isStockTransferred'] == true);
    final rawMaterials = materials ?? (reqData['materials'] as List?);
    final targetSiteId = (siteId != null && siteId.isNotEmpty)
        ? siteId
        : (reqData['siteId'] ?? '').toString();
    final targetSiteName = (reqData['siteName'] ?? reqData['projectName'] ?? targetSiteId).toString();
    final targetProjectName = (reqData['projectName'] ?? '').toString();
    final targetSupervisor = supervisorName ?? (reqData['supervisorName'] ?? '').toString();

    // If it's a material request and not already transferred, execute company-to-site stock movement
    if (!isAlreadyTransferred &&
        collectionName.toLowerCase().contains('material') &&
        rawMaterials != null &&
        rawMaterials.isNotEmpty &&
        targetSiteId.isNotEmpty) {
      for (final m in rawMaterials) {
        if (m is Map) {
          final matMap = Map<String, dynamic>.from(m);
          final matName = (matMap['materialName'] ?? matMap['material'] ?? '').toString().trim();
          final rawQty = matMap['materialQty'] ?? matMap['quantity'] ?? matMap['releasedQty'] ?? 0;
          final int qty = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0);

          if (matName.isNotEmpty && qty > 0) {
            try {
              await MaterialInventoryService.transferCompanyToSite(
                materialName: matName,
                siteId: targetSiteId,
                quantity: qty,
                siteName: targetSiteName,
                managerName: managerName,
                supervisorName: targetSupervisor,
                projectName: targetProjectName,
                displayName: matName,
              );
            } catch (invErr) {
              debugPrint('MaterialInventoryService stock transfer error for $matName: $invErr');
            }
          }
        }
      }
    }

    // If it's a tools request and not already transferred, execute company-to-site stock movement
    if (!isAlreadyTransferred &&
        collectionName.toLowerCase().contains('tool') &&
        targetSiteId.isNotEmpty) {
      final reqTools = (reqData['tools'] as List?) ?? [];
      final reqId = (reqData['toolReqId'] ?? docId).toString();
      if (reqTools.isNotEmpty) {
        try {
          await _transferToolsCompanyToSite(
            tools: reqTools,
            siteId: targetSiteId,
            managerName: managerName,
            supervisorName: targetSupervisor,
            projectName: targetProjectName,
            reqId: reqId,
          );
        } catch (tErr) {
          debugPrint('Tools stock transfer error during clearance: $tErr');
        }
      }
    }

    final updates = {
      if (additionalUpdates != null) ...additionalUpdates,
      'status': statusApproved,
      'statusDisplay': 'Approved & Released',
      'currentStep': 4,
      'finalApprovedBy': managerName,
      'finalClearanceRemarks': remarks,
      'isStockTransferred': true,
      'stockTransferredAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    };

    await reqRef.update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);
    final isTool = reqType == 'tools';

    // Real-time notification to Supervisor confirming final release!
    if (supervisorName != null && supervisorName.isNotEmpty) {
      await NotificationService.notifySupervisor(
        supervisorName: supervisorName,
        title: isTool
            ? '🚚 Tools Requisition Approved & Dispatched!'
            : '🎉 $reqTypeName Approved & Released!',
        body: isTool
            ? 'Manager $managerName approved and dispatched Tools Requisition #$docId. Tools dispatched – awaiting arrival confirmation.'
            : 'Manager $managerName completed final clearance for $reqTypeName #$docId. Material released – awaiting arrival confirmation.',
        requestType: reqType,
        requestId: docId,
        docId: docId,
        siteId: siteId,
        status: statusApproved,
        senderRole: 'Manager',
        senderName: managerName,
        remarks: remarks,
      );
    }
  }

  /// Internal helper to execute atomic company-to-site tool stock movement.
  static Future<void> _transferToolsCompanyToSite({
    required List<dynamic> tools,
    required String siteId,
    required String managerName,
    required String supervisorName,
    String? projectName,
    String? reqId,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('ddMMyyyy_HHmmss').format(now);
    final docId = '${siteId}_$dateStr';
    String tmId = 'TM001';

    try {
      final snapshot = await FirestoreService.getCollection('toolsMovement')
          .orderBy('tmId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastTmId = snapshot.docs.first['tmId'] as String?;
        if (lastTmId != null && lastTmId.startsWith('TM')) {
          final lastNum = int.tryParse(lastTmId.substring(2)) ?? 0;
          tmId = 'TM${(lastNum + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (_) {}

    final formattedDate =
        '${DateFormat('MMMM d, yyyy at hh:mm:ss a').format(now)} UTC+5:30';

    final toolsList = <Map<String, dynamic>>[];

    for (final t in tools) {
      if (t is Map) {
        final tMap = Map<String, dynamic>.from(t);
        final toolCode = (tMap['toolCode'] ?? tMap['toolId'] ?? '').toString().trim();
        final toolName = (tMap['toolName'] ?? toolCode).toString().trim();
        final rawCount = tMap['toolCount'] ?? tMap['count'] ?? tMap['quantity'] ?? 0;
        final int enteredCount = (rawCount is num)
            ? rawCount.toInt()
            : (int.tryParse(rawCount.toString()) ?? 0);

        if (toolCode.isNotEmpty && enteredCount > 0) {
          toolsList.add({
            'toolId': tMap['toolId'] ?? toolCode,
            'toolCode': toolCode,
            'toolName': toolName,
            'toolCount': enteredCount,
          });

          // 1. Decrement toolsAtCompany
          try {
            final companyQuery = await FirestoreService.getCollection('toolsAtCompany')
                .where('toolCode', isEqualTo: toolCode)
                .limit(1)
                .get();

            if (companyQuery.docs.isNotEmpty) {
              await companyQuery.docs.first.reference.update({
                'availableCount': FieldValue.increment(-enteredCount),
              });
            }
          } catch (_) {}

          // 2. Increment toolsAtSite
          try {
            final siteDocRef = FirestoreService.getCollection('toolsAtSite').doc(toolCode);
            await siteDocRef.set({'toolCode': toolCode}, SetOptions(merge: true));
            await siteDocRef.update({
              'availableCount': FieldValue.increment(enteredCount),
            });
          } catch (_) {}

          // 3. Update toolsInventory availableCountAtSites
          try {
            final invDocRef = FirestoreService.getCollection('toolsInventory').doc(toolCode);
            final isoString = now.toIso8601String();
            await FirestoreService.runTransaction((transaction) async {
              final snap = await transaction.get(invDocRef);
              if (!snap.exists) {
                transaction.set(invDocRef, {
                  'toolCode': toolCode,
                  'availableCountAtSites': {siteId: enteredCount},
                  'lastUpdated': isoString,
                });
              } else {
                final data = snap.data() as Map<String, dynamic>;
                final Map<String, dynamic> availableCountAtSites =
                    Map<String, dynamic>.from(data['availableCountAtSites'] ?? {});
                final currentSiteCount = (availableCountAtSites[siteId] as int?) ?? 0;
                final newSiteCount = currentSiteCount + enteredCount;
                if (newSiteCount <= 0) {
                  availableCountAtSites.remove(siteId);
                } else {
                  availableCountAtSites[siteId] = newSiteCount;
                }
                transaction.update(invDocRef, {
                  'availableCountAtSites': availableCountAtSites,
                  'lastUpdated': isoString,
                });
              }
            });
          } catch (_) {}
        }
      }
    }

    if (toolsList.isNotEmpty) {
      try {
        final movementData = {
          'tmId': tmId,
          'date': formattedDate,
          'mgrName': managerName,
          'supervisorName': supervisorName,
          'mtSiteId': siteId,
          'projectName': projectName ?? '',
          'tools': toolsList,
          if (reqId != null && reqId.isNotEmpty) 'reqId': reqId,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await FirestoreService.getCollection('toolsMovement').doc(docId).set(movementData);
      } catch (e) {
        debugPrint('Failed to save toolsMovement record: $e');
      }
    }
  }

  // ===========================================================================
  // STAGE 5 (POST-RELEASE): SUPERVISOR MATERIAL ARRIVAL CONFIRMATION
  // ===========================================================================

  /// Call when the requesting Supervisor confirms physical arrival of material at the site with proof image.
  static Future<void> supervisorConfirmArrival({
    required String collectionName,
    required String docId,
    required String supervisorName,
    String? supervisorId,
    required String proofImageUrl,
    String? remarks,
    String? siteId,
    String? matReqId,
    List<dynamic>? materials,
  }) async {
    final auditEntry = createAuditEntry(
      step: '5. Material Arrival Confirmation',
      action: 'Material Arrival Confirmed',
      actorRole: 'Supervisor',
      actorName: supervisorName,
      actorId: supervisorId,
      remarks: (remarks != null && remarks.isNotEmpty)
          ? '$remarks (Proof photo verified)'
          : 'Material physically received and verified at site. Proof photo uploaded.',
    );

    final reqRef = FirestoreService.getCollection(collectionName).doc(docId);
    final reqSnap = await reqRef.get();
    final reqData = reqSnap.data() ?? {};

    final isAlreadyTransferred = (reqData['isStockTransferred'] == true);
    final rawMaterials = materials ?? (reqData['materials'] as List?);
    final targetSiteId = (siteId != null && siteId.isNotEmpty)
        ? siteId
        : (reqData['siteId'] ?? '').toString();
    final targetSiteName = (reqData['siteName'] ?? reqData['projectName'] ?? targetSiteId).toString();
    final targetProjectName = (reqData['projectName'] ?? '').toString();
    final targetManagerName = (reqData['finalApprovedBy'] ?? reqData['managerName'] ?? '').toString();

    // Idempotent safeguard: If not previously transferred during clearance, transfer each item now
    if (!isAlreadyTransferred &&
        collectionName.toLowerCase().contains('material') &&
        rawMaterials != null &&
        rawMaterials.isNotEmpty &&
        targetSiteId.isNotEmpty) {
      for (final m in rawMaterials) {
        if (m is Map) {
          final matMap = Map<String, dynamic>.from(m);
          final matName = (matMap['materialName'] ?? matMap['material'] ?? '').toString().trim();
          final rawQty = matMap['materialQty'] ?? matMap['quantity'] ?? matMap['releasedQty'] ?? 0;
          final int qty = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 0);

          if (matName.isNotEmpty && qty > 0) {
            try {
              await MaterialInventoryService.transferCompanyToSite(
                materialName: matName,
                siteId: targetSiteId,
                quantity: qty,
                siteName: targetSiteName,
                managerName: targetManagerName,
                supervisorName: supervisorName,
                projectName: targetProjectName,
                displayName: matName,
              );
            } catch (invErr) {
              debugPrint('MaterialInventoryService arrival sync error for $matName: $invErr');
            }
          }
        }
      }
    }

    final updates = {
      'arrivalConfirmationStatus': 'confirmed',
      'arrivalConfirmedBy': supervisorName,
      'arrivalConfirmedById': supervisorId ?? '',
      'arrivalConfirmedAt': FieldValue.serverTimestamp(),
      'arrivalProofImageUrl': proofImageUrl,
      if (remarks != null && remarks.isNotEmpty)
        'arrivalConfirmationRemarks': remarks,
      'isStockTransferred': true,
      'stockTransferredAt': reqData['stockTransferredAt'] ?? FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await reqRef.update(updates);

    final reqType = getRequestType(collectionName);
    final reqTypeName = getRequestTypeDisplayName(reqType);
    final displayReqId = (matReqId != null && matReqId.isNotEmpty) ? matReqId : docId;

    // Real-time notification to Manager(s) confirming material has arrived on site!
    await NotificationService.notifyManager(
      title: '📦 $reqTypeName Arrival Confirmed',
      body: '$supervisorName (Site: ${targetSiteId.isNotEmpty ? targetSiteId : 'N/A'}) confirmed physical arrival & uploaded proof photo for $reqTypeName #$displayReqId.',
      requestType: reqType,
      requestId: displayReqId,
      docId: docId,
      siteId: targetSiteId,
      status: statusApproved,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: remarks,
    );
  }

  // ===========================================================================
  // STAGE 5 (POST-RELEASE): SUPERVISOR TOOLS ARRIVAL CONFIRMATION
  // ===========================================================================

  /// Call when the requesting Supervisor confirms physical arrival of equipment/tools at the site with proof image.
  static Future<void> supervisorConfirmToolArrival({
    required String collectionName,
    required String docId,
    required String supervisorName,
    String? supervisorId,
    required String proofImageUrl,
    String? remarks,
    String? siteId,
    String? toolReqId,
    List<dynamic>? tools,
  }) async {
    final auditEntry = createAuditEntry(
      step: '5. Tool Arrival Confirmation',
      action: 'Tool Arrival Confirmed',
      actorRole: 'Supervisor',
      actorName: supervisorName,
      actorId: supervisorId,
      remarks: (remarks != null && remarks.isNotEmpty)
          ? '$remarks (Proof photo verified)'
          : 'Tools & equipment physically received and verified at site. Proof photo uploaded.',
    );

    final reqRef = FirestoreService.getCollection(collectionName).doc(docId);
    final reqSnap = await reqRef.get();
    final reqData = reqSnap.data() ?? {};

    final isAlreadyTransferred = (reqData['isStockTransferred'] == true);
    final rawTools = tools ?? (reqData['tools'] as List?) ?? [];
    final targetSiteId = (siteId != null && siteId.isNotEmpty)
        ? siteId
        : (reqData['siteId'] ?? '').toString();
    final targetProjectName = (reqData['projectName'] ?? '').toString();
    final targetManagerName = (reqData['finalApprovedBy'] ?? reqData['managerName'] ?? '').toString();
    final displayReqId = (toolReqId != null && toolReqId.isNotEmpty)
        ? toolReqId
        : (reqData['toolReqId'] ?? docId).toString();

    // Idempotent safeguard: If not previously transferred during clearance, transfer tools now once
    if (!isAlreadyTransferred && rawTools.isNotEmpty && targetSiteId.isNotEmpty) {
      try {
        await _transferToolsCompanyToSite(
          tools: rawTools,
          siteId: targetSiteId,
          managerName: targetManagerName,
          supervisorName: supervisorName,
          projectName: targetProjectName,
          reqId: displayReqId,
        );
      } catch (invErr) {
        debugPrint('Tools transfer arrival sync error: $invErr');
      }
    }

    final updates = {
      'arrivalConfirmationStatus': 'confirmed',
      'arrivalConfirmedBy': supervisorName,
      'arrivalConfirmedById': supervisorId ?? '',
      'arrivalConfirmedAt': FieldValue.serverTimestamp(),
      'arrivalProofImageUrl': proofImageUrl,
      if (remarks != null && remarks.isNotEmpty)
        'arrivalConfirmationRemarks': remarks,
      'isStockTransferred': true,
      'stockTransferredAt': reqData['stockTransferredAt'] ?? FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await reqRef.update(updates);

    // Real-time notification to Manager(s) confirming tools arrival on site!
    await NotificationService.notifyManager(
      title: '🚚 Tool Arrival Confirmed',
      body: '$supervisorName (Site: ${targetSiteId.isNotEmpty ? targetSiteId : 'N/A'}) confirmed physical arrival & uploaded proof photo for Tools Requisition #$displayReqId.',
      requestType: 'tools',
      requestId: displayReqId,
      docId: docId,
      siteId: targetSiteId,
      status: statusApproved,
      senderRole: 'Supervisor',
      senderName: supervisorName,
      remarks: remarks,
    );
  }
}
