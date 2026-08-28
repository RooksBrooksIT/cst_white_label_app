import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';

/// Centralized data model defining exact subscription limits for each plan.
class SubscriptionPlanLimits {
  final String planName;
  final int maxProjects; // Active Sites / Projects limit
  final int? maxManagers; // null if not individually constrained
  final int? maxSupervisors; // null if not individually constrained
  final int maxTotalUsers; // Total team users limit
  final List<String> features;
  final bool isUnlimited;

  const SubscriptionPlanLimits({
    required this.planName,
    required this.maxProjects,
    this.maxManagers,
    this.maxSupervisors,
    required this.maxTotalUsers,
    required this.features,
    this.isUnlimited = false,
  });
}

/// Exact document upload, delete, and re-upload rules for Layout & Drawings per subscription plan.
class DrawingPlanLimits {
  final String planName;
  final int maxActiveDocsPerSite; // Silver: 1, Gold: 1, Platinum: 2, Enterprise: 2
  final bool allowDelete; // Silver: false, Gold: true, Platinum: true
  final int? maxDeletesPerSite; // Silver: 0, Gold: 1, Platinum: null (unlimited)
  final bool allowReupload; // Silver: false, Gold: true, Platinum: true
  final int? maxReuploadsPerSite; // Silver: 0, Gold: 1, Platinum: null (unlimited)
  final String description;

  const DrawingPlanLimits({
    required this.planName,
    required this.maxActiveDocsPerSite,
    required this.allowDelete,
    this.maxDeletesPerSite,
    required this.allowReupload,
    this.maxReuploadsPerSite,
    required this.description,
  });
}

/// Site-level drawing usage metrics tracked in Firestore.
class SiteDrawingUsage {
  final String siteId;
  final int activeDocsCount;
  final int deleteCount;
  final int reuploadCount;
  final int totalUploadCount;

  const SiteDrawingUsage({
    required this.siteId,
    required this.activeDocsCount,
    required this.deleteCount,
    required this.reuploadCount,
    required this.totalUploadCount,
  });

  factory SiteDrawingUsage.empty(String siteId) {
    return SiteDrawingUsage(
      siteId: siteId,
      activeDocsCount: 0,
      deleteCount: 0,
      reuploadCount: 0,
      totalUploadCount: 0,
    );
  }
}

/// Real-time workspace usage metrics.
class SubscriptionUsage {
  final int siteCount;
  final int managerCount;
  final int supervisorCount;
  final int totalUserCount;

  const SubscriptionUsage({
    required this.siteCount,
    required this.managerCount,
    required this.supervisorCount,
    required this.totalUserCount,
  });
}

/// Validation result for resource creation and feature access.
class SubscriptionValidationResult {
  final bool isAllowed;
  final String? errorMessage;
  final String? upgradePrompt;

  const SubscriptionValidationResult({
    required this.isAllowed,
    this.errorMessage,
    this.upgradePrompt,
  });

  static const allowed = SubscriptionValidationResult(isAllowed: true);
}

/// Centralized subscription access-control service enforcing exact plan limitations,
/// dynamic Platinum site quotas, and strict validation across the entire application.
class SubscriptionLimitService {
  /// Resolves the strict plan configuration according to the subscription document.
  static SubscriptionPlanLimits getLimitsForPlan(
    String rawPlanName, {
    int? platinumSitesCount,
  }) {
    final norm = rawPlanName.trim().toLowerCase();

    if (norm.contains('enterprise')) {
      return const SubscriptionPlanLimits(
        planName: 'Enterprise',
        maxProjects: 999999,
        maxManagers: 999999,
        maxSupervisors: 999999,
        maxTotalUsers: 999999,
        features: [
          'Unlimited Projects & Active Sites',
          'Unlimited Managers & Supervisors',
          'Layout & Drawings: Up to 2 active docs per site (multi-delete & re-upload)',
          'Custom Cloud Infrastructure & Dedicated Database',
          '24/7 Priority SLA & Dedicated Account Manager',
          'Custom API Integrations & Webhooks',
          'Enterprise Security & Data Residency',
        ],
        isUnlimited: true,
      );
    } else if (norm.contains('platinum')) {
      final int sites = (platinumSitesCount != null && platinumSitesCount >= 5)
          ? platinumSitesCount
          : 10;
      final int managers = (sites / 2).round().clamp(2, 25);
      final int supervisors = sites;
      final int totalUsers = (sites * 1.5).round();

      return SubscriptionPlanLimits(
        planName: 'Platinum',
        maxProjects: sites,
        maxManagers: managers,
        maxSupervisors: supervisors,
        maxTotalUsers: totalUsers,
        features: [
          'Up to $sites Projects & Active Sites',
          'Up to $managers Managers',
          'Up to $supervisors Supervisors',
          'Layout & Drawings: Up to 2 active docs per site (multi-delete & re-upload)',
          'Advanced collaboration & Workflows',
          'Real-time site monitoring & Live logs',
          'Comprehensive expense tracking & Audits',
          'Priority cloud sync & audit logging',
        ],
      );
    } else if (norm.contains('gold')) {
      return const SubscriptionPlanLimits(
        planName: 'Gold',
        maxProjects: 10,
        maxManagers: 5,
        maxSupervisors: 10,
        maxTotalUsers: 15,
        features: [
          'Up to 10 Projects & Active Sites',
          'Up to 5 Managers & 10 Supervisors',
          'Layout & Drawings: 1 doc per site (1 delete & 1 re-upload)',
          'Advanced collaboration & Site monitoring',
          'Expense tracking & Monthly report views',
          'Role-based Access & Live Timeline',
          'Real-time Material Movement Logs',
        ],
      );
    } else if (norm.contains('silver')) {
      return const SubscriptionPlanLimits(
        planName: 'Silver',
        maxProjects: 3,
        maxManagers: null, // Silver has no separate manager limit
        maxSupervisors: null, // Silver has no separate supervisor limit
        maxTotalUsers: 5,
        features: [
          'Basic Project Management (up to 3 sites)',
          'Layout & Drawings: 1 doc per site (view only, no delete/re-upload)',
          'Task Tracking & Updates',
          'Limited Team Members (3-5)',
          'Basic Reports & Data View',
          'Standard Cloud Backup & Sync',
        ],
      );
    } else {
      // Free Trial default
      return const SubscriptionPlanLimits(
        planName: 'Free Trial',
        maxProjects: 1,
        maxManagers: null,
        maxSupervisors: null,
        maxTotalUsers: 2,
        features: [
          'Basic Project Management',
          'Layout & Drawings: 1 doc per site (view only)',
          'Task Tracking & Updates',
          'Limited Team Members (up to 2)',
          'Basic Reports & Analytics',
          'Standard Cloud Storage',
        ],
      );
    }
  }

  /// Returns specific Layout & Drawings document upload, delete, and re-upload limits.
  static DrawingPlanLimits getDrawingLimitsForPlan(String rawPlanName) {
    final norm = rawPlanName.trim().toLowerCase();

    if (norm.contains('enterprise')) {
      return const DrawingPlanLimits(
        planName: 'Enterprise',
        maxActiveDocsPerSite: 2,
        allowDelete: true,
        maxDeletesPerSite: null,
        allowReupload: true,
        maxReuploadsPerSite: null,
        description: 'Up to 2 active documents per site with unlimited deletions and re-uploads.',
      );
    } else if (norm.contains('platinum')) {
      return const DrawingPlanLimits(
        planName: 'Platinum',
        maxActiveDocsPerSite: 2,
        allowDelete: true,
        maxDeletesPerSite: null,
        allowReupload: true,
        maxReuploadsPerSite: null,
        description: 'Up to 2 active documents per site with unlimited deletions and re-uploads.',
      );
    } else if (norm.contains('gold')) {
      return const DrawingPlanLimits(
        planName: 'Gold',
        maxActiveDocsPerSite: 1,
        allowDelete: true,
        maxDeletesPerSite: 1,
        allowReupload: true,
        maxReuploadsPerSite: 1,
        description: '1 active document per site. 1 delete and 1 re-upload permitted.',
      );
    } else if (norm.contains('silver')) {
      return const DrawingPlanLimits(
        planName: 'Silver',
        maxActiveDocsPerSite: 1,
        allowDelete: false,
        maxDeletesPerSite: 0,
        allowReupload: false,
        maxReuploadsPerSite: 0,
        description: '1 document per site (upload and view only). No deletion or re-upload permitted.',
      );
    } else {
      // Free Trial default
      return const DrawingPlanLimits(
        planName: 'Free Trial',
        maxActiveDocsPerSite: 1,
        allowDelete: false,
        maxDeletesPerSite: 0,
        allowReupload: false,
        maxReuploadsPerSite: 0,
        description: '1 document per site (upload and view only). No deletion or re-upload permitted.',
      );
    }
  }

  /// Fetches the currently active subscription document, promotes queued plans if due,
  /// and returns the active plan limits.
  static Future<SubscriptionPlanLimits> getActivePlanLimits() async {
    try {
      var doc = await FirestoreService.subscriptionDoc.get();
      if (!doc.exists) {
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (doc.exists) {
        final data = doc.data()!;
        final now = DateTime.now();

        // 1. Check for automated activation of queued upgrade upon expiry
        final isQueued = data['isUpgradeQueued'] as bool? ?? false;
        final queuedPlan = data['queuedPlan'] as String?;
        final queuedStart = (data['queuedStartDate'] as Timestamp?)?.toDate();

        if (isQueued && queuedPlan != null && queuedStart != null && !now.isBefore(queuedStart)) {
          final queuedType = data['queuedPlanType'] as String? ?? 'Monthly';
          final queuedEnd = data['queuedEndDate'] as Timestamp?;
          final queuedProjects = (data['queuedMaxProjects'] as num?)?.toInt();
          final queuedUsers = (data['queuedMaxUsers'] as num?)?.toInt();
          final queuedManagers = (data['queuedMaxManagers'] as num?)?.toInt();
          final queuedSupervisors = (data['queuedMaxSupervisors'] as num?)?.toInt();

          await FirestoreService.subscriptionDoc.set({
            'subscriptionPlan': queuedPlan,
            'subscriptionType': queuedType,
            'subscriptionStartDate': Timestamp.fromDate(queuedStart),
            'subscriptionEndDate': queuedEnd ?? Timestamp.fromDate(queuedStart.add(const Duration(days: 30))),
            'isSubscriptionActive': true,
            'isUpgradeQueued': false,
            'queuedPlan': FieldValue.delete(),
            'queuedPlanType': FieldValue.delete(),
            'queuedStartDate': FieldValue.delete(),
            'queuedEndDate': FieldValue.delete(),
            'queuedMaxProjects': FieldValue.delete(),
            'queuedMaxUsers': FieldValue.delete(),
            'queuedMaxManagers': FieldValue.delete(),
            'queuedMaxSupervisors': FieldValue.delete(),
            if (queuedProjects != null) 'maxProjects': queuedProjects,
            if (queuedUsers != null) 'maxUsers': queuedUsers,
            if (queuedManagers != null) 'maxManagers': queuedManagers,
            if (queuedSupervisors != null) 'maxSupervisors': queuedSupervisors,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return getLimitsForPlan(queuedPlan, platinumSitesCount: queuedProjects);
        }

        final currentPlan = data['subscriptionPlan'] as String? ?? 'Free Trial';
        final maxProjects = (data['maxProjects'] as num?)?.toInt();

        return getLimitsForPlan(currentPlan, platinumSitesCount: maxProjects);
      }
    } catch (e) {
      debugPrint('Error loading active subscription plan limits: $e');
    }

    return getLimitsForPlan('Free Trial');
  }

  /// Calculates actual usage in the organization.
  static Future<SubscriptionUsage> getCurrentUsage() async {
    int siteCount = 0;
    int managerCount = 0;
    int supervisorCount = 0;

    try {
      final sitesSnap = await FirestoreService.getCollection('Site').get();
      siteCount = sitesSnap.docs.length;
    } catch (e) {
      debugPrint('Error getting site count: $e');
    }

    try {
      final managerSnap = await FirestoreService.getCollection('manager').get();
      managerCount = managerSnap.docs.length;
    } catch (e) {
      debugPrint('Error getting manager count: $e');
    }

    try {
      final supSnap = await FirestoreService.getCollection('supervisor').get();
      supervisorCount = supSnap.docs.length;
    } catch (e) {
      debugPrint('Error getting supervisor count: $e');
    }

    final totalUserCount = managerCount + supervisorCount;

    return SubscriptionUsage(
      siteCount: siteCount,
      managerCount: managerCount,
      supervisorCount: supervisorCount,
      totalUserCount: totalUserCount,
    );
  }

  /// Fetches site-level drawing metrics including active documents and historical operations.
  static Future<SiteDrawingUsage> getSiteDrawingUsage(String siteId) async {
    final cleanSiteId = siteId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    int activeDocsCount = 0;
    int deleteCount = 0;
    int reuploadCount = 0;
    int totalUploadCount = 0;

    try {
      // 1. Calculate active documents from siteDrawings collection
      final drawingsSnap = await FirestoreService.getCollection('siteDrawings')
          .where('siteId', isEqualTo: siteId.trim())
          .get();

      for (var doc in drawingsSnap.docs) {
        final data = doc.data();
        final docsList = data['siteDocs'] as List<dynamic>? ?? [];
        activeDocsCount += docsList.length;
      }

      // 2. Fetch delete and re-upload tracking history from siteDrawingsUsage
      final usageDoc = await FirestoreService.getCollection('siteDrawingsUsage')
          .doc(cleanSiteId)
          .get();

      if (usageDoc.exists) {
        final data = usageDoc.data()!;
        deleteCount = (data['deleteCount'] as num?)?.toInt() ?? 0;
        reuploadCount = (data['reuploadCount'] as num?)?.toInt() ?? 0;
        totalUploadCount = (data['totalUploadCount'] as num?)?.toInt() ?? 0;
      } else {
        // Fallback: If no usage doc yet but active docs exist, total uploads is at least active docs
        totalUploadCount = activeDocsCount;
      }
    } catch (e) {
      debugPrint('Error loading drawing usage for site $siteId: $e');
    }

    return SiteDrawingUsage(
      siteId: siteId,
      activeDocsCount: activeDocsCount,
      deleteCount: deleteCount,
      reuploadCount: reuploadCount,
      totalUploadCount: totalUploadCount,
    );
  }

  /// Validates whether a new drawing document can be uploaded for a site.
  static Future<SubscriptionValidationResult> canUploadDrawing({
    required String siteId,
    required int newDocsCount,
    String? currentPlanName,
  }) async {
    if (newDocsCount <= 0) return SubscriptionValidationResult.allowed;

    final limits = await getActivePlanLimits();
    final plan = currentPlanName ?? limits.planName;
    final drawingLimits = getDrawingLimitsForPlan(plan);
    final usage = await getSiteDrawingUsage(siteId);

    // 1. Check max active documents capacity
    final resultingActiveDocs = usage.activeDocsCount + newDocsCount;
    if (resultingActiveDocs > drawingLimits.maxActiveDocsPerSite) {
      if (drawingLimits.maxActiveDocsPerSite == 1) {
        return SubscriptionValidationResult(
          isAllowed: false,
          errorMessage:
              'You have reached your limit of 1 active document for Site "$siteId" on the $plan plan. Upgrade to Platinum to upload up to 2 active documents per site.',
          upgradePrompt: 'Upgrade to Platinum for 2 active documents per site.',
        );
      } else {
        return SubscriptionValidationResult(
          isAllowed: false,
          errorMessage:
              'You cannot exceed ${drawingLimits.maxActiveDocsPerSite} active documents for Site "$siteId" on the $plan plan. Please delete an existing document first.',
          upgradePrompt: 'Maximum active documents limit reached for this site.',
        );
      }
    }

    // 2. Check re-upload / subsequent upload limits
    if (usage.totalUploadCount > 0) {
      // Re-upload restriction for Silver
      if (!drawingLimits.allowReupload) {
        return SubscriptionValidationResult(
          isAllowed: false,
          errorMessage:
              'Re-uploading is not permitted on the $plan plan. Users can upload 1 document initially and view only. Upgrade to Gold or Platinum for deletion and re-upload capability.',
          upgradePrompt: 'Upgrade to Gold or Platinum for re-upload capabilities.',
        );
      }

      // Re-upload restriction for Gold
      if (drawingLimits.maxReuploadsPerSite != null &&
          usage.reuploadCount >= drawingLimits.maxReuploadsPerSite!) {
        return SubscriptionValidationResult(
          isAllowed: false,
          errorMessage:
              'You have exhausted your ${drawingLimits.maxReuploadsPerSite} allowed re-upload for Site "$siteId" on the $plan plan. Upgrade to Platinum for unlimited deletions and re-uploads.',
          upgradePrompt: 'Upgrade to Platinum for unlimited re-uploads.',
        );
      }
    }

    return SubscriptionValidationResult.allowed;
  }

  /// Validates whether a drawing document can be deleted for a site.
  static Future<SubscriptionValidationResult> canDeleteDrawing({
    required String siteId,
    String? currentPlanName,
  }) async {
    final limits = await getActivePlanLimits();
    final plan = currentPlanName ?? limits.planName;
    final drawingLimits = getDrawingLimitsForPlan(plan);
    final usage = await getSiteDrawingUsage(siteId);

    // 1. Check if delete is allowed for plan
    if (!drawingLimits.allowDelete) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'Document deletion is not permitted on the $plan plan. Users on the Silver plan can upload and view documents only. Upgrade to Gold or Platinum to enable deletion and replacement.',
        upgradePrompt: 'Upgrade to Gold or Platinum to enable document deletion.',
      );
    }

    // 2. Check if delete quota is exhausted (e.g. Gold plan 1 delete limit)
    if (drawingLimits.maxDeletesPerSite != null &&
        usage.deleteCount >= drawingLimits.maxDeletesPerSite!) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have exhausted your ${drawingLimits.maxDeletesPerSite} allowed deletion for Site "$siteId" on the $plan plan. Upgrade to Platinum for unlimited deletions and re-uploads.',
        upgradePrompt: 'Upgrade to Platinum for unlimited deletions.',
      );
    }

    return SubscriptionValidationResult.allowed;
  }

  /// Records an upload or re-upload event in the site drawing usage tracking document.
  static Future<void> recordDrawingUpload({
    required String siteId,
    required int count,
  }) async {
    try {
      final cleanSiteId = siteId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final docRef = FirestoreService.getCollection('siteDrawingsUsage').doc(cleanSiteId);
      final docSnap = await docRef.get();

      final isFirstTime = !docSnap.exists || ((docSnap.data()?['totalUploadCount'] as num?)?.toInt() ?? 0) == 0;

      await docRef.set({
        'siteId': siteId.trim(),
        'totalUploadCount': FieldValue.increment(count),
        if (!isFirstTime) 'reuploadCount': FieldValue.increment(count),
        'lastUploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording drawing upload for site $siteId: $e');
    }
  }

  /// Records a delete event in the site drawing usage tracking document.
  static Future<void> recordDrawingDelete({
    required String siteId,
    int count = 1,
  }) async {
    try {
      final cleanSiteId = siteId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final docRef = FirestoreService.getCollection('siteDrawingsUsage').doc(cleanSiteId);

      await docRef.set({
        'siteId': siteId.trim(),
        'deleteCount': FieldValue.increment(count),
        'lastDeletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording drawing delete for site $siteId: $e');
    }
  }

  /// Validates whether a new Site / Project can be created.
  static Future<SubscriptionValidationResult> canCreateSite() async {
    final limits = await getActivePlanLimits();
    if (limits.isUnlimited) return SubscriptionValidationResult.allowed;

    final usage = await getCurrentUsage();
    if (usage.siteCount >= limits.maxProjects) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have reached your limit of ${limits.maxProjects} Active ${limits.maxProjects == 1 ? "Site" : "Sites"} on the ${limits.planName} plan. Please upgrade your subscription plan to create additional sites.',
        upgradePrompt: 'Upgrade to expand your Active Sites capacity.',
      );
    }

    return SubscriptionValidationResult.allowed;
  }

  /// Validates whether a new Manager can be created.
  static Future<SubscriptionValidationResult> canCreateManager() async {
    final limits = await getActivePlanLimits();
    if (limits.isUnlimited) return SubscriptionValidationResult.allowed;

    final usage = await getCurrentUsage();

    // 1. Total Team User Limit Check
    if (usage.totalUserCount >= limits.maxTotalUsers) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have reached your total team quota of ${limits.maxTotalUsers} users on the ${limits.planName} plan. Please upgrade your plan to add more team members.',
        upgradePrompt: 'Upgrade to add more managers and supervisors.',
      );
    }

    // 2. Specific Manager Limit Check (e.g. Gold / Platinum)
    if (limits.maxManagers != null && usage.managerCount >= limits.maxManagers!) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have reached your limit of ${limits.maxManagers} Managers on the ${limits.planName} plan. Please upgrade your subscription plan to add more managers.',
        upgradePrompt: 'Upgrade to increase manager allocation.',
      );
    }

    return SubscriptionValidationResult.allowed;
  }

  /// Validates whether a new Supervisor can be created.
  static Future<SubscriptionValidationResult> canCreateSupervisor() async {
    final limits = await getActivePlanLimits();
    if (limits.isUnlimited) return SubscriptionValidationResult.allowed;

    final usage = await getCurrentUsage();

    // 1. Total Team User Limit Check
    if (usage.totalUserCount >= limits.maxTotalUsers) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have reached your total team quota of ${limits.maxTotalUsers} users on the ${limits.planName} plan. Please upgrade your plan to add more team members.',
        upgradePrompt: 'Upgrade to add more managers and supervisors.',
      );
    }

    // 2. Specific Supervisor Limit Check (e.g. Gold / Platinum)
    if (limits.maxSupervisors != null && usage.supervisorCount >= limits.maxSupervisors!) {
      return SubscriptionValidationResult(
        isAllowed: false,
        errorMessage:
            'You have reached your limit of ${limits.maxSupervisors} Supervisors on the ${limits.planName} plan. Please upgrade your subscription plan to add more supervisors.',
        upgradePrompt: 'Upgrade to increase supervisor allocation.',
      );
    }

    return SubscriptionValidationResult.allowed;
  }

  /// Displays standard modal dialog when a subscription limit is reached.
  static Future<void> showLimitReachedDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? currentPlan,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF475569),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Dismiss',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.arrow_upward_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Upgrade Plan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B1942),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PricingScreen(
                    isManagingExisting: true,
                    currentPlan: currentPlan,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

