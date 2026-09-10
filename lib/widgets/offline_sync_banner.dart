import 'package:flutter/material.dart';
import 'package:ebricks/services/offline_sync_service.dart';

/// Small, non-intrusive top mini pill indicator that respects SafeArea
/// and does NOT overlap OS status bars, battery, time, or app headers.
class OfflineSyncBanner extends StatefulWidget {
  const OfflineSyncBanner({super.key});

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends State<OfflineSyncBanner> {
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _syncService.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncService.isOnline;
    final isSyncing = _syncService.isSyncing;
    final pendingCount = _syncService.pendingCount;

    // Do NOT show top badge when online with no sync action or pending items
    if (isOnline && !isSyncing && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    Color pillBg;
    IconData icon;
    String label;

    if (!isOnline) {
      pillBg = const Color(0xFFDC2626); // Clean red badge
      icon = Icons.wifi_off_rounded;
      label = pendingCount > 0 ? 'Offline ($pendingCount pending)' : 'Offline';
    } else if (isSyncing) {
      pillBg = const Color(0xFF2563EB); // Blue badge
      icon = Icons.sync_rounded;
      label = 'Syncing...';
    } else {
      pillBg = const Color(0xFFD97000); // Amber badge
      icon = Icons.cloud_queue_rounded;
      label = '$pendingCount pending sync';
    }

    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(icon, color: Colors.white, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated, clean Sync/Offline Status Section Card for Dashboards & Forms
class SyncStatusCard extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const SyncStatusCard({
    super.key,
    this.margin,
    this.compact = false,
  });

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _syncService.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncService.isOnline;
    final isSyncing = _syncService.isSyncing;
    final pendingCount = _syncService.pendingCount;

    Color cardBg;
    Color borderColor;
    Color iconBg;
    Color iconColor;
    Color titleColor;
    Color subtextColor;
    IconData icon;
    String titleText;
    String subtitleText;

    if (!isOnline) {
      cardBg = const Color(0xFFFEF2F2); // Soft red tint
      borderColor = const Color(0xFFFECACA);
      iconBg = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFDC2626);
      titleColor = const Color(0xFF991B1B);
      subtextColor = const Color(0xFFB91C1C);
      icon = Icons.wifi_off_rounded;
      titleText = 'Offline – Data will be saved locally';
      subtitleText = pendingCount > 0
          ? '$pendingCount entries waiting to sync'
          : 'Mobile network unavailable. Data saved safely on device.';
    } else if (isSyncing) {
      cardBg = const Color(0xFFEFF6FF); // Soft blue tint
      borderColor = const Color(0xFFBFDBFE);
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF2563EB);
      titleColor = const Color(0xFF1E40AF);
      subtextColor = const Color(0xFF1D4ED8);
      icon = Icons.sync_rounded;
      titleText = 'Syncing...';
      subtitleText = pendingCount > 0
          ? 'Uploading $pendingCount pending entry(s) to server'
          : 'Syncing offline records with server...';
    } else if (pendingCount > 0) {
      cardBg = const Color(0xFFFFFBEB); // Soft amber tint
      borderColor = const Color(0xFFFDE68A);
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFD97000);
      titleColor = const Color(0xFF92400E);
      subtextColor = const Color(0xFFB45309);
      icon = Icons.cloud_upload_rounded;
      titleText = '$pendingCount entries waiting to sync';
      subtitleText = 'Network connection restored. Tap to sync now.';
    } else {
      cardBg = const Color(0xFFECFDF5); // Soft emerald tint
      borderColor = const Color(0xFFA7F3D0);
      iconBg = const Color(0xFFD1FAE5);
      iconColor = const Color(0xFF059669);
      titleColor = const Color(0xFF065F46);
      subtextColor = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      titleText = 'All data synced';
      subtitleText = 'Device is online and all changes are up to date.';
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(widget.compact ? 10 : 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: widget.compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: widget.compact ? 11 : 11.5,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
          if (isOnline && pendingCount > 0 && !isSyncing) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _syncService.processSyncQueue(),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Sync Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
