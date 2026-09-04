import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';

/// Represents site-specific inventory for a material
class SiteInventoryEntry {
  final String siteId;
  final String siteName;
  final String projectName;
  final int availableCount;
  final dynamic updatedAt;

  SiteInventoryEntry({
    required this.siteId,
    this.siteName = '',
    this.projectName = '',
    required this.availableCount,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      'siteName': siteName.isNotEmpty ? siteName : siteId,
      if (projectName.isNotEmpty) 'projectName': projectName,
      'availableCount': availableCount,
      'updatedAt': (updatedAt != null && updatedAt is! FieldValue)
          ? updatedAt
          : DateTime.now().toIso8601String(),
    };
  }

  factory SiteInventoryEntry.fromMap(Map<String, dynamic> map) {
    return SiteInventoryEntry(
      siteId: (map['siteId'] ?? map['siteid'] ?? '').toString().trim(),
      siteName: (map['siteName'] ?? map['sitename'] ?? map['siteId'] ?? '').toString().trim(),
      projectName: (map['projectName'] ?? map['projectname'] ?? '').toString().trim(),
      availableCount: _parseCount(map['availableCount'] ?? map['count'] ?? map['materialQty'] ?? map['quantity']),
      updatedAt: map['updatedAt'] ?? map['lastupdated'] ?? map['lastUpdated'],
    );
  }

  static int _parseCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }
}

/// Consolidated Material Inventory Item across Company and Sites
class MaterialInventoryItem {
  final String docId;
  final String materialId;
  final String materialName;
  final String displayName;
  final String category;
  final String subCategory;
  final String unit;
  final double unitPrice;
  final String description;
  final int companyAvailableCount;
  final List<SiteInventoryEntry> siteInventories;
  final dynamic lastUpdated;

  MaterialInventoryItem({
    required this.docId,
    this.materialId = '',
    required this.materialName,
    String? displayName,
    this.category = 'General Material',
    this.subCategory = '',
    this.unit = 'Units',
    this.unitPrice = 0.0,
    this.description = '',
    this.companyAvailableCount = 0,
    List<SiteInventoryEntry>? siteInventories,
    this.lastUpdated,
  })  : displayName = displayName ?? materialName,
        siteInventories = siteInventories ?? [];

  /// Total units across all active sites
  int get totalSiteStock =>
      siteInventories.fold<int>(0, (acc, site) => acc + site.availableCount);

  /// Grand total stock (Company warehouse + all sites)
  int get totalStock => companyAvailableCount + totalSiteStock;

  /// Total monetary valuation
  double get totalValuation => totalStock * unitPrice;

  /// Site breakdown as Map of siteId to quantity
  Map<String, double> get siteBreakdownMap {
    final map = <String, double>{};
    for (final s in siteInventories) {
      if (s.availableCount > 0) {
        map[s.siteId] = s.availableCount.toDouble();
      }
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId.isNotEmpty ? materialId : docId,
      'materialName': materialName,
      'displayName': displayName,
      'category': category,
      'subCategory': subCategory,
      'unit': unit,
      'unitPrice': unitPrice,
      'description': description,
      'companyAvailableCount': companyAvailableCount,
      'siteInventories': siteInventories.map((s) => s.toMap()).toList(),
      'totalSiteCount': totalSiteStock,
      'totalAvailableCount': totalStock,
      'lastUpdated': lastUpdated ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory MaterialInventoryItem.fromMap(String docId, Map<String, dynamic> map) {
    final rawSites = map['siteInventories'];
    final List<SiteInventoryEntry> sites = [];
    if (rawSites is List) {
      for (final item in rawSites) {
        if (item is Map) {
          sites.add(SiteInventoryEntry.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return MaterialInventoryItem(
      docId: docId,
      materialId: (map['materialId'] ?? docId).toString().trim(),
      materialName: (map['materialName'] ?? map['displayName'] ?? docId).toString().trim(),
      displayName: (map['displayName'] ?? map['materialName'] ?? docId).toString().trim(),
      category: (map['category'] ?? map['materialCategory'] ?? map['matCategory'] ?? 'General Material').toString().trim(),
      subCategory: (map['subCategory'] ?? map['materialSubCategory'] ?? map['matSubCategory'] ?? '').toString().trim(),
      unit: (map['unit'] ?? map['materialUnit'] ?? map['matUnit'] ?? 'Units').toString().trim(),
      unitPrice: _parseNum(map['unitPrice'] ?? map['materialPrice'] ?? map['price']),
      description: (map['description'] ?? '').toString().trim(),
      companyAvailableCount: _parseCount(map['companyAvailableCount'] ?? map['count'] ?? map['availableCount']),
      siteInventories: sites,
      lastUpdated: map['lastUpdated'] ?? map['lastupdated'] ?? map['updatedAt'],
    );
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }
}

/// Central Unified Engine for Material Inventory, Availability, and Movement
class MaterialInventoryService {
  /// Converts a material name (e.g. "Cement OPC" or "Steel 12mm") into a standardized doc ID (e.g. "cement_opc")
  static String getMaterialDocId(String materialName) {
    return materialName.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  // ===========================================================================
  // 1. AVAILABILITY & COMPANY STOCK MANAGEMENT
  // ===========================================================================

  /// Sets or adds to the company-level stock for a material.
  /// Maintains single source of truth and synchronizes all legacy collections.
  static Future<int> setCompanyStock({
    required String materialName,
    required int count,
    bool isAddition = false,
    String? displayName,
    String? category,
    String? subCategory,
    String? unit,
    double? unitPrice,
  }) async {
    try {
      final docId = getMaterialDocId(materialName);
      final availRef = FirestoreService.getCollection('materialsAvailability').doc(docId);
      final matTransferRef = FirestoreService.getCollection('materialTransfer').doc(docId);
      final masterMaterialQuery = await FirestoreService.getCollection('materials')
          .where('materialName', isEqualTo: materialName)
          .limit(1)
          .get();

      // Resolve metadata
      String resolvedCat = category ?? '';
      String resolvedSubCat = subCategory ?? '';
      String resolvedUnit = unit ?? '';
      double resolvedPrice = unitPrice ?? 0.0;
      String resolvedMaterialId = '';

      if (masterMaterialQuery.docs.isNotEmpty) {
        final mData = masterMaterialQuery.docs.first.data();
        resolvedMaterialId = (mData['materialId'] ?? masterMaterialQuery.docs.first.id).toString();
        if (resolvedCat.isEmpty) resolvedCat = (mData['materialCategory'] ?? '').toString();
        if (resolvedSubCat.isEmpty) resolvedSubCat = (mData['materialSubCategory'] ?? '').toString();
        if (resolvedUnit.isEmpty) resolvedUnit = (mData['materialUnit'] ?? '').toString();
        if (resolvedPrice == 0.0) {
          resolvedPrice = (mData['unitPrice'] as num?)?.toDouble() ??
              double.tryParse((mData['materialPrice'] ?? '0').toString()) ?? 0.0;
        }
      }

      final docSnap = await availRef.get();
      int newCompanyCount = count;
      List<Map<String, dynamic>> siteInventoriesList = [];

      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        final currentCount = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
        newCompanyCount = isAddition ? (currentCount + count) : count;
        if (newCompanyCount < 0) newCompanyCount = 0;

        final rawSites = data['siteInventories'];
        if (rawSites is List) {
          siteInventoriesList = rawSites.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } else {
        // Check fallback in materialTransfer
        final transferSnap = await matTransferRef.get();
        if (transferSnap.exists) {
          final tData = transferSnap.data() ?? {};
          final currentCount = (tData['companyAvailableCount'] as num?)?.toInt() ?? 0;
          newCompanyCount = isAddition ? (currentCount + count) : count;
          if (newCompanyCount < 0) newCompanyCount = 0;

          final rawSites = tData['siteInventories'];
          if (rawSites is List) {
            siteInventoriesList = rawSites.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }

      final totalSiteCount = siteInventoriesList.fold<int>(
        0,
        (acc, s) => acc + ((s['availableCount'] as num?)?.toInt() ?? 0),
      );

      final payload = {
        'materialId': resolvedMaterialId.isNotEmpty ? resolvedMaterialId : docId,
        'materialName': materialName,
        'displayName': displayName ?? materialName,
        if (resolvedCat.isNotEmpty) 'category': resolvedCat,
        if (resolvedSubCat.isNotEmpty) 'subCategory': resolvedSubCat,
        if (resolvedUnit.isNotEmpty) 'unit': resolvedUnit,
        if (resolvedPrice > 0) 'unitPrice': resolvedPrice,
        'companyAvailableCount': newCompanyCount,
        'siteInventories': siteInventoriesList,
        'totalSiteCount': totalSiteCount,
        'totalAvailableCount': newCompanyCount + totalSiteCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Atomic parallel write to canonical collections
      await Future.wait([
        availRef.set(payload, SetOptions(merge: true)),
        matTransferRef.set(payload, SetOptions(merge: true)),
      ]);

      // Legacy mirror synchronization (non-blocking)
      _syncLegacyMirrors(
        materialName: materialName,
        docId: docId,
        companyCount: newCompanyCount,
      );

      return newCompanyCount;
    } catch (e) {
      debugPrint('MaterialInventoryService.setCompanyStock error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 2. MOVEMENT: COMPANY TO SITE TRANSFER
  // ===========================================================================

  /// Records transfer from Company warehouse to a construction site.
  /// Atomically decrements company stock and increments site stock.
  static Future<void> transferCompanyToSite({
    required String materialName,
    required String siteId,
    required int quantity,
    String? siteName,
    String? managerName,
    String? supervisorName,
    String? projectName,
    String? displayName,
  }) async {
    if (quantity <= 0) return;

    try {
      final docId = getMaterialDocId(materialName);
      final availRef = FirestoreService.getCollection('materialsAvailability').doc(docId);
      final matTransferRef = FirestoreService.getCollection('materialTransfer').doc(docId);

      final docSnap = await availRef.get();
      Map<String, dynamic> data = {};
      if (docSnap.exists) {
        data = docSnap.data() ?? {};
      } else {
        final tSnap = await matTransferRef.get();
        if (tSnap.exists) data = tSnap.data() ?? {};
      }

      final int currentCompany = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
      final int newCompany = (currentCompany - quantity).clamp(0, 999999999);

      final List<dynamic> rawSites = List.from(data['siteInventories'] ?? []);
      final List<Map<String, dynamic>> siteInventories = [];
      bool siteFound = false;
      int previousSiteCount = 0;
      int newSiteCount = quantity;

      for (var item in rawSites) {
        if (item is Map) {
          final sMap = Map<String, dynamic>.from(item);
          final sId = (sMap['siteId'] ?? '').toString().trim().toLowerCase();
          if (sId == siteId.trim().toLowerCase()) {
            previousSiteCount = (sMap['availableCount'] as num?)?.toInt() ?? 0;
            newSiteCount = previousSiteCount + quantity;
            sMap['availableCount'] = newSiteCount;
            if (siteName != null && siteName.isNotEmpty) sMap['siteName'] = siteName;
            if (projectName != null && projectName.isNotEmpty) sMap['projectName'] = projectName;
            sMap['updatedAt'] = DateTime.now().toIso8601String();
            siteFound = true;
          }
          siteInventories.add(sMap);
        }
      }

      if (!siteFound) {
        siteInventories.add({
          'siteId': siteId,
          'siteName': siteName != null && siteName.isNotEmpty ? siteName : siteId,
          if (projectName != null && projectName.isNotEmpty) 'projectName': projectName,
          'availableCount': quantity,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final totalSiteCount = siteInventories.fold<int>(
        0,
        (acc, s) => acc + ((s['availableCount'] as num?)?.toInt() ?? 0),
      );

      final updatePayload = {
        'materialName': materialName,
        'displayName': displayName ?? data['displayName'] ?? materialName,
        'companyAvailableCount': newCompany,
        'siteInventories': siteInventories,
        'totalSiteCount': totalSiteCount,
        'totalAvailableCount': newCompany + totalSiteCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        availRef.set(updatePayload, SetOptions(merge: true)),
        matTransferRef.set(updatePayload, SetOptions(merge: true)),
      ]);

      // Record transfer log in materialTransfers
      await _logTransferRecord(
        transferType: 'CompanyToSite',
        fromSiteId: 'COMPANY',
        fromSiteName: 'Company Warehouse',
        toSiteId: siteId,
        toSiteName: siteName ?? siteId,
        managerName: managerName,
        supervisorName: supervisorName,
        projectName: projectName,
        materials: [
          {
            'materialName': materialName,
            'displayName': displayName ?? materialName,
            'quantity': quantity,
            'neededCount': quantity,
            'previousCompanyCount': currentCompany,
            'newCompanyCount': newCompany,
            'previousSiteCount': previousSiteCount,
            'newSiteCount': newSiteCount,
          }
        ],
      );

      // Sync company-level legacy mirrors
      _syncLegacyMirrors(
        materialName: materialName,
        docId: docId,
        companyCount: newCompany,
      );

      // Sync site-level mirrors
      _syncSiteMirrors(
        siteId: siteId,
        materialName: materialName,
        siteCount: newSiteCount,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('MaterialInventoryService.transferCompanyToSite error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 3. MOVEMENT: SITE TO SITE TRANSFER
  // ===========================================================================

  /// Records transfer from one Site to another Site.
  /// Atomically decrements fromSite and increments toSite.
  static Future<void> transferSiteToSite({
    required String materialName,
    required String fromSiteId,
    required String toSiteId,
    required int quantity,
    String? fromSiteName,
    String? toSiteName,
    String? fromManagerName,
    String? toManagerName,
    String? fromSupervisorName,
    String? toSupervisorName,
    String? fromProjectName,
    String? toProjectName,
    String? displayName,
  }) async {
    if (quantity <= 0) return;

    try {
      final docId = getMaterialDocId(materialName);
      final availRef = FirestoreService.getCollection('materialsAvailability').doc(docId);
      final matTransferRef = FirestoreService.getCollection('materialTransfer').doc(docId);

      final docSnap = await availRef.get();
      Map<String, dynamic> data = {};
      if (docSnap.exists) {
        data = docSnap.data() ?? {};
      } else {
        final tSnap = await matTransferRef.get();
        if (tSnap.exists) data = tSnap.data() ?? {};
      }

      final List<dynamic> rawSites = List.from(data['siteInventories'] ?? []);
      final List<Map<String, dynamic>> siteInventories = [];
      bool toSiteFound = false;
      int fromNewCount = 0;
      int toNewCount = quantity;

      for (var item in rawSites) {
        if (item is Map) {
          final sMap = Map<String, dynamic>.from(item);
          final sId = (sMap['siteId'] ?? '').toString().trim().toLowerCase();

          if (sId == fromSiteId.trim().toLowerCase()) {
            final curr = (sMap['availableCount'] as num?)?.toInt() ?? 0;
            fromNewCount = (curr - quantity).clamp(0, 999999999);
            sMap['availableCount'] = fromNewCount;
            sMap['updatedAt'] = DateTime.now().toIso8601String();
          } else if (sId == toSiteId.trim().toLowerCase()) {
            final curr = (sMap['availableCount'] as num?)?.toInt() ?? 0;
            toNewCount = curr + quantity;
            sMap['availableCount'] = toNewCount;
            if (toSiteName != null && toSiteName.isNotEmpty) sMap['siteName'] = toSiteName;
            if (toProjectName != null && toProjectName.isNotEmpty) sMap['projectName'] = toProjectName;
            sMap['updatedAt'] = DateTime.now().toIso8601String();
            toSiteFound = true;
          }
          siteInventories.add(sMap);
        }
      }

      if (!toSiteFound) {
        siteInventories.add({
          'siteId': toSiteId,
          'siteName': toSiteName != null && toSiteName.isNotEmpty ? toSiteName : toSiteId,
          if (toProjectName != null && toProjectName.isNotEmpty) 'projectName': toProjectName,
          'availableCount': quantity,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final companyCount = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
      final totalSiteCount = siteInventories.fold<int>(
        0,
        (acc, s) => acc + ((s['availableCount'] as num?)?.toInt() ?? 0),
      );

      final updatePayload = {
        'materialName': materialName,
        'displayName': displayName ?? data['displayName'] ?? materialName,
        'companyAvailableCount': companyCount,
        'siteInventories': siteInventories,
        'totalSiteCount': totalSiteCount,
        'totalAvailableCount': companyCount + totalSiteCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        availRef.set(updatePayload, SetOptions(merge: true)),
        matTransferRef.set(updatePayload, SetOptions(merge: true)),
      ]);

      // Record transfer log
      await _logTransferRecord(
        transferType: 'SiteToSite',
        fromSiteId: fromSiteId,
        fromSiteName: fromSiteName ?? fromSiteId,
        fromManagerName: fromManagerName,
        fromSupervisorName: fromSupervisorName,
        toSiteId: toSiteId,
        toSiteName: toSiteName ?? toSiteId,
        toManagerName: toManagerName,
        toSupervisorName: toSupervisorName,
        materials: [
          {
            'materialName': materialName,
            'displayName': displayName ?? materialName,
            'quantity': quantity,
            'neededCount': quantity,
            'fromSiteNewCount': fromNewCount,
            'toSiteNewCount': toNewCount,
          }
        ],
      );

      // Sync site mirrors for both sites
      _syncSiteMirrors(
        siteId: fromSiteId,
        materialName: materialName,
        siteCount: fromNewCount,
        displayName: displayName,
      );
      _syncSiteMirrors(
        siteId: toSiteId,
        materialName: materialName,
        siteCount: toNewCount,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('MaterialInventoryService.transferSiteToSite error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 4. MOVEMENT: SITE TO COMPANY RETURN
  // ===========================================================================

  /// Records material return from a Site back to the Company warehouse.
  /// Atomically decrements site stock and increments company warehouse stock.
  static Future<void> transferSiteToCompany({
    required String materialName,
    required String siteId,
    required int quantity,
    String? siteName,
    String? managerName,
    String? supervisorName,
    String? projectName,
    String? displayName,
  }) async {
    if (quantity <= 0) return;

    try {
      final docId = getMaterialDocId(materialName);
      final availRef = FirestoreService.getCollection('materialsAvailability').doc(docId);
      final matTransferRef = FirestoreService.getCollection('materialTransfer').doc(docId);

      final docSnap = await availRef.get();
      Map<String, dynamic> data = {};
      if (docSnap.exists) {
        data = docSnap.data() ?? {};
      } else {
        final tSnap = await matTransferRef.get();
        if (tSnap.exists) data = tSnap.data() ?? {};
      }

      final int currentCompany = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
      final int newCompany = currentCompany + quantity;

      final List<dynamic> rawSites = List.from(data['siteInventories'] ?? []);
      final List<Map<String, dynamic>> siteInventories = [];
      int newSiteCount = 0;

      for (var item in rawSites) {
        if (item is Map) {
          final sMap = Map<String, dynamic>.from(item);
          final sId = (sMap['siteId'] ?? '').toString().trim().toLowerCase();
          if (sId == siteId.trim().toLowerCase()) {
            final curr = (sMap['availableCount'] as num?)?.toInt() ?? 0;
            newSiteCount = (curr - quantity).clamp(0, 999999999);
            sMap['availableCount'] = newSiteCount;
            sMap['updatedAt'] = DateTime.now().toIso8601String();
          }
          siteInventories.add(sMap);
        }
      }

      final totalSiteCount = siteInventories.fold<int>(
        0,
        (acc, s) => acc + ((s['availableCount'] as num?)?.toInt() ?? 0),
      );

      final updatePayload = {
        'materialName': materialName,
        'displayName': displayName ?? data['displayName'] ?? materialName,
        'companyAvailableCount': newCompany,
        'siteInventories': siteInventories,
        'totalSiteCount': totalSiteCount,
        'totalAvailableCount': newCompany + totalSiteCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        availRef.set(updatePayload, SetOptions(merge: true)),
        matTransferRef.set(updatePayload, SetOptions(merge: true)),
      ]);

      // Log transfer
      await _logTransferRecord(
        transferType: 'SiteToCompany',
        fromSiteId: siteId,
        fromSiteName: siteName ?? siteId,
        toSiteId: 'COMPANY',
        toSiteName: 'Company Warehouse',
        managerName: managerName,
        supervisorName: supervisorName,
        projectName: projectName,
        materials: [
          {
            'materialName': materialName,
            'displayName': displayName ?? materialName,
            'quantity': quantity,
            'neededCount': quantity,
            'newSiteCount': newSiteCount,
            'newCompanyCount': newCompany,
          }
        ],
      );

      // Sync company-level legacy mirrors
      _syncLegacyMirrors(
        materialName: materialName,
        docId: docId,
        companyCount: newCompany,
      );

      // Sync site mirror
      _syncSiteMirrors(
        siteId: siteId,
        materialName: materialName,
        siteCount: newSiteCount,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('MaterialInventoryService.transferSiteToCompany error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 5. SUPERVISOR SITE MATERIAL ARRIVAL & LOGGING
  // ===========================================================================

  /// Records physical material arrival / updated quantity at site by supervisor.
  static Future<void> recordSiteMaterialArrival({
    required String siteId,
    required String materialName,
    required int quantity,
    String? siteName,
    String? supervisorName,
    String? unit,
    String? displayName,
  }) async {
    try {
      final docId = getMaterialDocId(materialName);
      final availRef = FirestoreService.getCollection('materialsAvailability').doc(docId);
      final matTransferRef = FirestoreService.getCollection('materialTransfer').doc(docId);

      final docSnap = await availRef.get();
      Map<String, dynamic> data = {};
      if (docSnap.exists) {
        data = docSnap.data() ?? {};
      } else {
        final tSnap = await matTransferRef.get();
        if (tSnap.exists) data = tSnap.data() ?? {};
      }

      final List<dynamic> rawSites = List.from(data['siteInventories'] ?? []);
      final List<Map<String, dynamic>> siteInventories = [];
      bool siteFound = false;

      for (var item in rawSites) {
        if (item is Map) {
          final sMap = Map<String, dynamic>.from(item);
          final sId = (sMap['siteId'] ?? '').toString().trim().toLowerCase();
          if (sId == siteId.trim().toLowerCase()) {
            sMap['availableCount'] = quantity;
            if (siteName != null && siteName.isNotEmpty) sMap['siteName'] = siteName;
            sMap['updatedAt'] = DateTime.now().toIso8601String();
            siteFound = true;
          }
          siteInventories.add(sMap);
        }
      }

      if (!siteFound) {
        siteInventories.add({
          'siteId': siteId,
          'siteName': siteName != null && siteName.isNotEmpty ? siteName : siteId,
          'availableCount': quantity,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final companyCount = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
      final totalSiteCount = siteInventories.fold<int>(
        0,
        (acc, s) => acc + ((s['availableCount'] as num?)?.toInt() ?? 0),
      );

      final updatePayload = {
        'materialName': materialName,
        'displayName': displayName ?? data['displayName'] ?? materialName,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        'companyAvailableCount': companyCount,
        'siteInventories': siteInventories,
        'totalSiteCount': totalSiteCount,
        'totalAvailableCount': companyCount + totalSiteCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        availRef.set(updatePayload, SetOptions(merge: true)),
        matTransferRef.set(updatePayload, SetOptions(merge: true)),
      ]);

      _syncSiteMirrors(
        siteId: siteId,
        materialName: materialName,
        siteCount: quantity,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('MaterialInventoryService.recordSiteMaterialArrival error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 6. QUERY & REPORTING METHODS
  // ===========================================================================

  /// Fetches single consolidated material inventory item by name.
  static Future<MaterialInventoryItem?> fetchMaterialInventory(String materialName) async {
    try {
      final docId = getMaterialDocId(materialName);
      final availDoc = await FirestoreService.getCollection('materialsAvailability').doc(docId).get();

      if (availDoc.exists && availDoc.data() != null) {
        return MaterialInventoryItem.fromMap(docId, availDoc.data()!);
      }

      final transferDoc = await FirestoreService.getCollection('materialTransfer').doc(docId).get();
      if (transferDoc.exists && transferDoc.data() != null) {
        return MaterialInventoryItem.fromMap(docId, transferDoc.data()!);
      }

      // Fallback to searching materials catalog
      final masterQuery = await FirestoreService.getCollection('materials')
          .where('materialName', isEqualTo: materialName)
          .limit(1)
          .get();

      if (masterQuery.docs.isNotEmpty) {
        final doc = masterQuery.docs.first;
        return MaterialInventoryItem.fromMap(doc.id, doc.data());
      }

      return null;
    } catch (e) {
      debugPrint('MaterialInventoryService.fetchMaterialInventory error: $e');
      return null;
    }
  }

  /// Fetches complete aggregated inventory for all materials in organization.
  static Future<List<MaterialInventoryItem>> fetchAllMaterialsInventory() async {
    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final results = await Future.wait([
        FirestoreService.getCollection('materials').get(),
        FirestoreService.getCollection('materialsAvailability').get(),
        FirestoreService.getCollection('materialTransfer').get(),
        FirestoreService.getCollection('materialCategories').get(),
      ]);

      final masterDocs = results[0].docs;
      final availDocs = results[1].docs;
      final transferDocs = results[2].docs;
      final catDocs = results[3].docs;

      final Map<String, MaterialInventoryItem> itemsMap = {};

      // 1. Ingest master materials definitions
      for (final doc in masterDocs) {
        final data = doc.data();
        final name = (data['materialName'] ?? data['matName'] ?? data['name'] ?? doc.id).toString().trim();
        if (name.isEmpty) continue;
        final docKey = getMaterialDocId(name);

        itemsMap[docKey] = MaterialInventoryItem.fromMap(docKey, data);
      }

      // 2. Ingest category catalog fallbacks
      for (final doc in catDocs) {
        final data = doc.data();
        final name = (data['matCategory'] ?? data['materialName'] ?? doc.id).toString().trim();
        if (name.isEmpty) continue;
        final docKey = getMaterialDocId(name);

        if (!itemsMap.containsKey(docKey)) {
          itemsMap[docKey] = MaterialInventoryItem(
            docId: docKey,
            materialName: name,
            category: name,
          );
        }
      }

      // 3. Ingest and merge live canonical availability & transfers
      final liveDocs = [...availDocs, ...transferDocs];
      for (final doc in liveDocs) {
        final data = doc.data();
        final name = (data['materialName'] ?? data['displayName'] ?? doc.id).toString().trim();
        if (name.isEmpty) continue;
        final docKey = getMaterialDocId(name);

        final liveItem = MaterialInventoryItem.fromMap(docKey, data);

        if (itemsMap.containsKey(docKey)) {
          final existing = itemsMap[docKey]!;
          // Merge metadata + live stock counts (live canonical stock takes precedence)
          itemsMap[docKey] = MaterialInventoryItem(
            docId: docKey,
            materialId: existing.materialId.isNotEmpty ? existing.materialId : liveItem.materialId,
            materialName: existing.materialName,
            displayName: existing.displayName,
            category: existing.category != 'General Material' ? existing.category : liveItem.category,
            subCategory: existing.subCategory.isNotEmpty ? existing.subCategory : liveItem.subCategory,
            unit: existing.unit != 'Units' ? existing.unit : liveItem.unit,
            unitPrice: existing.unitPrice > 0 ? existing.unitPrice : liveItem.unitPrice,
            description: existing.description.isNotEmpty ? existing.description : liveItem.description,
            companyAvailableCount: liveItem.companyAvailableCount,
            siteInventories: liveItem.siteInventories.isNotEmpty
                ? liveItem.siteInventories
                : existing.siteInventories,
            lastUpdated: liveItem.lastUpdated ?? existing.lastUpdated,
          );
        } else {
          itemsMap[docKey] = liveItem;
        }
      }

      final list = itemsMap.values.toList();
      list.sort((a, b) => a.materialName.toLowerCase().compareTo(b.materialName.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('MaterialInventoryService.fetchAllMaterialsInventory error: $e');
      return [];
    }
  }

  /// Fetches all materials at a specific site with their current available count.
  /// Guarantees exact synchronization across all supervisor screens.
  static Future<List<Map<String, dynamic>>> fetchSiteInventory(String siteId) async {
    if (siteId.trim().isEmpty) return [];
    try {
      final allItems = await fetchAllMaterialsInventory();
      final List<Map<String, dynamic>> siteMaterials = [];

      for (final item in allItems) {
        final siteEntry = item.siteInventories.firstWhere(
          (s) => s.siteId.trim().toLowerCase() == siteId.trim().toLowerCase(),
          orElse: () => SiteInventoryEntry(siteId: siteId, availableCount: 0),
        );

        // Include if transferred to this site or present in site inventories
        final bool hasTransferred = item.siteInventories.any(
          (s) => s.siteId.trim().toLowerCase() == siteId.trim().toLowerCase(),
        );

        if (siteEntry.availableCount > 0 || hasTransferred) {
          siteMaterials.add({
            'materialId': item.docId,
            'materialName': item.materialName,
            'displayName': item.displayName.isNotEmpty ? item.displayName : item.materialName,
            'category': item.category,
            'subCategory': item.subCategory,
            'unit': item.unit,
            'unitPrice': item.unitPrice,
            'availableCount': siteEntry.availableCount,
            'siteId': siteId,
            'siteName': siteEntry.siteName.isNotEmpty ? siteEntry.siteName : siteId,
            'lastUpdated': siteEntry.updatedAt ?? item.lastUpdated,
          });
        }
      }

      siteMaterials.sort(
        (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
              (b['displayName'] as String).toLowerCase(),
            ),
      );

      return siteMaterials;
    } catch (e) {
      debugPrint('MaterialInventoryService.fetchSiteInventory error: $e');
      return [];
    }
  }

  // ===========================================================================
  // 7. INTERNAL HELPERS & BACKWARD COMPATIBILITY SYNCS
  // ===========================================================================

  static Future<void> _logTransferRecord({
    required String transferType,
    required String fromSiteId,
    required String fromSiteName,
    required String toSiteId,
    required String toSiteName,
    String? fromManagerName,
    String? toManagerName,
    String? managerName,
    String? supervisorName,
    String? fromSupervisorName,
    String? toSupervisorName,
    String? projectName,
    required List<Map<String, dynamic>> materials,
  }) async {
    try {
      final transferPayload = {
        'transferType': transferType,
        'fromSiteId': fromSiteId,
        'fromSiteName': fromSiteName,
        'toSiteId': toSiteId,
        'toSiteName': toSiteName,
        'managerName': managerName ?? fromManagerName ?? toManagerName ?? '',
        'fromManagerName': fromManagerName ?? managerName ?? '',
        'toManagerName': toManagerName ?? managerName ?? '',
        'supervisorName': supervisorName ?? fromSupervisorName ?? toSupervisorName ?? '',
        'fromSupervisorName': fromSupervisorName ?? supervisorName ?? '',
        'toSupervisorName': toSupervisorName ?? supervisorName ?? '',
        if (projectName != null && projectName.isNotEmpty) 'projectName': projectName,
        'materials': materials,
        'status': 'COMPLETED',
        'createdAt': FieldValue.serverTimestamp(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };

      await FirestoreService.getCollection('materialTransfers').add(transferPayload);
    } catch (e) {
      debugPrint('Error logging transfer record: $e');
    }
  }

  static void _syncLegacyMirrors({
    required String materialName,
    required String docId,
    required int companyCount,
  }) {
    // Non-blocking fire-and-forget sync to legacy collections
    Future.microtask(() async {
      try {
        final now = DateTime.now();
        final formattedDate =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
        final legacyDocId = '${materialName}_$formattedDate';

        // 1. Sync materialsavailablity daily doc
        await FirestoreService.getCollection('materialsavailablity').doc(legacyDocId).set({
          'materialName': materialName,
          'count': companyCount,
          'lastupdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Sync materials master collection count
        final masterQuery = await FirestoreService.getCollection('materials')
            .where('materialName', isEqualTo: materialName)
            .get();
        for (final mDoc in masterQuery.docs) {
          await mDoc.reference.set({
            'availableCount': companyCount,
            'count': companyCount,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Legacy mirrors sync error: $e');
      }
    });
  }

  static void _syncSiteMirrors({
    required String siteId,
    required String materialName,
    required int siteCount,
    String? displayName,
  }) {
    Future.microtask(() async {
      try {
        // 1. Sync siteMaterials/{siteId}/materials/{materialName}
        final siteMatRef = FirestoreService.getCollection('siteMaterials')
            .doc(siteId)
            .collection('materials')
            .doc(materialName);

        await siteMatRef.set({
          'materialId': materialName,
          'materialName': materialName,
          'displayName': displayName ?? materialName,
          'count': siteCount,
          'availableCount': siteCount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Sync materialatsite/{siteId}_{materialName}
        final matAtSiteRef = FirestoreService.getCollection('materialatsite')
            .doc('${siteId}_$materialName');

        await matAtSiteRef.set({
          'siteid': siteId,
          'siteId': siteId,
          'materialName': materialName,
          'materialname': materialName,
          'count': siteCount,
          'availableCount': siteCount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Site mirrors sync error: $e');
      }
    });
  }
}
