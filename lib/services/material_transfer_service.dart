import 'material_inventory_service.dart';

/// Legacy bridge for material transfers.
/// Delegates all operations to [MaterialInventoryService] to guarantee a single source of truth.
class MaterialTransferService {
  /// Converts a material name (e.g. "Cement OPC" or "Steel 12mm") into a standardized document ID (e.g. "cement_opc")
  static String getMaterialDocId(String materialName) {
    return MaterialInventoryService.getMaterialDocId(materialName);
  }

  /// Updates inventory when material is transferred from Company to a Site
  static Future<void> recordCompanyToSiteTransfer({
    required String materialName,
    required String siteId,
    required int transferQty,
    String? siteName,
    String? displayName,
    String? managerName,
    String? supervisorName,
    String? projectName,
    int? currentCompanyAvailable,
  }) async {
    await MaterialInventoryService.transferCompanyToSite(
      materialName: materialName,
      siteId: siteId,
      quantity: transferQty,
      siteName: siteName,
      managerName: managerName,
      supervisorName: supervisorName,
      projectName: projectName,
      displayName: displayName,
    );
  }

  /// Updates inventory when material is transferred from one Site to another Site
  static Future<void> recordSiteToSiteTransfer({
    required String materialName,
    required String fromSiteId,
    required String toSiteId,
    required int transferQty,
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
    await MaterialInventoryService.transferSiteToSite(
      materialName: materialName,
      fromSiteId: fromSiteId,
      toSiteId: toSiteId,
      quantity: transferQty,
      fromSiteName: fromSiteName,
      toSiteName: toSiteName,
      fromManagerName: fromManagerName,
      toManagerName: toManagerName,
      fromSupervisorName: fromSupervisorName,
      toSupervisorName: toSupervisorName,
      fromProjectName: fromProjectName,
      toProjectName: toProjectName,
      displayName: displayName,
    );
  }

  /// Updates inventory when material is transferred from Site back to Company
  static Future<void> recordSiteToCompanyTransfer({
    required String materialName,
    required String siteId,
    required int transferQty,
    String? siteName,
    String? displayName,
    String? managerName,
    String? supervisorName,
    String? projectName,
    int? currentCompanyAvailable,
  }) async {
    await MaterialInventoryService.transferSiteToCompany(
      materialName: materialName,
      siteId: siteId,
      quantity: transferQty,
      siteName: siteName,
      managerName: managerName,
      supervisorName: supervisorName,
      projectName: projectName,
      displayName: displayName,
    );
  }

  /// Updates companyAvailableCount directly when company stock changes
  static Future<void> setCompanyAvailableCount({
    required String materialName,
    required int count,
    String? displayName,
  }) async {
    await MaterialInventoryService.setCompanyStock(
      materialName: materialName,
      count: count,
      displayName: displayName,
    );
  }
}
