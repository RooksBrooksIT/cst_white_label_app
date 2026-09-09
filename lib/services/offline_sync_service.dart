import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebricks/services/firestore_service.dart';

/// Represents the sync status of an offline queue item
enum SyncStatus {
  pendingSync,
  syncing,
  synced,
  syncFailed,
}

extension SyncStatusExtension on SyncStatus {
  String toValue() {
    switch (this) {
      case SyncStatus.pendingSync:
        return 'Pending Sync';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.syncFailed:
        return 'Sync Failed';
    }
  }

  static SyncStatus fromValue(String? val) {
    switch (val) {
      case 'Syncing':
        return SyncStatus.syncing;
      case 'Synced':
        return SyncStatus.synced;
      case 'Sync Failed':
        return SyncStatus.syncFailed;
      case 'Pending Sync':
      default:
        return SyncStatus.pendingSync;
    }
  }
}

/// Queue item representing an offline transaction
class OfflineQueueItem {
  final String localTxId;
  final String orgId;
  final String userId;
  final String moduleName;
  final String collectionPath;
  final String? documentId;
  final Map<String, dynamic> payload;
  SyncStatus status;
  final String createdAt;
  String? syncedAt;
  int retryCount;
  String? lastError;

  OfflineQueueItem({
    required this.localTxId,
    required this.orgId,
    required this.userId,
    required this.moduleName,
    required this.collectionPath,
    this.documentId,
    required this.payload,
    this.status = SyncStatus.pendingSync,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'localTxId': localTxId,
      'orgId': orgId,
      'userId': userId,
      'moduleName': moduleName,
      'collectionPath': collectionPath,
      'documentId': documentId,
      'payload': payload,
      'status': status.toValue(),
      'createdAt': createdAt,
      'syncedAt': syncedAt,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory OfflineQueueItem.fromMap(Map<String, dynamic> map) {
    return OfflineQueueItem(
      localTxId: map['localTxId'] ?? '',
      orgId: map['orgId'] ?? '',
      userId: map['userId'] ?? '',
      moduleName: map['moduleName'] ?? 'General',
      collectionPath: map['collectionPath'] ?? '',
      documentId: map['documentId'],
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      status: SyncStatusExtension.fromValue(map['status']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      syncedAt: map['syncedAt'],
      retryCount: map['retryCount'] ?? 0,
      lastError: map['lastError'],
    );
  }
}

/// Centralized service managing connectivity, offline data entry,
/// local queue storage, master data caching, and automatic idempotency-protected sync.
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueStorageKey = 'ebricks_offline_sync_queue_v1';
  static const String _masterCacheKeyPrefix = 'ebricks_master_cache_';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  List<OfflineQueueItem> _queue = [];
  String? _syncMessage;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  List<OfflineQueueItem> get queue => List.unmodifiable(_queue);
  String? get syncMessage => _syncMessage;

  int get pendingCount => _queue
      .where((item) =>
          item.status == SyncStatus.pendingSync ||
          item.status == SyncStatus.syncFailed)
      .length;

  /// Initializes connectivity listener and loads pending local sync queue
  static Future<void> initialize() async {
    await _instance._initInternal();
  }

  Future<void> _initInternal() async {
    await _loadQueueFromStorage();
    await _checkConnectivity();

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // If online on startup and has pending items, trigger auto-sync
    if (_isOnline && pendingCount > 0) {
      unawaited(processSyncQueue());
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateOnlineState(!results.contains(ConnectivityResult.none));
    } catch (e) {
      _updateOnlineState(true);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = !results.contains(ConnectivityResult.none);
    final previousState = _isOnline;
    _updateOnlineState(hasConnection);

    if (hasConnection && !previousState) {
      _syncMessage = 'Network restored. Syncing pending entries...';
      notifyListeners();
      unawaited(processSyncQueue());
    }
  }

  void _updateOnlineState(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  /// Generates a unique UUID v4 idempotency key
  static String generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 10
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Convenience helper to enqueue an entry by feature type
  Future<OfflineQueueItem> enqueueEntry({
    required String type,
    required Map<String, dynamic> data,
    String? idempotencyKey,
  }) async {
    String collectionPath = 'organisation_expenses';
    String moduleName = 'Organization Expenses';
    if (type == 'supervisor_entry') {
      collectionPath = 'siteSupervisorEntries';
      moduleName = 'Supervisor Entry';
    } else if (type == 'manager_expense') {
      collectionPath = 'manager_expenses';
      moduleName = 'Manager Expense';
    } else if (type == 'petty_cash_request') {
      collectionPath = 'petty_cash_requests';
      moduleName = 'Petty Cash Request';
    }

    final docId = data['docId']?.toString() ?? data['requestId']?.toString();

    return enqueueOfflineEntry(
      moduleName: moduleName,
      collectionPath: collectionPath,
      documentId: docId,
      payload: data,
    );
  }

  /// Saves an entry locally into the offline sync queue
  Future<OfflineQueueItem> enqueueOfflineEntry({
    required String moduleName,
    required String collectionPath,
    String? documentId,
    required Map<String, dynamic> payload,
    String? orgId,
    String? userId,
  }) async {
    final activeOrgId = orgId ?? FirestoreService.currentOrgId;
    final prefs = await SharedPreferences.getInstance();
    final activeUserId = userId ?? prefs.getString('auth_user_id') ?? 'unknown_user';

    final txId = generateUuid();
    final nowIso = DateTime.now().toIso8601String();

    // Ensure payload preserves original creation timestamp and idempotency key
    final cleanPayload = Map<String, dynamic>.from(payload);
    cleanPayload['createdAt'] ??= nowIso;
    cleanPayload['originalCreatedAt'] ??= nowIso;
    cleanPayload['idempotencyKey'] = txId;
    cleanPayload['createdByUserId'] = activeUserId;
    cleanPayload['orgId'] = activeOrgId;

    final queueItem = OfflineQueueItem(
      localTxId: txId,
      orgId: activeOrgId,
      userId: activeUserId,
      moduleName: moduleName,
      collectionPath: collectionPath,
      documentId: documentId,
      payload: cleanPayload,
      status: SyncStatus.pendingSync,
      createdAt: nowIso,
    );

    _queue.add(queueItem);
    await _saveQueueToStorage();
    notifyListeners();

    debugPrint('OfflineSyncService: Enqueued record $txId for module $moduleName');

    // If online, attempt immediate sync
    if (_isOnline) {
      unawaited(processSyncQueue());
    }

    return queueItem;
  }

  /// Processes the local offline sync queue sequentially
  Future<void> processSyncQueue() async {
    if (_isSyncing || !_isOnline) return;
    final itemsToSync = _queue
        .where((item) =>
            item.status == SyncStatus.pendingSync ||
            item.status == SyncStatus.syncFailed)
        .toList();

    if (itemsToSync.isEmpty) return;

    _isSyncing = true;
    _syncMessage = 'Syncing ${itemsToSync.length} entry(s)...';
    notifyListeners();

    int successCount = 0;
    int failCount = 0;

    for (var item in itemsToSync) {
      // Re-verify network status before each upload
      if (!_isOnline) break;

      item.status = SyncStatus.syncing;
      notifyListeners();

      try {
        await _uploadRecordToServer(item);
        item.status = SyncStatus.synced;
        item.syncedAt = DateTime.now().toIso8601String();
        item.lastError = null;
        successCount++;
        debugPrint('OfflineSyncService: Successfully synced ${item.localTxId}');
      } catch (e) {
        item.retryCount += 1;
        item.status = SyncStatus.syncFailed;
        item.lastError = e.toString();
        failCount++;
        debugPrint('OfflineSyncService: Sync failed for ${item.localTxId}: $e');
      }

      await _saveQueueToStorage();
      notifyListeners();
    }

    // Clean up successfully synced records from active queue storage
    _queue.removeWhere((item) => item.status == SyncStatus.synced);
    await _saveQueueToStorage();

    _isSyncing = false;
    if (failCount == 0 && successCount > 0) {
      _syncMessage = 'All offline data synced successfully!';
    } else if (failCount > 0) {
      _syncMessage = 'Synced $successCount item(s). $failCount failed (will retry automatically).';
    } else {
      _syncMessage = null;
    }

    notifyListeners();
  }

  /// Uploads a single queued record to Firestore safely with duplicate prevention (Idempotency)
  Future<void> _uploadRecordToServer(OfflineQueueItem item) async {
    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection(item.collectionPath);

    // 1. Idempotency Check: Query server to see if localTxId has already been recorded
    final existingDocSnap = await collectionRef
        .where('idempotencyKey', isEqualTo: item.localTxId)
        .limit(1)
        .get();

    if (existingDocSnap.docs.isNotEmpty) {
      debugPrint('OfflineSyncService: Record ${item.localTxId} already exists on server. Marking synced.');
      return;
    }

    // 2. Prepare Firestore document payload
    final docPayload = Map<String, dynamic>.from(item.payload);

    // Preserve original timestamp while injecting server sync timestamp
    docPayload['idempotencyKey'] = item.localTxId;
    docPayload['syncedAt'] = FieldValue.serverTimestamp();
    docPayload['isOfflineEntry'] = true;

    // Convert ISO string dates to Timestamp if necessary
    if (docPayload['entryDate'] is String) {
      try {
        docPayload['entryDate'] = Timestamp.fromDate(DateTime.parse(docPayload['entryDate']));
      } catch (_) {}
    }
    if (docPayload['createdAt'] is String) {
      try {
        docPayload['createdAt'] = Timestamp.fromDate(DateTime.parse(docPayload['createdAt']));
      } catch (_) {}
    }

    // 3. Perform write
    if (item.documentId != null && item.documentId!.isNotEmpty) {
      final docRef = collectionRef.doc(item.documentId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        // Merge with existing doc if present
        await docRef.set(docPayload, SetOptions(merge: true));
      } else {
        await docRef.set(docPayload);
      }
    } else {
      await collectionRef.add(docPayload);
    }
  }

  /// Persistent Queue Storage
  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _queue.map((item) => item.toMap()).toList();
      await prefs.setString(_queueStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to save queue to storage: $e');
    }
  }

  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(raw);
        _queue = jsonList.map((m) => OfflineQueueItem.fromMap(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to load queue from storage: $e');
    }
  }

  // ===========================================================================
  // MASTER DATA CACHING FOR OFFLINE DROPDOWNS & SELECTIONS
  // ===========================================================================

  /// Caches key master data map locally for offline selections
  static Future<void> cacheMasterData(String categoryKey, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullKey = '$_masterCacheKeyPrefix${FirestoreService.currentOrgId}_$categoryKey';
      await prefs.setString(fullKey, jsonEncode(data));
      debugPrint('OfflineSyncService: Cached master data for key $fullKey');
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to cache master data: $e');
    }
  }

  /// Retrieves cached master data locally when offline
  static Future<dynamic> getCachedMasterData(String categoryKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullKey = '$_masterCacheKeyPrefix${FirestoreService.currentOrgId}_$categoryKey';
      final raw = prefs.getString(fullKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw);
      }
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to load cached master data: $e');
    }
    return null;
  }
}
