import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/utils/terms_helper.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/organization/pricing_screen.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';

import 'package:demo_cst/services/subscription_limit_service.dart';

class OrganizationSubscriptionPage extends StatefulWidget {
  const OrganizationSubscriptionPage({super.key});

  @override
  State<OrganizationSubscriptionPage> createState() =>
      _OrganizationSubscriptionPageState();
}

class _OrganizationSubscriptionPageState
    extends State<OrganizationSubscriptionPage> {
  bool _isLoading = true;
  String _planName = 'Loading...';
  String _status = 'Loading...';
  String _expiryDate = 'Loading...';
  int _daysRemaining = 0;
  bool _isActive = false;
  bool _isUpgradeQueued = false;
  String _queuedPlanName = '';
  String _queuedStartDate = '';

  SubscriptionPlanLimits _limits =
      SubscriptionLimitService.getLimitsForPlan('Free Trial');
  SubscriptionUsage _usage = const SubscriptionUsage(
    siteCount: 0,
    managerCount: 0,
    supervisorCount: 0,
    totalUserCount: 0,
  );

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionAndUsage();
  }

  Future<void> _loadSubscriptionAndUsage() async {
    try {
      final limits = await SubscriptionLimitService.getActivePlanLimits();
      final usage = await SubscriptionLimitService.getCurrentUsage();

      var doc = await FirestoreService.subscriptionDoc.get();
      if (!doc.exists) {
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (mounted) {
        String expiryDate = 'Lifetime Active';
        int daysRemaining = 365;
        bool isActive = true;
        bool isUpgradeQueued = false;
        String queuedPlanName = '';
        String queuedStartDate = '';

        if (doc.exists) {
          final data = doc.data()!;
          final isActiveField = data['isSubscriptionActive'] as bool? ?? true;
          final expiry = data['subscriptionEndDate'] as Timestamp?;

          if (expiry != null) {
            final expDate = expiry.toDate();
            final now = DateTime.now();
            final isExpired = now.isAfter(expDate);
            daysRemaining = expDate.difference(now).inDays;
            if (daysRemaining < 0) daysRemaining = 0;
            expiryDate = DateFormat('dd MMM yyyy').format(expDate);
            isActive = isActiveField && !isExpired;
          }

          final isQueued = data['isUpgradeQueued'] as bool? ?? false;
          final queuedPlanRaw = data['queuedPlan'] as String?;
          final queuedStartTs = data['queuedStartDate'] as Timestamp?;
          if (isQueued && queuedPlanRaw != null && queuedPlanRaw.isNotEmpty) {
            isUpgradeQueued = true;
            queuedPlanName = _formatPlanName(queuedPlanRaw);
            if (queuedStartTs != null) {
              queuedStartDate =
                  DateFormat('dd MMM yyyy').format(queuedStartTs.toDate());
            } else {
              queuedStartDate = expiryDate;
            }
          }
        }

        setState(() {
          _limits = limits;
          _usage = usage;
          _planName = limits.planName;
          _isActive = isActive;
          _status = isActive ? 'Active' : 'Inactive';
          _expiryDate = expiryDate;
          _daysRemaining = daysRemaining;
          _isUpgradeQueued = isUpgradeQueued;
          _queuedPlanName = queuedPlanName;
          _queuedStartDate = queuedStartDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatPlanName(String raw) {
    if (raw.trim().isEmpty) return 'Free Trial';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: _isActive,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Manage Subscription',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkAccent,
                  Color.alphaBlend(
                    primaryColor.withValues(alpha: 0.35),
                    darkAccent,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: _isActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      primary: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── 1. Hero Plan & Billing Card ───────────────────
                          _buildCurrentPlanCard(darkAccent),
                          const SizedBox(height: 16),

                          // ── 2. Usage & Quota Overview Card ────────────────
                          _buildUsageMetricsCard(darkAccent),
                          const SizedBox(height: 16),

                          // ── 3. Plan Features / Entitlements ───────────────
                          _buildPlanDetailsSection(darkAccent),
                          const SizedBox(height: 16),

                          // ── 4. Upgrade / Manage Plan Action Card ──────────
                          _buildChangePlanSection(darkAccent),
                          const SizedBox(height: 20),

                          // ── 5. Terms & Refund Policy Link ────────────────
                          Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.description_rounded, size: 16, color: Color(0xFF0284C7)),
                              label: const Text(
                                'Terms & Conditions • Refund Policy',
                                style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              onPressed: () {
                                TermsHelper.showTermsDialog(
                                  context,
                                  onAccepted: () {},
                                  readOnly: true,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          Center(
                            child: Text(
                              'CST Cloud Infrastructure • Enterprise Encryption',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI SECTIONS
  // ---------------------------------------------------------------------------

  Widget _buildCurrentPlanCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkAccent,
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'SUBSCRIPTION TIER',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Plan Name
          Text(
            _planName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isActive
                ? '$_daysRemaining days remaining until next renewal'
                : 'Your subscription period has ended',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),

          // Renewal / Billing Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_repeat_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Renewal Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  _expiryDate,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          if (_isUpgradeQueued) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.amber.shade400.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Queued Upgrade: $_queuedPlanName (Activates $_queuedStartDate)',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageMetricsCard(Color darkAccent) {
    final isSilver = _limits.planName == 'Silver';
    final isFreeTrial = _limits.planName == 'Free Trial';
    final isEnterprise = _limits.planName == 'Enterprise';

    final List<Widget> statItems;

    if (isEnterprise) {
      statItems = [
        Expanded(
          child: _buildUsageStatItem(
            'Active Sites',
            '${_usage.siteCount}',
            'Unlimited',
            Icons.location_city_rounded,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Managers',
            '${_usage.managerCount}',
            'Unlimited',
            Icons.admin_panel_settings_rounded,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Supervisors',
            '${_usage.supervisorCount}',
            'Unlimited',
            Icons.supervisor_account_rounded,
            const Color(0xFF0284C7),
          ),
        ),
      ];
    } else if (isSilver || isFreeTrial) {
      final maxSites = _limits.maxProjects;
      final maxUsers = _limits.maxTotalUsers;
      final sitesDisplay = '${_usage.siteCount.clamp(0, maxSites)} / $maxSites';
      final usersDisplay = '${_usage.totalUserCount.clamp(0, maxUsers)} / $maxUsers';
      final sitesStatus = _usage.siteCount >= maxSites
          ? 'Limit Reached'
          : '${maxSites - _usage.siteCount} Available';
      final usersStatus = _usage.totalUserCount >= maxUsers
          ? 'Limit Reached'
          : '${maxUsers - _usage.totalUserCount} Available';

      statItems = [
        Expanded(
          child: _buildUsageStatItem(
            'Active Sites',
            sitesDisplay,
            sitesStatus,
            Icons.location_city_rounded,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Team Users',
            usersDisplay,
            usersStatus,
            Icons.group_rounded,
            const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Cloud Storage',
            isSilver ? 'Daily Sync' : 'Standard',
            'Cloud Backup',
            Icons.cloud_done_rounded,
            const Color(0xFF8B5CF6),
          ),
        ),
      ];
    } else {
      // Gold & Platinum
      final maxSites = _limits.maxProjects;
      final maxManagers = _limits.maxManagers ?? 5;
      final maxSupervisors = _limits.maxSupervisors ?? 10;
      final sitesDisplay = '${_usage.siteCount.clamp(0, maxSites)} / $maxSites';
      final managersDisplay = '${_usage.managerCount.clamp(0, maxManagers)} / $maxManagers';
      final supsDisplay = '${_usage.supervisorCount.clamp(0, maxSupervisors)} / $maxSupervisors';

      final sitesStatus = _usage.siteCount >= maxSites ? 'Limit Reached' : 'Max $maxSites';
      final managersStatus = _usage.managerCount >= maxManagers ? 'Limit Reached' : 'Max $maxManagers';
      final supsStatus = _usage.supervisorCount >= maxSupervisors ? 'Limit Reached' : 'Max $maxSupervisors';

      statItems = [
        Expanded(
          child: _buildUsageStatItem(
            'Active Sites',
            sitesDisplay,
            sitesStatus,
            Icons.location_city_rounded,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Managers',
            managersDisplay,
            managersStatus,
            Icons.admin_panel_settings_rounded,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUsageStatItem(
            'Supervisors',
            supsDisplay,
            supsStatus,
            Icons.supervisor_account_rounded,
            const Color(0xFF0284C7),
          ),
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_usage_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Workspace Capacity & Usage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),
          Row(
            children: statItems,
          ),
        ],
      ),
    );
  }

  List<String> _getFeaturesForCurrentPlan() {
    return _limits.features;
  }

  Widget _buildUsageStatItem(
    String title,
    String value,
    String limit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              limit,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailsSection(Color darkAccent) {
    final features = _getFeaturesForCurrentPlan();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Included Entitlements & Features',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: _buildFeatureItem(feature),
              )),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF10B981),
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePlanSection(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upgrade or Modify Subscription',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: darkAccent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore multi-tier plans, switch billing periods, or scale your operations with additional seats.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final theme = Theme.of(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PricingScreen(
                            orgName: '',
                            email: '',
                            phone: '',
                            username: '',
                            password: '',
                            dateStr: '',
                            appName: '',
                            selectedColor: theme.primaryColor,
                            currentPlan: _planName,
                            isManagingExisting: true,
                          ),
                        ),
                      ).then((_) => _loadSubscriptionAndUsage());
                    },
                    icon: const Icon(Icons.upgrade_rounded, size: 20),
                    label: const Text(
                      'MANAGE / UPGRADE PLAN',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Contact Billing Support',
                icon: Icon(Icons.help_outline_rounded, color: primaryColor),
                style: IconButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
