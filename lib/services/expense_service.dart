import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class ExpenseService {
  // Recalculate all expense category totals and sync with project document
  static Future<void> recalcTotalsAndSyncProject(String siteId) async {
    if (siteId.isEmpty || siteId == 'uninitialized') return;
    try {
      final siteKeys = await _resolveSiteKeys(siteId);

      // Compute totals from all 5 expense categories concurrently in parallel
      final results = await Future.wait([
        _sumSupervisorExpenses(siteId, siteKeys),
        _sumManagerExpenses(siteId, siteKeys),
        _sumOrganizationExpenses(siteId, siteKeys),
        _sumContractorExpenses(siteId, siteKeys),
        _sumIncentiveExpenses(siteId, siteKeys),
      ]);

      final supervisorTotal = results[0];
      final managerTotal = results[1];
      final organizationTotal = results[2];
      final contractorTotal = results[3];
      final incentiveTotal = results[4];

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

      // Determine actual customer amount paid across documents
      double amountPaid = 0.0;
      if (projectRef != null) {
        final projectSnap = await projectRef.get();
        if (projectSnap.exists && projectSnap.data() != null) {
          final data = projectSnap.data()!;
          if (data['amountPaid'] is num) {
            amountPaid = (data['amountPaid'] as num).toDouble();
          } else if (data['amountReceived'] is num) {
            amountPaid = (data['amountReceived'] as num).toDouble();
          } else if (data['paid'] is num) {
            amountPaid = (data['paid'] as num).toDouble();
          }
        }
      }

      if (amountPaid == 0.0 && siteRef != null) {
        final siteSnap = await siteRef.get();
        if (siteSnap.exists && siteSnap.data() != null) {
          final sData = siteSnap.data()!;
          if (sData['amountPaid'] is num) {
            amountPaid = (sData['amountPaid'] as num).toDouble();
          } else if (sData['amountReceived'] is num) {
            amountPaid = (sData['amountReceived'] as num).toDouble();
          } else if (sData['paid'] is num) {
            amountPaid = (sData['paid'] as num).toDouble();
          }
        }
      }

      final amountBalance = amountPaid - totalAllExpenses;
      final batch = firestore.batch();

      // Document reference for total site expenses
      final totalsRef =
          FirestoreService.getCollection('totalSiteExpensesPerDay').doc(siteId);

      // Upsert totals document with merged fields
      batch.set(
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
      if (projectRef != null) {
        batch.set(
          projectRef,
          {
            'amountSpent': totalAllExpenses,
            'amountSpend': totalAllExpenses,
            'amountBalance': amountBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // Also update Site collection document if exists and is not the same as projectRef
      if (siteRef != null && (projectRef == null || siteRef.path != projectRef.path)) {
        batch.set(
          siteRef,
          {
            'amountSpent': totalAllExpenses,
            'amountSpend': totalAllExpenses,
            'amountBalance': amountBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

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

  // Helper to resolve all possible identifier aliases for a site (docId, siteId, site, siteName)
  static Future<Set<String>> _resolveSiteKeys(String siteId) async {
    final siteKeys = <String>{siteId.trim()};
    try {
      final pDoc = await _findExistingProjectDocBySiteId(siteId);
      if (pDoc != null) {
        final pSnap = await pDoc.get();
        if (pSnap.exists && pSnap.data() != null) {
          final d = pSnap.data()!;
          if (d['siteId'] != null) siteKeys.add(d['siteId'].toString().trim());
          if (d['site'] != null) siteKeys.add(d['site'].toString().trim());
          if (d['siteName'] != null) siteKeys.add(d['siteName'].toString().trim());
          if (d['siteLocation'] != null) siteKeys.add(d['siteLocation'].toString().trim());
        }
      }
      final sDoc = await _findExistingSiteDocBySiteId(siteId);
      if (sDoc != null) {
        final sSnap = await sDoc.get();
        if (sSnap.exists && sSnap.data() != null) {
          final d = sSnap.data()!;
          if (d['siteId'] != null) siteKeys.add(d['siteId'].toString().trim());
          if (d['site'] != null) siteKeys.add(d['site'].toString().trim());
          if (d['siteName'] != null) siteKeys.add(d['siteName'].toString().trim());
          if (d['siteLocation'] != null) siteKeys.add(d['siteLocation'].toString().trim());
        }
      }
    } catch (_) {}
    siteKeys.removeWhere((k) => k.isEmpty);
    return siteKeys;
  }

  // Helper to parse numeric amount from any dynamic field or sub-structure
  static double _parseExpenseAmount(dynamic val, [Map<String, dynamic>? data]) {
    if (val != null) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(',', '').replaceAll('₹', '').trim();
        final parsed = double.tryParse(clean);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    if (data != null) {
      double sum = 0.0;
      final food = _parseExpenseAmount(data['food']);
      final fuel = _parseExpenseAmount(data['fuel']);
      final transport = _parseExpenseAmount(data['transport']);
      sum += food + fuel + transport;

      final labours = data['labours'];
      if (labours is List) {
        for (var l in labours) {
          if (l is Map) {
            final amt = _parseExpenseAmount(l['amount']);
            if (amt > 0) {
              sum += amt;
            } else {
              final count = _parseExpenseAmount(l['count']);
              final salary = _parseExpenseAmount(l['unitSalary'] ?? l['salary']);
              sum += (count * salary);
            }
          }
        }
      }

      final materials = data['materials'];
      if (materials is List) {
        for (var m in materials) {
          if (m is Map) {
            final amt = _parseExpenseAmount(m['amount']);
            if (amt > 0) {
              sum += amt;
            } else {
              final qty = _parseExpenseAmount(m['quantity'] ?? m['qty']);
              final price = _parseExpenseAmount(m['unitPrice'] ?? m['price']);
              sum += (qty * price);
            }
          }
        }
      }
      if (sum > 0) return sum;
    }
    return 0.0;
  }

  // Sum supervisor expenses for the site
  static Future<double> _sumSupervisorExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await _resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      for (final key in siteKeys) {
        final snap1 = await FirestoreService.siteSupervisorEntries
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snap1.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap2 = await FirestoreService.siteSupervisorEntries
            .where('site', isEqualTo: key)
            .get();
        for (final doc in snap2.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap3 = await FirestoreService.siteSupervisorEntries
            .where('siteName', isEqualTo: key)
            .get();
        for (final doc in snap3.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      // Check all entries to match docId prefix e.g. {siteKey}_{ddMMyyyy}
      try {
        final allEntriesSnap = await FirestoreService.siteSupervisorEntries.get();
        for (final doc in allEntriesSnap.docs) {
          for (final key in siteKeys) {
            if (doc.id.startsWith('${key}_') ||
                doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
              matchedDocs[doc.id] = doc.data();
            }
          }
        }
      } catch (_) {}

      for (final data in matchedDocs.values) {
        // Skip manager or org entries recorded in supervisor collection
        if (data['isManagerEntry'] == true ||
            data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true ||
            data['createdBy'] == 'manager_org') {
          continue;
        }
        final amount = _parseExpenseAmount(data['totalAmount'] ?? data['amount'], data);
        total += amount;
      }
    } catch (e) {
      print("❌ Error summing supervisor expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum manager expenses for the site
  static Future<double> _sumManagerExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await _resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      // 1. Ingest direct managerExpenses collection (Primary collection used by Manager Expenses screen)
      for (final key in siteKeys) {
        final snap1 = await FirestoreService.managerExpenses
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snap1.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap2 = await FirestoreService.managerExpenses
            .where('site', isEqualTo: key)
            .get();
        for (final doc in snap2.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap3 = await FirestoreService.managerExpenses
            .where('projectName', isEqualTo: key)
            .get();
        for (final doc in snap3.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      // Check managerExpenses docId prefix {siteKey}_{ddMMyyyy}
      try {
        final allExpSnap = await FirestoreService.managerExpenses.get();
        for (final doc in allExpSnap.docs) {
          for (final key in siteKeys) {
            if (doc.id.startsWith('${key}_') ||
                doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
              matchedDocs[doc.id] = doc.data();
            }
          }
        }
      } catch (_) {}

      // 2. Ingest managerExpenseSummary (fallback / mirror for docs not already present)
      for (final key in siteKeys) {
        try {
          final snapSummarySite = await FirestoreService.managerExpenseSummary
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in snapSummarySite.docs) {
            matchedDocs.putIfAbsent(doc.id, () => doc.data());
          }
        } catch (_) {}
      }

      try {
        final allSummarySnap = await FirestoreService.managerExpenseSummary.get();
        for (final doc in allSummarySnap.docs) {
          for (final key in siteKeys) {
            if (doc.id.startsWith('${key}_') ||
                doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
              matchedDocs.putIfAbsent(doc.id, () => doc.data());
            }
          }
        }
      } catch (_) {}

      // 3. Ingest managerEntries collection
      for (final key in siteKeys) {
        try {
          final managerEntriesSnapshot = await FirestoreService.managerEntries
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in managerEntriesSnapshot.docs) {
            matchedDocs.putIfAbsent('mgr_${doc.id}', () => doc.data());
          }
        } catch (_) {}
      }

      // 4. Ingest manager site entries saved in siteSupervisorEntries
      for (final key in siteKeys) {
        try {
          final supervisorEntriesSnapshot = await FirestoreService.siteSupervisorEntries
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in supervisorEntriesSnapshot.docs) {
            final data = doc.data();
            if (data['isManagerEntry'] == true || data['createdBy'] == 'manager') {
              matchedDocs.putIfAbsent('sup_mgr_${doc.id}', () => data);
            }
          }
        } catch (_) {}
      }

      for (final data in matchedDocs.values) {
        // Check if bills array exists and sum items
        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          double billsSum = 0.0;
          for (final b in bills) {
            if (b is Map) {
              billsSum += _parseExpenseAmount(b['billAmount'] ?? b['amount']);
            }
          }
          if (billsSum > 0) {
            total += billsSum;
            continue;
          }
        }

        final amount = _parseExpenseAmount(
          data['mgrExpenseTotalAmount'] ?? data['totalAmount'] ?? data['amount'],
          data,
        );
        total += amount;
      }
    } catch (e) {
      print("❌ Error summing manager expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum organization expenses for the site
  static Future<double> _sumOrganizationExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await _resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      // 1. Ingest direct organizationEntries
      for (final key in siteKeys) {
        final orgDirectSnap = await FirestoreService.organizationEntries
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in orgDirectSnap.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final orgDirectSnap2 = await FirestoreService.organizationEntries
            .where('site', isEqualTo: key)
            .get();
        for (final doc in orgDirectSnap2.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      try {
        final allOrgSnap = await FirestoreService.organizationEntries.get();
        for (final doc in allOrgSnap.docs) {
          for (final key in siteKeys) {
            if (doc.id.startsWith('${key}_') ||
                doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
              matchedDocs[doc.id] = doc.data();
            }
          }
        }
      } catch (_) {}

      // 2. Ingest organizationExpenses collection if present
      for (final key in siteKeys) {
        try {
          final orgExpSnap = await FirestoreService.getCollection('organizationExpenses')
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in orgExpSnap.docs) {
            matchedDocs.putIfAbsent(doc.id, () => doc.data());
          }
        } catch (_) {}
      }

      // 3. Fallback to organizationExpenseSummary
      for (final key in siteKeys) {
        try {
          final snapSummary = await FirestoreService.organizationExpenseSummary
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in snapSummary.docs) {
            matchedDocs.putIfAbsent(doc.id, () => doc.data());
          }
        } catch (_) {}
      }

      try {
        final allOrgSumSnap = await FirestoreService.organizationExpenseSummary.get();
        for (final doc in allOrgSumSnap.docs) {
          for (final key in siteKeys) {
            if (doc.id.startsWith('${key}_') ||
                doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
              matchedDocs.putIfAbsent(doc.id, () => doc.data());
            }
          }
        }
      } catch (_) {}

      // 4. Ingest manager site entry organization expenses saved in siteSupervisorEntries
      for (final key in siteKeys) {
        try {
          final orgEntriesSnapshot = await FirestoreService.siteSupervisorEntries
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in orgEntriesSnapshot.docs) {
            final data = doc.data();
            if (data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
              matchedDocs.putIfAbsent('sup_org_${doc.id}', () => data);
            }
          }
        } catch (_) {}
      }

      for (final data in matchedDocs.values) {
        // Check if bills array exists
        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          double billsSum = 0.0;
          for (final b in bills) {
            if (b is Map) {
              billsSum += _parseExpenseAmount(b['billAmount'] ?? b['amount']);
            }
          }
          if (billsSum > 0) {
            total += billsSum;
            continue;
          }
        }

        final amount = _parseExpenseAmount(
          data['orgExpenseTotalAmount'] ?? data['totalAmount'] ?? data['amount'],
          data,
        );
        total += amount;
      }
    } catch (e) {
      print("❌ Error summing organization expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum contractor expenses for the site
  static Future<double> _sumContractorExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await _resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      for (final key in siteKeys) {
        final snapshot = await FirestoreService.contractorEntries
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snapshot.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      for (final data in matchedDocs.values) {
        final amount = _parseExpenseAmount(data['totalAmount'] ?? data['amount'], data);
        total += amount;
      }
    } catch (e) {
      print("❌ Error summing contractor expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum incentive expenses for the site
  static Future<double> _sumIncentiveExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await _resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      for (final key in siteKeys) {
        final snapshot = await FirestoreService.siteSupervisorIncentives
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snapshot.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        try {
          final snap2 = await FirestoreService.getCollection('supervisorIncentives')
              .where('siteId', isEqualTo: key)
              .get();
          for (final doc in snap2.docs) {
            matchedDocs[doc.id] = doc.data();
          }
        } catch (_) {}
      }

      for (final data in matchedDocs.values) {
        final amount = _parseExpenseAmount(
          data['incentiveAmount'] ?? data['amount'] ?? data['totalAmount'],
        );
        total += amount;
      }
    } catch (e) {
      print("❌ Error summing incentive expenses for siteId=$siteId: $e");
    }
    return total;
  }
}