import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class ExpenseService {
  // Recalculate all expense category totals and sync with project document
  static Future<void> recalcTotalsAndSyncProject(String siteId) async {
    try {
      // Compute totals from different expense categories
      final supervisorTotal = await _sumSupervisorExpenses(siteId);
      final managerTotal = await _sumManagerExpenses(siteId);
      final organizationTotal = await _sumOrganizationExpenses(siteId);
      final contractorTotal = await _sumContractorExpenses(siteId);
      final incentiveTotal = await _sumIncentiveExpenses(siteId);

      final double totalAllExpenses = supervisorTotal +
          managerTotal +
          organizationTotal +
          contractorTotal +
          incentiveTotal;

      final firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>>? projectRef =
          await _findExistingProjectDocBySiteId(siteId);
      final DocumentReference<Map<String, dynamic>>? siteRef =
          await _findExistingSiteDocBySiteId(siteId);

      await firestore.runTransaction((txn) async {
        // Document reference for total site expenses
        final totalsRef =
            FirestoreService.getCollection('totalSiteExpensesPerDay').doc(siteId);

        // Read project document snapshot (if exists) first
        DocumentSnapshot<Map<String, dynamic>>? projectSnap;
        if (projectRef != null) {
          projectSnap = await txn.get(projectRef);
        }

        // Read Site document snapshot (if exists)
        DocumentSnapshot<Map<String, dynamic>>? siteSnap;
        if (siteRef != null) {
          siteSnap = await txn.get(siteRef);
        }

        // Upsert totals document with merged fields
        txn.set(
          totalsRef,
          {
            'siteId': siteId,
            'totalSiteExpense': supervisorTotal,
            'totalMgrExpense': managerTotal,
            'totalOrgExpense': organizationTotal,
            'totalContractorExpense': contractorTotal,
            'totalIncentiveExpenses': incentiveTotal,
            'totalAllExpenses': totalAllExpenses,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Update project financial summary if project doc exists
        if (projectRef != null && projectSnap != null && projectSnap.exists) {
          final Map<String, dynamic>? data = projectSnap.data();
          double amountPaid = 0.0;
          if (data != null && data['amountPaid'] is num) {
            amountPaid = (data['amountPaid'] as num).toDouble();
          } else if (data != null && data['paid'] is num) {
            amountPaid = (data['paid'] as num).toDouble();
          } else if (data != null && data['amountReceived'] is num) {
            amountPaid = (data['amountReceived'] as num).toDouble();
          }
          final amountBalance = amountPaid - totalAllExpenses;

          txn.update(projectRef, {
            'amountSpent': totalAllExpenses,
            'amountSpend': totalAllExpenses,
            'amountBalance': amountBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Also update Site collection document if exists
        if (siteRef != null && siteSnap != null && siteSnap.exists) {
          final Map<String, dynamic>? sData = siteSnap.data();
          double sAmountPaid = 0.0;
          if (sData != null && sData['amountPaid'] is num) {
            sAmountPaid = (sData['amountPaid'] as num).toDouble();
          } else if (sData != null && sData['paid'] is num) {
            sAmountPaid = (sData['paid'] as num).toDouble();
          } else if (sData != null && sData['amountReceived'] is num) {
            sAmountPaid = (sData['amountReceived'] as num).toDouble();
          }
          final sAmountBalance = sAmountPaid - totalAllExpenses;

          txn.update(siteRef, {
            'amountSpent': totalAllExpenses,
            'amountSpend': totalAllExpenses,
            'amountBalance': sAmountBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print(
        "✅ Synced totals for site $siteId — Supervisor: $supervisorTotal, Manager: $managerTotal, Organization: $organizationTotal, Contractor: $contractorTotal, Incentive: $incentiveTotal, Total: $totalAllExpenses",
      );
    } catch (e) {
      print(
        "❌ Error recalculating and syncing totals for site $siteId: $e",
      );
    }
  }

  // Public wrappers for update methods that all currently recalc totals
  static Future<void> updateAllTotalsForSite(String siteId) =>
      recalcTotalsAndSyncProject(siteId);

  static Future<void> updateTotalSiteExpense(String siteId) async {
    print("ℹ️ updateTotalSiteExpense called — recalculating all totals.");
    await recalcTotalsAndSyncProject(siteId);
  }

  static Future<void> updateTotalMgrExpenseForSite(String siteId) async {
    print("ℹ️ updateTotalMgrExpenseForSite called — recalculating all totals.");
    await recalcTotalsAndSyncProject(siteId);
  }

  static Future<void> updateTotalOrgExpenseForSite(String siteId) async {
    print("ℹ️ updateTotalOrgExpenseForSite called — recalculating all totals.");
    await recalcTotalsAndSyncProject(siteId);
  }

  static Future<void> updateTotalIncentiveExpensesForSite(String siteId) async {
    print(
        "ℹ️ updateTotalIncentiveExpensesForSite called — recalculating all totals.");
    await recalcTotalsAndSyncProject(siteId);
  }

  // Find the existing project document reference by siteId
  static Future<DocumentReference<Map<String, dynamic>>?>
      _findExistingProjectDocBySiteId(String siteId) async {
    try {
      final docDirect = await FirestoreService.projects.doc(siteId).get();
      if (docDirect.exists) {
        return docDirect.reference;
      }
      final query = await FirestoreService.projects
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.reference;
      }
      final querySite = await FirestoreService.projects
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (querySite.docs.isNotEmpty) {
        return querySite.docs.first.reference;
      }
      return null;
    } catch (e) {
      print("❌ Error searching for project by siteId=$siteId: $e");
      return null;
    }
  }

  // Find the existing Site document reference by siteId
  static Future<DocumentReference<Map<String, dynamic>>?>
      _findExistingSiteDocBySiteId(String siteId) async {
    try {
      final siteDocDirect =
          await FirestoreService.getCollection('Site').doc(siteId).get();
      if (siteDocDirect.exists) {
        return siteDocDirect.reference;
      }
      final query = await FirestoreService.getCollection('Site')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.reference;
      }
      final querySite = await FirestoreService.getCollection('Site')
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (querySite.docs.isNotEmpty) {
        return querySite.docs.first.reference;
      }
      return null;
    } catch (e) {
      print("❌ Error searching for Site doc by siteId=$siteId: $e");
      return null;
    }
  }

  // Sum supervisor expenses for the site
  static Future<double> _sumSupervisorExpenses(String siteId) async {
    double total = 0.0;
    try {
      final snapshot = await FirestoreService.siteSupervisorEntries
          .where('siteId', isEqualTo: siteId)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Skip manager entries entered through manager site entry page
        if (data['isManagerEntry'] == true ||
            data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true ||
            data['createdBy'] == 'manager_org') {
          continue;
        }
        final amount = data['totalAmount'];
        if (amount is num) {
          total += amount.toDouble();
        }
      }
    } catch (e) {
      print("❌ Error summing supervisor expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum manager expenses for the site
  static Future<double> _sumManagerExpenses(String siteId) async {
    double total = 0.0;
    try {
      final snapshot = await FirestoreService.managerExpenseSummary
          // Document IDs assumed like: {siteId}_{something}
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${siteId}_')
          .where(FieldPath.documentId, isLessThan: '${siteId}_\uf8ff')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['mgrExpenseTotalAmount'];
        if (amount is num) {
          total += amount.toDouble();
        }
      }

      // Also sum manager site entry expenses saved in managerEntries
      final managerEntriesSnapshot = await FirestoreService.managerEntries
          .where('siteId', isEqualTo: siteId)
          .get();
      for (final doc in managerEntriesSnapshot.docs) {
        final data = doc.data();
        final amount = data['totalAmount'];
        if (amount is num) {
          total += amount.toDouble();
        }
      }

      // Maintain backward compatibility with historical manager entries in siteSupervisorEntries
      final supervisorEntriesSnapshot = await FirestoreService.siteSupervisorEntries
          .where('siteId', isEqualTo: siteId)
          .get();
      for (final doc in supervisorEntriesSnapshot.docs) {
        final data = doc.data();
        if (data['isManagerEntry'] == true || data['createdBy'] == 'manager') {
          final amount = data['totalAmount'];
          if (amount is num) {
            total += amount.toDouble();
          }
        }
      }
    } catch (e) {
      print("❌ Error summing manager expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum organization expenses for the site
  static Future<double> _sumOrganizationExpenses(String siteId) async {
    double total = 0.0;
    try {
      // 1. Direct entries in organizationEntries
      final orgDirectSnap = await FirestoreService.organizationEntries
          .where('siteId', isEqualTo: siteId)
          .get();
      double directOrgTotal = 0.0;
      for (final doc in orgDirectSnap.docs) {
        final data = doc.data();
        final amount = data['totalAmount'] ?? data['amount'];
        if (amount is num) {
          directOrgTotal += amount.toDouble();
        }
      }

      if (directOrgTotal > 0) {
        total += directOrgTotal;
      } else {
        // Fallback to organizationExpenseSummary
        final snapshot = await FirestoreService.organizationExpenseSummary
            // Document IDs assumed like: {siteId}_{something}
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${siteId}_')
            .where(FieldPath.documentId, isLessThan: '${siteId}_\uf8ff')
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final amount = data['orgExpenseTotalAmount'] ?? data['totalAmount'] ?? data['amount'];
          if (amount is num) {
            total += amount.toDouble();
          }
        }
      }

      // Also sum manager site entry organization expenses saved in siteSupervisorEntries
      final orgEntriesSnapshot = await FirestoreService.siteSupervisorEntries
          .where('siteId', isEqualTo: siteId)
          .get();
      for (final doc in orgEntriesSnapshot.docs) {
        final data = doc.data();
        if (data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
          final amount = data['totalAmount'];
          if (amount is num) {
            total += amount.toDouble();
          }
        }
      }
    } catch (e) {
      print("❌ Error summing organization expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum contractor expenses for the site
  static Future<double> _sumContractorExpenses(String siteId) async {
    double total = 0.0;
    try {
      final snapshot = await FirestoreService.contractorEntries
          .where('siteId', isEqualTo: siteId)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['totalAmount'];
        if (amount is num) {
          total += amount.toDouble();
        }
      }
    } catch (e) {
      print("❌ Error summing contractor expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum incentive expenses for the site
  static Future<double> _sumIncentiveExpenses(String siteId) async {
    double total = 0.0;
    try {
      final snapshot = await FirestoreService.siteSupervisorIncentives
          .where('siteId', isEqualTo: siteId)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['incentiveAmount'];
        if (amount is num) {
          total += amount.toDouble();
        }
      }
    } catch (e) {
      print("❌ Error summing incentive expenses for siteId=$siteId: $e");
    }
    return total;
  }
}