import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/auth_service.dart';

/// Result object returned after a successful storage upload
class StorageUploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final int fileSizeBytes;
  final String contentType;

  StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.contentType,
  });

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'contentType': contentType,
    };
  }
}

/// Centralized service for all Firebase Storage uploads across the app.
/// Enforces strict multi-tenant organization isolation so that all user images,
/// receipts, supervisor photos, drawings, and documents are strictly compartmentalized
/// under `organisation/{orgId}/...` and can never bleed into or overwrite other tenants.
class AppStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Retrieves the active Organization / Tenant ID robustly.
  static String get currentOrgId {
    String orgId = FirestoreService.currentOrgId;
    if (orgId.isEmpty || orgId == 'uninitialized') {
      try {
        final auth = AuthService();
        final resolved = (auth.userData['dynamicPath'] ?? auth.userData['orgId'] ?? '').toString();
        if (resolved.isNotEmpty) {
          if (resolved.contains('/')) {
            final parts = resolved.split('/');
            orgId = (parts.length > 1 && parts[0] == 'organisation') ? parts[1] : parts[0];
          } else {
            orgId = resolved;
          }
        }
      } catch (_) {}
    }
    if (orgId.isEmpty || orgId == 'uninitialized') {
      debugPrint('WARNING: Storage accessed without active organization ID.');
      return 'default_org';
    }
    return orgId;
  }

  /// Root storage reference scoped strictly to the current organization:
  /// `organisation/{orgId}`
  static Reference get orgRootRef => _storage.ref().child('organisation').child(currentOrgId);

  /// Scoped child reference under the current organization root
  static Reference getOrgSubRef(String subPath) {
    // Strip leading slashes
    final cleanSubPath = subPath.startsWith('/') ? subPath.substring(1) : subPath;
    return orgRootRef.child(cleanSubPath);
  }

  /// Sanitizes a file name to remove special/problematic characters
  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Detects appropriate MIME Content-Type based on extension
  static SettableMetadata detectMetadata(String fileName, [String? explicitContentType]) {
    if (explicitContentType != null && explicitContentType.isNotEmpty) {
      return SettableMetadata(contentType: explicitContentType);
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return SettableMetadata(contentType: 'image/jpeg');
      case 'png':
        return SettableMetadata(contentType: 'image/png');
      case 'webp':
        return SettableMetadata(contentType: 'image/webp');
      case 'gif':
        return SettableMetadata(contentType: 'image/gif');
      case 'bmp':
        return SettableMetadata(contentType: 'image/bmp');
      case 'pdf':
        return SettableMetadata(contentType: 'application/pdf');
      case 'doc':
      case 'docx':
        return SettableMetadata(contentType: 'application/msword');
      case 'xls':
      case 'xlsx':
        return SettableMetadata(contentType: 'application/vnd.ms-excel');
      case 'dwg':
      case 'dxf':
        return SettableMetadata(contentType: 'application/acad');
      case 'txt':
        return SettableMetadata(contentType: 'text/plain');
      case 'zip':
        return SettableMetadata(contentType: 'application/zip');
      default:
        return SettableMetadata(contentType: 'application/octet-stream');
    }
  }

  /// Core universal upload method with strict tenant isolation
  static Future<StorageUploadResult?> uploadFile({
    required String category,
    required String fileName,
    File? file,
    Uint8List? bytes,
    String? customSubPath,
    SettableMetadata? metadata,
    String? explicitOrgId,
  }) async {
    try {
      final org = (explicitOrgId != null && explicitOrgId.isNotEmpty) ? explicitOrgId : currentOrgId;
      final cleanName = sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${timestamp}_$cleanName';

      // Build strictly scoped path: organisation/{orgId}/{category}/{uniqueFileName}
      final relativePath = customSubPath != null && customSubPath.isNotEmpty
          ? '$customSubPath/$uniqueName'
          : '$category/$uniqueName';

      final fullStoragePath = 'organisation/$org/$relativePath';
      final storageRef = _storage.ref().child(fullStoragePath);

      final fileMetadata = metadata ?? detectMetadata(fileName);

      UploadTask uploadTask;
      int sizeBytes = 0;

      if (bytes != null && bytes.isNotEmpty) {
        sizeBytes = bytes.length;
        uploadTask = storageRef.putData(bytes, fileMetadata);
      } else if (file != null) {
        if (!kIsWeb) {
          if (!await file.exists()) {
            debugPrint('AppStorageService: File does not exist on disk at ${file.path}');
            return null;
          }
          sizeBytes = await file.length();
          uploadTask = storageRef.putFile(file, fileMetadata);
        } else {
          final fileBytes = await file.readAsBytes();
          sizeBytes = fileBytes.length;
          uploadTask = storageRef.putData(fileBytes, fileMetadata);
        }
      } else {
        debugPrint('AppStorageService: Neither file nor bytes provided for upload');
        return null;
      }

      final TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('AppStorageService: Upload successful -> $fullStoragePath');

      return StorageUploadResult(
        downloadUrl: downloadUrl,
        storagePath: fullStoragePath,
        fileName: cleanName,
        fileSizeBytes: sizeBytes,
        contentType: fileMetadata.contentType ?? 'application/octet-stream',
      );
    } catch (e) {
      debugPrint('AppStorageService: Upload failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // DOMAIN-SPECIFIC SCOPED UPLOAD METHODS
  // ---------------------------------------------------------------------------

  /// Uploads user profile image / avatar scoped to:
  /// `organisation/{orgId}/users/{userId}/avatar_{timestamp}_{fileName}`
  static Future<String?> uploadUserImage({
    required String userId,
    required String fileName,
    File? file,
    Uint8List? bytes,
  }) async {
    final result = await uploadFile(
      category: 'users/$userId/images',
      fileName: fileName,
      file: file,
      bytes: bytes,
    );
    return result?.downloadUrl;
  }

  /// Uploads supervisor site verification photo scoped to:
  /// `organisation/{orgId}/supervisor_photos/{supervisorId}/{timestamp}_verification.jpg`
  static Future<String?> uploadSupervisorVerificationPhoto({
    required String supervisorId,
    required File imageFile,
    String? siteId,
  }) async {
    final subFolder = siteId != null && siteId.isNotEmpty
        ? 'supervisor_photos/$supervisorId/$siteId'
        : 'supervisor_photos/$supervisorId';

    final result = await uploadFile(
      category: subFolder,
      fileName: 'verification.jpg',
      file: imageFile,
    );
    return result?.downloadUrl;
  }

  /// Uploads a Manager Expense bill image/document to:
  /// `manager expenses/organisation/{tenantId}/manager expenses/{siteId_siteName}/{image}`
  static Future<String?> uploadManagerExpenseBill({
    required String siteId,
    required String siteName,
    required String billNo,
    File? file,
    Uint8List? bytes,
    String? explicitTenantId,
  }) async {
    return _uploadExpenseBillToScopedPath(
      expenseType: 'manager expenses',
      siteId: siteId,
      siteName: siteName,
      billNo: billNo,
      file: file,
      bytes: bytes,
      explicitTenantId: explicitTenantId,
    );
  }

  /// Uploads an Organization Expense bill image/document to:
  /// `manager expenses/organisation/{tenantId}/organization expenses/{siteId_siteName}/{image}`
  static Future<String?> uploadOrganizationExpenseBill({
    required String siteId,
    required String siteName,
    required String billNo,
    File? file,
    Uint8List? bytes,
    String? explicitTenantId,
  }) async {
    return _uploadExpenseBillToScopedPath(
      expenseType: 'organization expenses',
      siteId: siteId,
      siteName: siteName,
      billNo: billNo,
      file: file,
      bytes: bytes,
      explicitTenantId: explicitTenantId,
    );
  }

  /// Internal scoped upload engine implementing exact required directory hierarchy:
  /// manager expenses/organisation/{tenantId}/{expenseType}/{siteId_siteName}/{image}
  static Future<String?> _uploadExpenseBillToScopedPath({
    required String expenseType,
    required String siteId,
    required String siteName,
    required String billNo,
    File? file,
    Uint8List? bytes,
    String? explicitTenantId,
  }) async {
    try {
      // 1. Resolve Tenant ID
      String tenantId = (explicitTenantId != null && explicitTenantId.trim().isNotEmpty)
          ? explicitTenantId.trim()
          : currentOrgId;

      if (tenantId.isEmpty || tenantId == 'uninitialized' || tenantId == 'default_org') {
        try {
          final auth = AuthService();
          final resolved = (auth.userData['dynamicPath'] ?? auth.userData['orgId'] ?? '').toString();
          if (resolved.isNotEmpty) {
            if (resolved.contains('/')) {
              final parts = resolved.split('/');
              tenantId = (parts.length > 1 && parts[0] == 'organisation') ? parts[1] : parts[0];
            } else {
              tenantId = resolved;
            }
          }
        } catch (_) {}
      }

      if (tenantId.isEmpty || tenantId == 'uninitialized') {
        tenantId = 'default_org';
      }

      // 2. Resolve Site Folder: {siteId_siteName}
      final cleanSiteId = sanitizeFileName(siteId.trim());
      String cleanSiteName = sanitizeFileName(siteName.trim());
      if (cleanSiteName.isEmpty || cleanSiteName.toLowerCase() == cleanSiteId.toLowerCase()) {
        cleanSiteName = 'site';
      }
      final siteFolder = '${cleanSiteId}_$cleanSiteName';

      // 3. Resolve Image / Document File Name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanBillNo = sanitizeFileName(billNo.trim());
      String ext = 'jpg';
      if (file != null && file.path.contains('.')) {
        ext = file.path.split('.').last.toLowerCase();
      }
      final billTag = cleanBillNo.isNotEmpty ? cleanBillNo : 'doc';
      final fileName = 'bill_${billTag}_$timestamp.$ext';

      // 4. Exact path required:
      // manager expenses/organisation/{tenantId}/{expenseType}/{siteId_siteName}/{image}
      final fullStoragePath =
          'manager expenses/organisation/$tenantId/$expenseType/$siteFolder/$fileName';
      final storageRef = _storage.ref().child(fullStoragePath);

      final metadata = SettableMetadata(
        contentType: detectMetadata(fileName).contentType ?? 'image/jpeg',
        cacheControl: 'public, max-age=2592000', // 30 days cache for fast loading
      );

      UploadTask uploadTask;
      if (bytes != null && bytes.isNotEmpty) {
        uploadTask = storageRef.putData(bytes, metadata);
      } else if (file != null) {
        if (!kIsWeb) {
          if (!await file.exists()) {
            debugPrint('AppStorageService: File does not exist at ${file.path}');
            return null;
          }
          uploadTask = storageRef.putFile(file, metadata);
        } else {
          final fileBytes = await file.readAsBytes();
          uploadTask = storageRef.putData(fileBytes, metadata);
        }
      } else {
        debugPrint('AppStorageService: No file or bytes provided');
        return null;
      }

      final TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('AppStorageService: Bill uploaded successfully -> $fullStoragePath');
      return downloadUrl;
    } catch (e) {
      debugPrint('AppStorageService: Error uploading expense bill: $e');
      return null;
    }
  }

  /// Backward compatible uploadExpenseBill redirecting to manager expenses path
  static Future<String?> uploadExpenseBill({
    required String siteId,
    required String billNo,
    required String dateFormatted,
    String? siteName,
    File? file,
    Uint8List? bytes,
    String extension = 'jpg',
    String? explicitTenantId,
  }) async {
    return uploadManagerExpenseBill(
      siteId: siteId,
      siteName: siteName ?? '',
      billNo: billNo,
      file: file,
      bytes: bytes,
      explicitTenantId: explicitTenantId,
    );
  }

  /// Uploads construction drawings and blueprint documents scoped to:
  /// `organisation/{orgId}/drawings/{siteId}/{timestamp}_{fileName}`
  static Future<StorageUploadResult?> uploadDrawingDoc({
    required String siteId,
    required String fileName,
    File? file,
    Uint8List? bytes,
  }) async {
    final cleanSite = sanitizeFileName(siteId);
    return await uploadFile(
      category: 'drawings/$cleanSite',
      fileName: fileName,
      file: file,
      bytes: bytes,
    );
  }

  /// Uploads organization branding logo / assets scoped to:
  /// `organisation/{orgId}/branding/logo_{timestamp}_{fileName}`
  static Future<String?> uploadBrandingAsset({
    required String assetType,
    required String fileName,
    File? file,
    Uint8List? bytes,
  }) async {
    final result = await uploadFile(
      category: 'branding/$assetType',
      fileName: fileName,
      file: file,
      bytes: bytes,
    );
    return result?.downloadUrl;
  }

  // ---------------------------------------------------------------------------
  // SECURITY & CLEANUP HELPERS
  // ---------------------------------------------------------------------------

  /// Deletes a file only if it strictly belongs to the current tenant organization
  static Future<bool> deleteFileByPath(String storagePath) async {
    try {
      final expectedPrefix1 = 'organisation/$currentOrgId/';
      final expectedPrefix2 = 'manager expenses/organisation/$currentOrgId/';
      if (!storagePath.startsWith(expectedPrefix1) && !storagePath.startsWith(expectedPrefix2)) {
        debugPrint('AppStorageService: Security check failed. Cannot delete cross-tenant file: $storagePath');
        return false;
      }

      await _storage.ref().child(storagePath).delete();
      debugPrint('AppStorageService: Successfully deleted $storagePath');
      return true;
    } catch (e) {
      debugPrint('AppStorageService: Error deleting file by path: $e');
      return false;
    }
  }

  /// Deletes a file by its download URL with tenant verification
  static Future<bool> deleteFileByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      final expectedPrefix1 = 'organisation/$currentOrgId/';
      final expectedPrefix2 = 'manager expenses/organisation/$currentOrgId/';
      if (!ref.fullPath.startsWith(expectedPrefix1) && !ref.fullPath.startsWith(expectedPrefix2)) {
        debugPrint('AppStorageService: Security check failed. Cannot delete cross-tenant file URL: ${ref.fullPath}');
        return false;
      }

      await ref.delete();
      debugPrint('AppStorageService: Successfully deleted URL ref: ${ref.fullPath}');
      return true;
    } catch (e) {
      debugPrint('AppStorageService: Error deleting file by URL: $e');
      return false;
    }
  }
}
