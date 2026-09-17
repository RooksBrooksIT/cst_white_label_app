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
  static final Map<String, SiteDetails> _siteDetailsCache = {};
  static final Map<String, DateTime> _siteDetailsCacheTimestamp = {};
  static const Duration _siteCacheTtl = Duration(minutes: 5);

  /// Clears or invalidates cached site details
  static void invalidateSiteCache([String? siteKey]) {
    if (siteKey != null && siteKey.isNotEmpty) {
      final k = siteKey.trim().toLowerCase();
      _siteDetailsCache.remove(k);
      _siteDetailsCache.remove(siteKey);
      _siteDetailsCacheTimestamp.remove(k);
      _siteDetailsCacheTimestamp.remove(siteKey);
    } else {
      _siteDetailsCache.clear();
      _siteDetailsCacheTimestamp.clear();
    }
  }

  /// Returns synchronously cached SiteDetails if available and not expired.
  static SiteDetails? getCachedSiteDetails(String siteKey) {
    if (siteKey.isEmpty || siteKey == 'uninitialized') return null;
    final k = siteKey.trim().toLowerCase();
    final cachedTime = _siteDetailsCacheTimestamp[k];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _siteCacheTtl &&
        _siteDetailsCache.containsKey(k)) {
      return _siteDetailsCache[k];
    }
    return null;
  }

  /// Manually populate or update cached SiteDetails
  static void cacheSiteDetails(SiteDetails details) {
    final now = DateTime.now();
    final keys = {
      details.canonicalDocId,
      details.siteCode,
      details.siteName,
      ...details.allKeys,
    };
    for (final k in keys) {
      if (k.isNotEmpty) {
        final lk = k.toLowerCase().trim();
        _siteDetailsCache[lk] = details;
        _siteDetailsCacheTimestamp[lk] = now;
      }
    }
  }

  /// Formats canonical site document ID in the format: SiteCode_SiteName (e.g. ST001_Testing)
  static String formatCanonicalSiteDocId(String siteCode, String siteName) {
    var cleanCode = siteCode.trim();
    var cleanName = siteName.trim();

    // 1. Normalize project prefixes if any (PR -> ST)
    if (cleanCode.toUpperCase().startsWith('PR')) {
      cleanCode = 'ST${cleanCode.substring(2)}';
    }

    // 2. Extract site code and name components if cleanCode has underscores
    if (cleanCode.contains('_')) {
      final parts = cleanCode.split('_').where((p) => p.trim().isNotEmpty).toList();
      String? extractedCode;
      final nameParts = <String>[];
      for (final p in parts) {
        final pNorm = p.toUpperCase().startsWith('PR') ? 'ST${p.substring(2)}' : p;
        if (extractedCode == null && (pNorm.toUpperCase().startsWith('ST') || RegExp(r'^[A-Z]{2}\d+').hasMatch(pNorm))) {
          extractedCode = pNorm;
        } else if (pNorm != extractedCode) {
          nameParts.add(p);
        }
      }
      if (extractedCode != null) {
        cleanCode = extractedCode;
      }
      if (cleanName.isEmpty && nameParts.isNotEmpty) {
        cleanName = nameParts.join('_');
      }
    }

    // 3. Extract site code and name components if cleanName has underscores
    if (cleanName.contains('_')) {
      final parts = cleanName.split('_').where((p) => p.trim().isNotEmpty).toList();
      String? extractedCode;
      final nameParts = <String>[];
      for (final p in parts) {
        final pNorm = p.toUpperCase().startsWith('PR') ? 'ST${p.substring(2)}' : p;
        if (extractedCode == null && (pNorm.toUpperCase().startsWith('ST') || RegExp(r'^[A-Z]{2}\d+').hasMatch(pNorm))) {
          extractedCode = pNorm;
        } else if (pNorm != extractedCode && (cleanCode.isEmpty || pNorm.toLowerCase() != cleanCode.toLowerCase())) {
          nameParts.add(p);
        }
      }
      if (cleanCode.isEmpty && extractedCode != null) {
        cleanCode = extractedCode;
      }
      if (nameParts.isNotEmpty) {
        cleanName = nameParts.join('_');
      } else if (extractedCode != null && cleanCode == extractedCode) {
        cleanName = '';
      }
    }

    // 4. Repeatedly strip cleanCode / ST... prefixes from cleanName
    cleanCode = cleanCode.replaceAll(' ', '');
    cleanName = cleanName.replaceAll(' ', '');

    final codeLower = cleanCode.toLowerCase();
    while (cleanName.isNotEmpty && cleanCode.isNotEmpty) {
      final nameLower = cleanName.toLowerCase();
      if (nameLower.startsWith('${codeLower}_')) {
        cleanName = cleanName.substring(cleanCode.length + 1).trim();
      } else if (nameLower == codeLower) {
        cleanName = '';
        break;
      } else if (nameLower.startsWith(codeLower) && cleanName.length > cleanCode.length) {
        cleanName = cleanName.substring(cleanCode.length).trim();
        if (cleanName.startsWith('_')) cleanName = cleanName.substring(1).trim();
      } else {
        break;
      }
    }

    if (cleanCode.isNotEmpty && cleanName.isNotEmpty && cleanCode.toLowerCase() != cleanName.toLowerCase()) {
      return '${cleanCode}_$cleanName';
    } else if (cleanCode.isNotEmpty) {
      return cleanCode;
    } else {
      return cleanName;
    }
  }

  /// Formats any combination of raw site ID, site code, and site name into the standardized
  /// SiteCode_SiteName format (e.g. ST001_Testing).
  static String formatCanonicalSiteId({
    required String rawId,
    String? siteCode,
    String? siteName,
  }) {
    final cleanRaw = rawId.trim();
    final cleanCode = (siteCode ?? '').trim();
    final cleanName = (siteName ?? '').trim();

    if (cleanCode.isNotEmpty || cleanName.isNotEmpty) {
      return formatCanonicalSiteDocId(
        cleanCode.isNotEmpty ? cleanCode : cleanRaw,
        cleanName.isNotEmpty ? cleanName : cleanRaw,
      );
    }

    return formatCanonicalSiteDocId(cleanRaw, '');
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
  /// that uses site name alone, duplicated prefixes, or non-canonical doc ID, merging totals into the canonical document.
  static Future<void> cleanupDuplicateSiteExpenseDocs() async {
    try {
      final totalsCol =
          FirestoreService.getCollection('totalSiteExpensesPerDay');
      final snap = await totalsCol.get();
      for (final doc in snap.docs) {
        final docId = doc.id;
        final canonicalDocId = await resolveCanonicalSiteDocId(docId);
        if (canonicalDocId.isNotEmpty && canonicalDocId != docId) {
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
      final refResults = await Future.wait([
        _findExistingProjectDocBySiteId(canonicalDocId),
        _findExistingSiteDocBySiteId(canonicalDocId),
      ]);
      final DocumentReference<Map<String, dynamic>>? projectRef = refResults[0];
      final DocumentReference<Map<String, dynamic>>? siteRef = refResults[1];

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

      // Clean up any legacy duplicate documents in totalSiteExpensesPerDay (e.g. 'Abinesh House', 'ST001_ST001_Testing', 'PR001_Testing', 'ST001')
      final candidateLegacyIds = <String>{
        if (details.siteName.isNotEmpty && details.siteName != canonicalDocId)
          details.siteName,
        if (siteId != canonicalDocId) siteId,
        if (details.siteCode.isNotEmpty && details.siteCode != canonicalDocId)
          details.siteCode,
        '${details.siteCode}_$canonicalDocId',
        '${details.siteCode}_${details.siteCode}_${details.siteName}',
        if (canonicalDocId.startsWith('ST')) 'PR${canonicalDocId.substring(2)}',
        if (details.siteCode.startsWith('ST')) 'PR${details.siteCode.substring(2)}_${details.siteName}',
      };
      candidateLegacyIds.remove(canonicalDocId);
      candidateLegacyIds.removeWhere((id) => id.trim().isEmpty);

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
      final docSnap = await FirestoreService.findLinkedProjectDoc(
        siteDocId: siteId,
        siteCode: siteId,
        siteName: siteId,
      );
      if (docSnap != null && docSnap.exists) {
        return docSnap.reference;
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
      final siteSnap = await FirestoreService.findLinkedSiteDoc(
        projectDocId: siteId,
        siteId: siteId,
      );
      if (siteSnap != null && siteSnap.exists) {
        return siteSnap.reference;
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
    if (trimmed.isEmpty || trimmed == 'uninitialized') {
      return SiteDetails(
        canonicalDocId: trimmed,
        siteCode: '',
        siteName: '',
        allKeys: {trimmed},
      );
    }

    final cacheKey = trimmed.toLowerCase();
    final cachedTime = _siteDetailsCacheTimestamp[cacheKey];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _siteCacheTtl &&
        _siteDetailsCache.containsKey(cacheKey)) {
      return _siteDetailsCache[cacheKey]!;
    }

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
          resolvedName.isEmpty ||
          resolvedSupervisor == null ||
          resolvedSupervisorId == null ||
          resolvedProjectStage == null) {
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

          if (resolvedSupervisor == null) {
            final sup = pd['supervisor'] ??
                pd['supervisorName'] ??
                pd['Supervisor'] ??
                pd['supervisor_name'] ??
                pd['FullName'] ??
                pd['fullName'] ??
                pd['name'] ??
                pd['username'] ??
                pd['UserName'];
            if (sup != null && sup.toString().trim().isNotEmpty) {
              resolvedSupervisor = sup.toString().trim();
            }
          }
          if (resolvedSupervisorId == null) {
            final supId = pd['Supervisor ID'] ??
                pd['supervisorId'] ??
                pd['SupervisorId'] ??
                pd['supervisor_id'] ??
                pd['assignedSupervisor'];
            if (supId != null && supId.toString().trim().isNotEmpty) {
              resolvedSupervisorId = supId.toString().trim();
            }
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
      if (resolvedSupervisor == null || resolvedSupervisorId == null || resolvedProjectStage == null) {
        final mapSnap = await FirestoreService.siteSupervisorMap.get();
        for (var doc in mapSnap.docs) {
          final md = doc.data();
          final mDocId = doc.id.trim();
          final mSiteDocId = (md['siteDocId'] ?? '').toString().trim();
          final mSite = (md['site'] ?? '').toString().trim();
          final mSiteId = (md['siteId'] ?? '').toString().trim();
          final mSiteName =
              (md['siteName'] ?? md['projectName'] ?? md['site_name'] ?? md['location'] ?? '').toString().trim();

          final matchKeys = {
            mDocId.toLowerCase(),
            mSiteDocId.toLowerCase(),
            mSite.toLowerCase(),
            mSiteId.toLowerCase(),
            mSiteName.toLowerCase(),
            mSiteName.replaceAll(' ', '').toLowerCase(),
          };

          final isMatch = matchKeys.contains(trimmed.toLowerCase()) ||
              matchKeys.contains(trimmed.replaceAll(' ', '').toLowerCase()) ||
              (resolvedCode.isNotEmpty && matchKeys.contains(resolvedCode.toLowerCase())) ||
              (resolvedName.isNotEmpty && matchKeys.contains(resolvedName.toLowerCase())) ||
              (resolvedDocId.isNotEmpty && matchKeys.contains(resolvedDocId.toLowerCase()));

          if (isMatch) {
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

            if (resolvedSupervisor == null) {
              final sup = md['supervisor'] ??
                  md['supervisorName'] ??
                  md['Supervisor'] ??
                  md['supervisor_name'] ??
                  md['FullName'] ??
                  md['fullName'] ??
                  md['name'] ??
                  md['username'] ??
                  md['UserName'];
              if (sup != null && sup.toString().trim().isNotEmpty) {
                resolvedSupervisor = sup.toString().trim();
              }
            }

            if (resolvedSupervisorId == null) {
              final supId = md['Supervisor ID'] ??
                  md['supervisorId'] ??
                  md['SupervisorId'] ??
                  md['supervisor_id'] ??
                  md['assignedSupervisor'];
              if (supId != null && supId.toString().trim().isNotEmpty) {
                resolvedSupervisorId = supId.toString().trim();
              }
            }

            if (resolvedLocation == null && md['location'] != null) resolvedLocation = md['location'].toString();
            if (resolvedProjectName == null && (md['projectName'] ?? md['project']) != null) {
              resolvedProjectName = (md['projectName'] ?? md['project']).toString();
            }
            if (resolvedProjectStage == null && (md['projectStage'] ?? md['stage']) != null) {
              resolvedProjectStage = (md['projectStage'] ?? md['stage']).toString();
            }
            if (resolvedSupervisor != null || resolvedSupervisorId != null) break;
          }
        }
      }
    } catch (e) {
      print("❌ Error in _resolveSiteDetails for $trimmed: $e");
    }

    // Determine final canonical doc ID: SiteCode_SiteName (e.g. ST001_Testing)
    String canonicalDocId = formatCanonicalSiteDocId(
      resolvedCode.isNotEmpty
          ? resolvedCode
          : (resolvedDocId.isNotEmpty ? resolvedDocId : trimmed),
      resolvedName.isNotEmpty
          ? resolvedName
          : (resolvedDocId.isNotEmpty ? resolvedDocId : trimmed),
    );

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

    final details = SiteDetails(
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

    final now = DateTime.now();
    _siteDetailsCache[cacheKey] = details;
    _siteDetailsCacheTimestamp[cacheKey] = now;
    if (canonicalDocId.isNotEmpty) {
      final canKey = canonicalDocId.toLowerCase();
      _siteDetailsCache[canKey] = details;
      _siteDetailsCacheTimestamp[canKey] = now;
    }
    for (final k in keys) {
      final lk = k.toLowerCase();
      _siteDetailsCache[lk] = details;
      _siteDetailsCacheTimestamp[lk] = now;
    }

    return details;
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.siteSupervisorEntries.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.siteSupervisorEntries.where('site', isEqualTo: key).get());
        queryFutures.add(FirestoreService.siteSupervisorEntries.where('siteName', isEqualTo: key).get());
      }
      queryFutures.add(FirestoreService.siteSupervisorEntries.get());

      final snapshots = await Future.wait(queryFutures);
      for (int i = 0; i < snapshots.length - 1; i++) {
        for (final doc in snapshots[i].docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      final allEntriesSnap = snapshots.last;
      for (final doc in allEntriesSnap.docs) {
        for (final key in siteKeys) {
          if (doc.id.startsWith('${key}_') ||
              doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
            matchedDocs[doc.id] = doc.data();
          }
        }
      }

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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      // 1. Direct managerExpenses
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.managerExpenses.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.managerExpenses.where('site', isEqualTo: key).get());
        queryFutures.add(FirestoreService.managerExpenses.where('projectName', isEqualTo: key).get());
      }
      final directExpCount = queryFutures.length;

      // 2. managerExpenseSummary
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.managerExpenseSummary.where('siteId', isEqualTo: key).get());
      }
      final summaryCount = queryFutures.length - directExpCount;

      // 3. managerEntries
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.managerEntries.where('siteId', isEqualTo: key).get());
      }
      final mgrEntriesCount = queryFutures.length - directExpCount - summaryCount;

      // 4. supervisor entries for manager entries
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.siteSupervisorEntries.where('siteId', isEqualTo: key).get());
      }

      // All collections full snap for prefix matching
      queryFutures.add(FirestoreService.managerExpenses.get());
      queryFutures.add(FirestoreService.managerExpenseSummary.get());

      final results = await Future.wait(queryFutures);

      int idx = 0;
      // 1. Ingest direct managerExpenses
      for (int i = 0; i < directExpCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      // 2. Ingest managerExpenseSummary
      for (int i = 0; i < summaryCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs.putIfAbsent(doc.id, () => doc.data());
        }
      }

      // 3. Ingest managerEntries
      for (int i = 0; i < mgrEntriesCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs.putIfAbsent('mgr_${doc.id}', () => doc.data());
        }
      }

      // 4. Ingest supervisorEntries for manager entries
      final remainingCount = siteKeys.length;
      for (int i = 0; i < remainingCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          final data = doc.data();
          if (data['isManagerEntry'] == true || data['createdBy'] == 'manager') {
            matchedDocs.putIfAbsent('sup_mgr_${doc.id}', () => data);
          }
        }
      }

      // Prefix matches from full scans
      final allExpSnap = results[idx++];
      for (final doc in allExpSnap.docs) {
        for (final key in siteKeys) {
          if (doc.id.startsWith('${key}_') ||
              doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
            matchedDocs[doc.id] = doc.data();
          }
        }
      }

      final allSummarySnap = results[idx++];
      for (final doc in allSummarySnap.docs) {
        for (final key in siteKeys) {
          if (doc.id.startsWith('${key}_') ||
              doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
            matchedDocs.putIfAbsent(doc.id, () => doc.data());
          }
        }
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      // 1. Direct organizationEntries
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.organizationEntries.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.organizationEntries.where('site', isEqualTo: key).get());
      }
      final directOrgCount = queryFutures.length;

      // 2. organizationExpenses
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.getCollection('organizationExpenses').where('siteId', isEqualTo: key).get());
      }
      final orgExpCount = queryFutures.length - directOrgCount;

      // 3. organizationExpenseSummary
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.organizationExpenseSummary.where('siteId', isEqualTo: key).get());
      }
      final orgSumCount = queryFutures.length - directOrgCount - orgExpCount;

      // 4. supervisorEntries for org
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.siteSupervisorEntries.where('siteId', isEqualTo: key).get());
      }

      // Full snaps for prefix match
      queryFutures.add(FirestoreService.organizationEntries.get());
      queryFutures.add(FirestoreService.organizationExpenseSummary.get());

      final results = await Future.wait(queryFutures);

      int idx = 0;
      for (int i = 0; i < directOrgCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      for (int i = 0; i < orgExpCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs.putIfAbsent(doc.id, () => doc.data());
        }
      }

      for (int i = 0; i < orgSumCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs.putIfAbsent(doc.id, () => doc.data());
        }
      }

      final supOrgCount = siteKeys.length;
      for (int i = 0; i < supOrgCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          final data = doc.data();
          if (data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
            matchedDocs.putIfAbsent('sup_org_${doc.id}', () => data);
          }
        }
      }

      final allOrgSnap = results[idx++];
      for (final doc in allOrgSnap.docs) {
        for (final key in siteKeys) {
          if (doc.id.startsWith('${key}_') ||
              doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
            matchedDocs[doc.id] = doc.data();
          }
        }
      }

      final allOrgSumSnap = results[idx++];
      for (final doc in allOrgSumSnap.docs) {
        for (final key in siteKeys) {
          if (doc.id.startsWith('${key}_') ||
              doc.id.toLowerCase().startsWith('${key.toLowerCase()}_')) {
            matchedDocs.putIfAbsent(doc.id, () => doc.data());
          }
        }
      }

      for (final data in matchedDocs.values) {
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.contractorEntries.where('siteId', isEqualTo: key).get());
      }
      final snapshots = await Future.wait(queryFutures);
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.siteSupervisorIncentives.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.getCollection('supervisorIncentives').where('siteId', isEqualTo: key).get());
      }

      final snapshots = await Future.wait(queryFutures);
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          matchedDocs[doc.id] = doc.data();
        }
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      // 1. Transactions
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.pettyCashTransactions.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.pettyCashTransactions.where('siteName', isEqualTo: key).get());
      }
      final txnCount = queryFutures.length;

      // 2. Direct Petty Cash Expenses
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.pettyCashExpenses.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.pettyCashExpenses.where('siteName', isEqualTo: key).get());
      }
      final expCount = queryFutures.length - txnCount;

      // Full snapshots for prefix matching
      queryFutures.add(FirestoreService.pettyCashTransactions.get());
      queryFutures.add(FirestoreService.pettyCashExpenses.get());

      final results = await Future.wait(queryFutures);
      int idx = 0;
      for (int i = 0; i < txnCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      for (int i = 0; i < expCount; i++, idx++) {
        for (final doc in results[idx].docs) {
          matchedDocs.putIfAbsent('exp_${doc.id}', () => doc.data());
        }
      }

      final allTxnsSnap = results[idx++];
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

      final allExpSnap = results[idx++];
      for (final doc in allExpSnap.docs) {
        final data = doc.data();
        final sId = (data['siteId'] ?? '').toString().trim();
        final sName = (data['siteName'] ?? '').toString().trim();
        for (final key in siteKeys) {
          if (sId == key ||
              sName == key ||
              (sId.isNotEmpty && sId.toLowerCase() == key.toLowerCase()) ||
              (sName.isNotEmpty && sName.toLowerCase() == key.toLowerCase()) ||
              doc.id.startsWith('${key}_')) {
            matchedDocs.putIfAbsent('exp_${doc.id}', () => data);
          }
        }
      }

      final Set<String> processedExpenseIds = {};

      for (final entry in matchedDocs.entries) {
        final data = entry.value;
        final docKey = entry.key;

        // Check if this is a direct expense or transaction
        if (docKey.startsWith('exp_')) {
          final isApproved = data['status'] == 'EXPENSE_APPROVED' ||
              data['status'] == 'approved' ||
              data['status'] == 'APPROVED' ||
              data['isApproved'] == true ||
              data['postedToLedger'] == true;
          if (isApproved) {
            final expId = (data['expenseId'] ?? docKey.substring(4)).toString();
            if (!processedExpenseIds.contains(expId)) {
              processedExpenseIds.add(expId);
              final amount = _parseExpenseAmount(data['amount'], data);
              total += amount;
            }
          }
        } else {
          final txnType = (data['transactionType'] ?? 'EXPENSE').toString().toUpperCase();
          if (txnType == 'EXPENSE' || txnType == 'EXPENSE_APPROVED' || txnType.contains('EXPENSE')) {
            final refId = (data['referenceId'] ?? data['expenseId'] ?? '').toString();
            if (refId.isNotEmpty && processedExpenseIds.contains(refId)) {
              continue; // Already counted via direct expense
            }
            if (refId.isNotEmpty) {
              processedExpenseIds.add(refId);
            }
            final amount = _parseExpenseAmount(data['amount'], data);
            total += amount;
          }
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

      final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final key in siteKeys) {
        queryFutures.add(FirestoreService.pettyCashRequests.where('siteId', isEqualTo: key).get());
        queryFutures.add(FirestoreService.pettyCashRequests.where('siteName', isEqualTo: key).get());
      }
      queryFutures.add(FirestoreService.pettyCashRequests.get());

      final results = await Future.wait(queryFutures);
      for (int i = 0; i < results.length - 1; i++) {
        for (final doc in results[i].docs) {
          matchedDocs[doc.id] = doc.data();
        }
      }

      final allReqSnap = results.last;
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

      for (final data in matchedDocs.values) {
        final rawStatus = (data['status'] ?? '').toString().toLowerCase().trim();
        final isReceivedOrAllocated = data['isReceived'] == true ||
            data['receivedAt'] != null ||
            rawStatus == 'received' ||
            rawStatus == 'awaiting_receipt_confirmation' ||
            rawStatus == 'approved' ||
            rawStatus == 'disbursed' ||
            rawStatus == 'allocated' ||
            rawStatus == 'active';
        if (isReceivedOrAllocated) {
          final double approvedAmt = (data['approvedAmount'] is num && (data['approvedAmount'] as num) > 0)
              ? (data['approvedAmount'] as num).toDouble()
              : ((data['allocatedAmount'] is num && (data['allocatedAmount'] as num) > 0)
                  ? (data['allocatedAmount'] as num).toDouble()
                  : ((data['disbursedAmount'] is num && (data['disbursedAmount'] as num) > 0)
                      ? (data['disbursedAmount'] as num).toDouble()
                      : ((data['requestedAmount'] is num) ? (data['requestedAmount'] as num).toDouble() : 0.0)));
          total += approvedAmt;
        }
      }

      // Check site-based pettyCashAccounts for totalReceived / totalAllocated
      final orgId = FirestoreService.currentOrgId;
      for (final key in siteKeys) {
        try {
          final accDocId = orgId.isNotEmpty ? '${orgId}_$key' : key;
          final accSnap = await FirestoreService.pettyCashAccounts.doc(accDocId).get();
          if (accSnap.exists && accSnap.data() != null) {
            final aData = accSnap.data()!;
            final accAlloc = (aData['totalAllocated'] is num)
                ? (aData['totalAllocated'] as num).toDouble()
                : 0.0;
            final accRecv = (aData['totalReceived'] is num)
                ? (aData['totalReceived'] as num).toDouble()
                : accAlloc;
            final maxAcc = accRecv > accAlloc ? accRecv : accAlloc;
            if (maxAcc > total) {
              total = maxAcc;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print("❌ Error summing petty cash received for siteId=$siteId: $e");
    }
    return total;
  }
}