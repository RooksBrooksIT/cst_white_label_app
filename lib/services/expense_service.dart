import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class SiteDetails {
  final String canonicalDocId; // e.g. 'ST001_AbineshHouse'
  final String siteCode; // e.g. 'ST001'
  final String siteName; // e.g. 'Abinesh House'
  final Set<String> allKeys; // all aliases for matching expenses
  final String? supervisor;
  final String? supervisorId;
  final String? location;
  final String? projectName;
  final String? projectStage;

  SiteDetails({
    required this.canonicalDocId,
    required this.siteCode,
    required this.siteName,
    required this.allKeys,
    this.supervisor,
    this.supervisorId,
    this.location,
    this.projectName,
    this.projectStage,
  });

  String? operator [](String key) {
    switch (key) {
      case 'canonicalDocId':
      case 'siteId':
        return canonicalDocId;
      case 'siteCode':
        return siteCode;
      case 'siteName':
        return siteName;
      case 'supervisor':
        return supervisor;
      case 'supervisorId':
        return supervisorId;
      case 'location':
        return location;
      case 'projectName':
        return projectName;
      case 'projectStage':
        return projectStage;
      default:
        return null;
    }
  }
}

class ExpenseService {
  /// Formats canonical site document ID in the format: SiteCode_SiteName (e.g. ST001_AbineshHouse)
  static String formatCanonicalSiteDocId(String siteCode, String siteName) {
    var cleanCode = siteCode.trim();
    if (cleanCode.toUpperCase().startsWith('PR')) {
      cleanCode = 'ST${cleanCode.substring(2)}';
    }
    final cleanName = siteName.trim().replaceAll(' ', '');
    if (cleanCode.isNotEmpty && cleanName.isNotEmpty) {
      if (cleanCode.contains('_') &&
          cleanCode.toLowerCase().contains(cleanName.toLowerCase())) {
        return cleanCode.replaceAll(' ', '');
      }
      return '${cleanCode}_$cleanName';
    } else if (cleanCode.isNotEmpty && cleanCode.contains('_')) {
      return cleanCode.replaceAll(' ', '');
    } else if (cleanName.isNotEmpty && cleanName.contains('_')) {
      return cleanName.replaceAll(' ', '');
    }
    return cleanCode.isNotEmpty ? cleanCode : cleanName;
  }

  /// Formats any combination of raw site ID, site code, and site name into the standardized
  /// SiteCode_SiteName format (e.g. ST001_AbineshHouse).
  static String formatCanonicalSiteId({
    required String rawId,
    String? siteCode,
    String? siteName,
  }) {
    final cleanRaw = rawId.trim();
    var cleanCode = (siteCode ?? '').trim();
    if (cleanCode.toUpperCase().startsWith('PR')) {
      cleanCode = 'ST${cleanCode.substring(2)}';
    }
    final cleanName = (siteName ?? '').trim();

    // 1. If cleanRaw already contains an underscore:
    if (cleanRaw.contains('_')) {
      final parts = cleanRaw.split('_');
      var code = parts.first.trim();
      final namePart = parts.skip(1).join('_').trim().replaceAll(' ', '');
      if (code.toUpperCase().startsWith('PR')) {
        code = 'ST${code.substring(2)}';
      }
      if (code.isNotEmpty && namePart.isNotEmpty) {
        final formattedName = namePart[0].toUpperCase() + namePart.substring(1);
        return '${code}_$formattedName';
      }
      return cleanRaw.replaceAll(' ', '');
    }

    // 2. If separate code and name are supplied:
    if (cleanCode.isNotEmpty && cleanName.isNotEmpty) {
      return formatCanonicalSiteDocId(cleanCode, cleanName);
    }

    // 3. If rawId is a code and cleanName is name:
    if (cleanRaw.isNotEmpty &&
        cleanName.isNotEmpty &&
        cleanRaw.toLowerCase() != cleanName.toLowerCase()) {
      return formatCanonicalSiteDocId(cleanRaw, cleanName);
    }

    // 4. If cleanCode is code and cleanRaw is name:
    if (cleanCode.isNotEmpty &&
        cleanRaw.isNotEmpty &&
        cleanCode.toLowerCase() != cleanRaw.toLowerCase()) {
      return formatCanonicalSiteDocId(cleanCode, cleanRaw);
    }

    if (cleanRaw.toUpperCase().startsWith('PR')) {
      return 'ST${cleanRaw.substring(2)}'.replaceAll(' ', '');
    }

    return cleanRaw.replaceAll(' ', '');
  }

  /// Sanitizes a collection of site IDs by:
  /// 1. Converting any project prefix (PR...) to standardized site prefix (ST...).
  /// 2. Discarding bare site names (e.g. "Abinesh House") if a canonical equivalent (e.g. "ST001_AbineshHouse") is present.
  /// 3. Removing empty or uninitialized entries.
  /// 4. Returning sorted unique IDs.
  static List<String> sanitizeSiteIds(Iterable<String> ids) {
    final Set<String> sanitized = {};
    for (final raw in ids) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == 'uninitialized') continue;
      String normalized = trimmed;
      if (normalized.toUpperCase().startsWith('PR')) {
        normalized = 'ST${normalized.substring(2)}';
      }
      sanitized.add(normalized);
    }

    // Filter out bare site names that have a canonical counterpart
    final canonicalList = sanitized.where((id) {
      if (!id.contains('_')) {
        final idClean = id.replaceAll(' ', '').toLowerCase();
        final hasCanonicalCounterpart = sanitized.any((other) =>
            other != id &&
            other.contains('_') &&
            (other.toLowerCase().startsWith('${idClean}_') ||
                other.toLowerCase().endsWith('_$idClean') ||
                other.toLowerCase().contains(idClean)));
        return !hasCanonicalCounterpart;
      }
      return true;
    }).toList();

    canonicalList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return canonicalList;
  }

  /// Resolves the canonical site document ID (e.g. ST001_AbineshHouse) from any identifier:
  /// (e.g. 'ST001_AbineshHouse', 'ST001', 'Abinesh House', or 'AbineshHouse')
  static Future<String> resolveCanonicalSiteDocId(String siteInput) async {
    final trimmed = siteInput.trim();
    if (trimmed.isEmpty || trimmed == 'uninitialized') return trimmed;
    final details = await resolveSiteDetails(trimmed);
    return details.canonicalDocId;
  }

  /// Scans totalSiteExpensesPerDay and removes any legacy duplicate document
  /// that uses site name alone or non-canonical doc ID, merging totals into the canonical document.
  static Future<void> cleanupDuplicateSiteExpenseDocs() async {
    try {
      final totalsCol =
          FirestoreService.getCollection('totalSiteExpensesPerDay');
      final snap = await totalsCol.get();
      for (final doc in snap.docs) {
        final docId = doc.id;
        // If document ID does not contain '_' or uses site name alone
        if (!docId.contains('_')) {
          final canonicalDocId = await resolveCanonicalSiteDocId(docId);
          if (canonicalDocId != docId && canonicalDocId.contains('_')) {
            print(
              "🔄 Migrating legacy duplicate totalSiteExpensesPerDay/$docId -> $canonicalDocId",
            );
            final data = doc.data();
            await totalsCol
                .doc(canonicalDocId)
                .set(data, SetOptions(merge: true));
            await doc.reference.delete();
            await recalcTotalsAndSyncProject(canonicalDocId);
            print("✅ Purged legacy duplicate document: $docId");
          }
        }
      }
    } catch (e) {
      print("❌ Error cleaning up duplicate totalSiteExpensesPerDay docs: $e");
    }
  }

  // Recalculate all expense category totals and sync with project document
  static Future<void> recalcTotalsAndSyncProject(String siteId) async {
    if (siteId.isEmpty || siteId == 'uninitialized') return;
    try {
      final details = await resolveSiteDetails(siteId);
      final canonicalDocId = details.canonicalDocId;
      final siteKeys = details.allKeys;

      // Compute totals from all expense categories + Petty Cash concurrently in parallel
      final results = await Future.wait([
        _sumSupervisorExpenses(canonicalDocId, siteKeys),
        _sumManagerExpenses(canonicalDocId, siteKeys),
        _sumOrganizationExpenses(canonicalDocId, siteKeys),
        _sumContractorExpenses(canonicalDocId, siteKeys),
        _sumIncentiveExpenses(canonicalDocId, siteKeys),
        _sumPettyCashExpenses(canonicalDocId, siteKeys),
        _sumPettyCashReceived(canonicalDocId, siteKeys),
      ]);

      final supervisorTotal = results[0];
      final managerTotal = results[1];
      final organizationTotal = results[2];
      final contractorTotal = results[3];
      final incentiveTotal = results[4];
      final pettyCashExpenseTotal = results[5];
      final pettyCashReceivedTotal = results[6];

      final double totalAllExpenses = supervisorTotal +
          managerTotal +
          organizationTotal +
          contractorTotal +
          incentiveTotal +
          pettyCashExpenseTotal;

      final firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>>? projectRef =
          await _findExistingProjectDocBySiteId(canonicalDocId);
      final DocumentReference<Map<String, dynamic>>? siteRef =
          await _findExistingSiteDocBySiteId(canonicalDocId);

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

      // Document reference for total site expenses - ALWAYS uses canonical doc ID (e.g. ST001_AbineshHouse)
      final totalsRef = FirestoreService.getCollection('totalSiteExpensesPerDay')
          .doc(canonicalDocId);

      // Upsert totals document with merged fields
      batch.set(
        totalsRef,
        {
          'siteId': canonicalDocId,
          'siteCode': details.siteCode,
          'siteName': details.siteName,
          'totalSiteExpense': supervisorTotal + pettyCashExpenseTotal,
          'totalSupervisorExpense': supervisorTotal,
          'totalPettyCashExpense': pettyCashExpenseTotal,
          'totalPettyCashReceived': pettyCashReceivedTotal,
          'remainingPettyCash': (pettyCashReceivedTotal - pettyCashExpenseTotal),
          'totalMgrExpense': managerTotal,
          'totalOrgExpense': organizationTotal,
          'totalContractorExpense': contractorTotal,
          'totalIncentiveExpenses': incentiveTotal,
          'totalAllExpenses': totalAllExpenses,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Clean up any legacy duplicate documents in totalSiteExpensesPerDay (e.g. 'Abinesh House')
      final candidateLegacyIds = <String>{
        if (details.siteName.isNotEmpty && details.siteName != canonicalDocId)
          details.siteName,
        if (siteId != canonicalDocId) siteId,
        if (details.siteCode.isNotEmpty && details.siteCode != canonicalDocId)
          details.siteCode,
      };

      for (final legId in candidateLegacyIds) {
        try {
          final legRef = FirestoreService.getCollection(
            'totalSiteExpensesPerDay',
          ).doc(legId);
          final legSnap = await legRef.get();
          if (legSnap.exists) {
            batch.delete(legRef);
            print(
              "🗑️ Removed duplicate legacy document in totalSiteExpensesPerDay: $legId",
            );
          }
        } catch (_) {}
      }

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
      if (siteRef != null &&
          (projectRef == null || siteRef.path != projectRef.path)) {
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
        "✅ Synced totals for site $canonicalDocId (requested: $siteId) — Supervisor: $supervisorTotal, Petty Cash Spent: $pettyCashExpenseTotal (Rec: $pettyCashReceivedTotal), Manager: $managerTotal, Organization: $organizationTotal, Contractor: $contractorTotal, Incentive: $incentiveTotal, Total: $totalAllExpenses",
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
      "ℹ️ updateTotalIncentiveExpensesForSite called — recalculating all totals.",
    );
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
      final querySiteName = await FirestoreService.projects
          .where('siteName', isEqualTo: siteId)
          .limit(1)
          .get();
      if (querySiteName.docs.isNotEmpty) {
        return querySiteName.docs.first.reference;
      }
      final queryProjectName = await FirestoreService.projects
          .where('projectName', isEqualTo: siteId)
          .limit(1)
          .get();
      if (queryProjectName.docs.isNotEmpty) {
        return queryProjectName.docs.first.reference;
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
      final querySiteName = await FirestoreService.getCollection('Site')
          .where('siteName', isEqualTo: siteId)
          .limit(1)
          .get();
      if (querySiteName.docs.isNotEmpty) {
        return querySiteName.docs.first.reference;
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

  /// Resolves canonical document ID, code, name, and search keys for any site identifier
  static Future<SiteDetails> resolveSiteDetails(String inputId) async {
    final trimmed = inputId.trim();
    final keys = <String>{trimmed};
    String resolvedDocId = '';
    String resolvedCode = '';
    String resolvedName = '';
    String? resolvedSupervisor;
    String? resolvedSupervisorId;
    String? resolvedLocation;
    String? resolvedProjectName;
    String? resolvedProjectStage;

    try {
      // 1. Check Site collection
      DocumentSnapshot<Map<String, dynamic>>? sSnap;
      final directSite =
          await FirestoreService.getCollection('Site').doc(trimmed).get();
      if (directSite.exists && directSite.data() != null) {
        sSnap = directSite;
      } else {
        final qSiteId = await FirestoreService.getCollection('Site')
            .where('siteId', isEqualTo: trimmed)
            .limit(1)
            .get();
        if (qSiteId.docs.isNotEmpty) {
          sSnap = qSiteId.docs.first;
        } else {
          final qSiteName = await FirestoreService.getCollection('Site')
              .where('siteName', isEqualTo: trimmed)
              .limit(1)
              .get();
          if (qSiteName.docs.isNotEmpty) {
            sSnap = qSiteName.docs.first;
          } else {
            final qSite = await FirestoreService.getCollection('Site')
                .where('site', isEqualTo: trimmed)
                .limit(1)
                .get();
            if (qSite.docs.isNotEmpty) {
              sSnap = qSite.docs.first;
            }
          }
        }
      }

      if (sSnap != null && sSnap.data() != null) {
        final d = sSnap.data()!;
        if (sSnap.id.contains('_')) {
          resolvedDocId = sSnap.id;
        }
        final sIdVal = (d['siteId'] ?? d['siteCode'] ?? '').toString().trim();
        final sNameVal = (d['siteName'] ?? d['name'] ?? '').toString().trim();
        if (sIdVal.isNotEmpty) {
          resolvedCode = sIdVal;
          keys.add(sIdVal);
        }
        if (sNameVal.isNotEmpty) {
          resolvedName = sNameVal;
          keys.add(sNameVal);
        }
        if (d['site'] != null) keys.add(d['site'].toString().trim());
        if (d['location'] != null) keys.add(d['location'].toString().trim());
        keys.add(sSnap.id);

        if (d['supervisor'] != null) resolvedSupervisor = d['supervisor'].toString();
        if (d['Supervisor ID'] != null || d['supervisorId'] != null) {
          resolvedSupervisorId = (d['Supervisor ID'] ?? d['supervisorId']).toString();
        }
        if (d['location'] != null) resolvedLocation = d['location'].toString();
        if (d['projectName'] != null || d['project'] != null) {
          resolvedProjectName = (d['projectName'] ?? d['project']).toString();
        }
        if (d['projectStage'] != null || d['stage'] != null) {
          resolvedProjectStage = (d['projectStage'] ?? d['stage']).toString();
        }
      }

      // 2. Check projects collection if needed
      if (resolvedDocId.isEmpty ||
          resolvedCode.isEmpty ||
          resolvedName.isEmpty) {
        DocumentSnapshot<Map<String, dynamic>>? pSnap;
        final directProj = await FirestoreService.projects.doc(trimmed).get();
        if (directProj.exists && directProj.data() != null) {
          pSnap = directProj;
        } else {
          final qpSiteId = await FirestoreService.projects
              .where('siteId', isEqualTo: trimmed)
              .limit(1)
              .get();
          if (qpSiteId.docs.isNotEmpty) {
            pSnap = qpSiteId.docs.first;
          } else {
            final qpSiteName = await FirestoreService.projects
                .where('siteName', isEqualTo: trimmed)
                .limit(1)
                .get();
            if (qpSiteName.docs.isNotEmpty) {
              pSnap = qpSiteName.docs.first;
            } else {
              final qpProjName = await FirestoreService.projects
                  .where('projectName', isEqualTo: trimmed)
                  .limit(1)
                  .get();
              if (qpProjName.docs.isNotEmpty) {
                pSnap = qpProjName.docs.first;
              }
            }
          }
        }

        if (pSnap != null && pSnap.data() != null) {
          final pd = pSnap.data()!;
          final pSiteId = (pd['siteId'] ?? '').toString().trim();
          final pSiteName =
              (pd['siteName'] ?? pd['projectName'] ?? '').toString().trim();
          if (pSiteId.contains('_') && resolvedDocId.isEmpty) {
            resolvedDocId = pSiteId;
          }
          if (resolvedCode.isEmpty && pSiteId.isNotEmpty) {
            resolvedCode =
                pSiteId.contains('_') ? pSiteId.split('_').first : pSiteId;
          }
          if (resolvedName.isEmpty && pSiteName.isNotEmpty) {
            resolvedName = pSiteName;
          }
          if (pSiteId.isNotEmpty) keys.add(pSiteId);
          if (pSiteName.isNotEmpty) keys.add(pSiteName);
          keys.add(pSnap.id);
          if (pSnap.id.contains('_')) keys.add(pSnap.id.split('_').first);

          if (resolvedSupervisor == null && pd['supervisor'] != null) resolvedSupervisor = pd['supervisor'].toString();
          if (resolvedSupervisorId == null && (pd['Supervisor ID'] != null || pd['supervisorId'] != null)) {
            resolvedSupervisorId = (pd['Supervisor ID'] ?? pd['supervisorId']).toString();
          }
          if (resolvedLocation == null && pd['location'] != null) resolvedLocation = pd['location'].toString();
          if (resolvedProjectName == null && (pd['projectName'] ?? pd['project'] != null)) {
            resolvedProjectName = (pd['projectName'] ?? pd['project']).toString();
          }
          if (resolvedProjectStage == null && (pd['projectStage'] ?? pd['stage'] != null)) {
            resolvedProjectStage = (pd['projectStage'] ?? pd['stage']).toString();
          }
        }
      }

      // 3. Check siteSupervisorMap collection if needed
      final mapSnap = await FirestoreService.siteSupervisorMap.get();
      for (var doc in mapSnap.docs) {
        final md = doc.data();
        final mSite = (md['site'] ?? '').toString().trim();
        final mSiteId = (md['siteId'] ?? '').toString().trim();
        final mSiteName =
            (md['siteName'] ?? md['projectName'] ?? '').toString().trim();
        final mDocId = doc.id;

        if (mDocId == trimmed ||
            mSite == trimmed ||
            mSiteId == trimmed ||
            mSiteName == trimmed ||
            (mSiteName.isNotEmpty &&
                mSiteName.toLowerCase() == trimmed.toLowerCase())) {
          if (mSite.contains('_') && resolvedDocId.isEmpty) {
            resolvedDocId = mSite;
          }
          if (mSiteId.contains('_') && resolvedDocId.isEmpty) {
            resolvedDocId = mSiteId;
          }
          if (resolvedCode.isEmpty &&
              mSiteId.isNotEmpty &&
              !mSiteId.contains('_')) {
            resolvedCode = mSiteId;
          }
          if (resolvedName.isEmpty && mSiteName.isNotEmpty) {
            resolvedName = mSiteName;
          }
          if (mSite.isNotEmpty) keys.add(mSite);
          if (mSiteId.isNotEmpty) keys.add(mSiteId);
          if (mSiteName.isNotEmpty) keys.add(mSiteName);

          if (resolvedSupervisor == null && md['supervisor'] != null) resolvedSupervisor = md['supervisor'].toString();
          if (resolvedSupervisorId == null && (md['Supervisor ID'] ?? md['supervisorId']) != null) {
            resolvedSupervisorId = (md['Supervisor ID'] ?? md['supervisorId']).toString();
          }
          if (resolvedLocation == null && md['location'] != null) resolvedLocation = md['location'].toString();
          if (resolvedProjectName == null && (md['projectName'] ?? md['project']) != null) {
            resolvedProjectName = (md['projectName'] ?? md['project']).toString();
          }
          if (resolvedProjectStage == null && (md['projectStage'] ?? md['stage']) != null) {
            resolvedProjectStage = (md['projectStage'] ?? md['stage']).toString();
          }
          break;
        }
      }
    } catch (e) {
      print("❌ Error in _resolveSiteDetails for $trimmed: $e");
    }

    // Determine final canonical doc ID: SiteCode_SiteName (e.g. ST001_AbineshHouse)
    String canonicalDocId;
    if (resolvedDocId.isNotEmpty && resolvedDocId.contains('_')) {
      canonicalDocId = resolvedDocId.replaceAll(' ', '');
    } else if (resolvedCode.isNotEmpty && resolvedName.isNotEmpty) {
      canonicalDocId = formatCanonicalSiteDocId(resolvedCode, resolvedName);
    } else if (trimmed.contains('_')) {
      canonicalDocId = trimmed.replaceAll(' ', '');
    } else if (resolvedCode.isNotEmpty) {
      canonicalDocId = '${resolvedCode}_${trimmed.replaceAll(' ', '')}';
    } else {
      canonicalDocId = trimmed.replaceAll(' ', '');
    }

    if (canonicalDocId.toUpperCase().startsWith('PR')) {
      canonicalDocId = 'ST${canonicalDocId.substring(2)}';
    }

    if (resolvedCode.isEmpty && canonicalDocId.contains('_')) {
      resolvedCode = canonicalDocId.split('_').first;
    }
    if (resolvedCode.toUpperCase().startsWith('PR')) {
      resolvedCode = 'ST${resolvedCode.substring(2)}';
    }
    if (resolvedName.isEmpty && canonicalDocId.contains('_')) {
      resolvedName = canonicalDocId.split('_').skip(1).join('_');
    }

    keys.add(canonicalDocId);
    if (resolvedCode.isNotEmpty) keys.add(resolvedCode);
    if (resolvedName.isNotEmpty) keys.add(resolvedName);
    // Include project alias so cross-collection queries for expenses match legacy docs
    if (canonicalDocId.toUpperCase().startsWith('ST') &&
        canonicalDocId.contains('_')) {
      final prDocId = 'PR${canonicalDocId.substring(2)}';
      keys.add(prDocId);
      keys.add(prDocId.split('_').first);
    }
    keys.removeWhere((k) => k.isEmpty);

    return SiteDetails(
      canonicalDocId: canonicalDocId,
      siteCode: resolvedCode,
      siteName: resolvedName,
      allKeys: keys,
      supervisor: resolvedSupervisor,
      supervisorId: resolvedSupervisorId,
      location: resolvedLocation,
      projectName: resolvedProjectName,
      projectStage: resolvedProjectStage,
    );
  }

  /// Helper to resolve all possible identifier aliases for a site (docId, siteId, site, siteName)
  static Future<Set<String>> resolveSiteKeys(String siteId) async {
    final details = await resolveSiteDetails(siteId);
    return details.allKeys;
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
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
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
        // Skip manager or org entries recorded in supervisor collection, and any petty cash flagged entries
        if (data['isManagerEntry'] == true ||
            data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true ||
            data['createdBy'] == 'manager_org' ||
            data['isPettyCash'] == true ||
            data['isPettyCashExpense'] == true) {
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
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
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
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
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
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
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
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
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

  // Sum petty cash expenses spent for the site
  static Future<double> _sumPettyCashExpenses(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      for (final key in siteKeys) {
        final snap1 = await FirestoreService.pettyCashTransactions
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snap1.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap2 = await FirestoreService.pettyCashTransactions
            .where('siteName', isEqualTo: key)
            .get();
        for (final doc in snap2.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      // Ingest all petty cash transactions to match site identifiers
      try {
        final allTxnsSnap = await FirestoreService.pettyCashTransactions.get();
        for (final doc in allTxnsSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? '').toString().trim();
          final sName = (data['siteName'] ?? '').toString().trim();
          for (final key in siteKeys) {
            if (sId == key ||
                sName == key ||
                (sId.isNotEmpty && sId.toLowerCase() == key.toLowerCase()) ||
                (sName.isNotEmpty && sName.toLowerCase() == key.toLowerCase()) ||
                doc.id.startsWith('${key}_')) {
              matchedDocs[doc.id] = data;
            }
          }
        }
      } catch (_) {}

      for (final data in matchedDocs.values) {
        final txnType = (data['transactionType'] ?? 'EXPENSE').toString().toUpperCase();
        if (txnType == 'EXPENSE') {
          final amount = _parseExpenseAmount(data['amount'], data);
          total += amount;
        }
      }
    } catch (e) {
      print("❌ Error summing petty cash expenses for siteId=$siteId: $e");
    }
    return total;
  }

  // Sum confirmed petty cash allocated/received for the site
  static Future<double> _sumPettyCashReceived(String siteId, [Set<String>? preResolvedSiteKeys]) async {
    double total = 0.0;
    try {
      final siteKeys = preResolvedSiteKeys ?? await resolveSiteKeys(siteId);
      final Map<String, Map<String, dynamic>> matchedDocs = {};

      for (final key in siteKeys) {
        final snap1 = await FirestoreService.pettyCashRequests
            .where('siteId', isEqualTo: key)
            .get();
        for (final doc in snap1.docs) {
          matchedDocs[doc.id] = doc.data();
        }

        final snap2 = await FirestoreService.pettyCashRequests
            .where('siteName', isEqualTo: key)
            .get();
        for (final doc in snap2.docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      try {
        final allReqSnap = await FirestoreService.pettyCashRequests.get();
        for (final doc in allReqSnap.docs) {
          final data = doc.data();
          final sId = (data['siteId'] ?? '').toString().trim();
          final sName = (data['siteName'] ?? '').toString().trim();
          for (final key in siteKeys) {
            if (sId == key ||
                sName == key ||
                (sId.isNotEmpty && sId.toLowerCase() == key.toLowerCase()) ||
                (sName.isNotEmpty && sName.toLowerCase() == key.toLowerCase())) {
              matchedDocs[doc.id] = data;
            }
          }
        }
      } catch (_) {}

      for (final data in matchedDocs.values) {
        final isReceived = data['isReceived'] == true ||
            data['receivedAt'] != null ||
            data['status'] == 'received';
        if (isReceived) {
          final double approvedAmt = (data['approvedAmount'] is num && (data['approvedAmount'] as num) > 0)
              ? (data['approvedAmount'] as num).toDouble()
              : ((data['allocatedAmount'] is num && (data['allocatedAmount'] as num) > 0)
                  ? (data['allocatedAmount'] as num).toDouble()
                  : ((data['requestedAmount'] is num) ? (data['requestedAmount'] as num).toDouble() : 0.0));
          total += approvedAmt;
        }
      }
    } catch (e) {
      print("❌ Error summing petty cash received for siteId=$siteId: $e");
    }
    return total;
  }
}