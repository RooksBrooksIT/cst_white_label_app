import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/organization/site_financial_details_page.dart';

class OrgSupervisorInSitePage extends StatefulWidget {
  const OrgSupervisorInSitePage({super.key});

  @override
  State<OrgSupervisorInSitePage> createState() => _OrgSupervisorInSitePageState();
}

class _OrgSupervisorInSitePageState extends State<OrgSupervisorInSitePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Assigned', 'Unassigned'

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      AppTheme.showErrorToast(context, 'No phone number available');
      return;
    }
    final Uri url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          AppTheme.showErrorToast(context, 'Could not launch dialer for $cleanPhone');
        }
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Error making call: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Supervisor in Site',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            elevation: 0,
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 750,
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.getCollection('supervisor').snapshots(),
                  builder: (context, supSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
                      builder: (context, mapSnap) {
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirestoreService.getCollection('Site').snapshots(),
                          builder: (context, siteSnap) {
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirestoreService.projects.snapshots(),
                              builder: (context, projSnap) {
                                if (supSnap.connectionState == ConnectionState.waiting &&
                                    mapSnap.connectionState == ConnectionState.waiting &&
                                    siteSnap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final supDocs = supSnap.hasData ? supSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                final mapDocs = mapSnap.hasData ? mapSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                final siteDocs = siteSnap.hasData ? siteSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                final projDocs = projSnap.hasData ? projSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                // 1. Build Sites Meta Map (siteId -> {siteName, projectName, location, stage, status, rawData})
                                final siteMetaMap = <String, Map<String, dynamic>>{};

                                for (var d in siteDocs) {
                                  final data = d.data();
                                  final sId = (data['siteId'] ?? d.id).toString().trim();
                                  if (sId.isNotEmpty) {
                                    siteMetaMap[sId] = {
                                      'siteId': sId,
                                      'siteName': (data['siteName'] ?? data['projectName'] ?? sId).toString(),
                                      'projectName': (data['projectName'] ?? data['siteName'] ?? '').toString(),
                                      'location': (data['siteLocation'] ?? data['location'] ?? data['address'] ?? '').toString(),
                                      'stage': (data['currentStage'] ?? data['projectStage'] ?? data['stage'] ?? '').toString(),
                                      'status': (data['currentStatus'] ?? data['status'] ?? 'Live').toString(),
                                      'supervisor': (data['supervisor'] ?? data['supervisorName'] ?? '').toString(),
                                      'rawData': data,
                                    };
                                  }
                                }

                                for (var d in projDocs) {
                                  final data = d.data();
                                  final sId = (data['siteId'] ?? d.id).toString().trim();
                                  if (sId.isNotEmpty) {
                                    final existing = siteMetaMap[sId];
                                    siteMetaMap[sId] = {
                                      'siteId': sId,
                                      'siteName': existing?['siteName'] ?? (data['siteName'] ?? data['projectName'] ?? sId).toString(),
                                      'projectName': (data['projectName'] ?? existing?['projectName'] ?? '').toString(),
                                      'location': (data['siteLocation'] ?? data['location'] ?? existing?['location'] ?? '').toString(),
                                      'stage': (data['currentStage'] ?? existing?['stage'] ?? '').toString(),
                                      'status': (data['currentStatus'] ?? data['status'] ?? existing?['status'] ?? 'Live').toString(),
                                      'supervisor': (data['supervisor'] ?? data['supervisorName'] ?? existing?['supervisor'] ?? '').toString(),
                                      'rawData': existing?['rawData'] ?? data,
                                    };
                                  }
                                }

                                // 2. Aggregate Unified Supervisor-to-Site Allocation Data
                                final unifiedSupervisors = _buildUnifiedSupervisors(
                                  supDocs: supDocs,
                                  mapDocs: mapDocs,
                                  siteMetaMap: siteMetaMap,
                                );

                                // 3. Compute KPI Metrics
                                final totalSupervisors = unifiedSupervisors.length;
                                final assignedCount = unifiedSupervisors.where((s) => s.isAssigned).length;
                                final unassignedCount = totalSupervisors - assignedCount;

                                // 4. Apply Live Search & Filters
                                final query = _searchQuery.trim().toLowerCase();
                                final filteredList = unifiedSupervisors.where((item) {
                                  final matchesQuery = query.isEmpty ||
                                      item.supervisorName.toLowerCase().contains(query) ||
                                      item.supervisorId.toLowerCase().contains(query) ||
                                      item.phoneNumber.toLowerCase().contains(query) ||
                                      item.siteId.toLowerCase().contains(query) ||
                                      item.siteName.toLowerCase().contains(query) ||
                                      item.projectName.toLowerCase().contains(query) ||
                                      item.location.toLowerCase().contains(query);

                                  bool matchesFilter = true;
                                  if (_selectedFilter == 'Assigned') {
                                    matchesFilter = item.isAssigned;
                                  } else if (_selectedFilter == 'Unassigned') {
                                    matchesFilter = !item.isAssigned;
                                  }

                                  return matchesQuery && matchesFilter;
                                }).toList();

                                return RefreshIndicator(
                                  onRefresh: () async {
                                    setState(() {});
                                  },
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // ── Top Summary KPI Cards ──────────────────────
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildKpiCard(
                                                title: 'Total Staff',
                                                value: '$totalSupervisors',
                                                subtitle: 'Supervisors',
                                                icon: Icons.people_alt_rounded,
                                                color: primaryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildKpiCard(
                                                title: 'On Sites',
                                                value: '$assignedCount',
                                                subtitle: 'Active deployed',
                                                icon: Icons.domain_rounded,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildKpiCard(
                                                title: 'Available',
                                                value: '$unassignedCount',
                                                subtitle: 'Unassigned',
                                                icon: Icons.person_search_rounded,
                                                color: const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // ── Search & Filter Box ─────────────────────────
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              TextField(
                                                controller: _searchController,
                                                onChanged: (val) => setState(() => _searchQuery = val),
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                decoration: InputDecoration(
                                                  hintText: 'Search supervisor name, site, project...',
                                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                                                  suffixIcon: _searchQuery.isNotEmpty
                                                      ? IconButton(
                                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                                          onPressed: () {
                                                            _searchController.clear();
                                                            setState(() => _searchQuery = '');
                                                          },
                                                        )
                                                      : null,
                                                  filled: true,
                                                  fillColor: const Color(0xFFF8FAFC),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  const Text(
                                                    'Filter:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildFilterChip('All', totalSupervisors, primaryColor),
                                                  const SizedBox(width: 6),
                                                  _buildFilterChip('Assigned', assignedCount, primaryColor),
                                                  const SizedBox(width: 6),
                                                  _buildFilterChip('Unassigned', unassignedCount, primaryColor),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),

                                        // ── Supervisors List ────────────────────────────
                                        if (filteredList.isEmpty)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFF1F5F9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.person_off_rounded,
                                                    size: 40,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                                Text(
                                                  _searchQuery.isEmpty ? 'No Supervisors Found' : 'No Matching Allocation',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: darkAccent,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _searchQuery.isEmpty
                                                      ? 'Add supervisors in Manager Config or assign them to sites in Site Setup.'
                                                      : 'Try searching with a different name or clearing filter.',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: filteredList.length,
                                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                                            itemBuilder: (context, index) {
                                              final supervisor = filteredList[index];
                                              return _buildSupervisorCard(
                                                supervisor: supervisor,
                                                primaryColor: primaryColor,
                                                darkAccent: darkAccent,
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, Color primaryColor) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorCard({
    required _SupervisorEntry supervisor,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: supervisor.isAssigned
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFED7AA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Row: Profile Avatar + Name + Phone Call CTA ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: supervisor.isAssigned
                          ? [
                              primaryColor.withValues(alpha: 0.18),
                              primaryColor.withValues(alpha: 0.08),
                            ]
                          : [
                              const Color(0xFFF59E0B).withValues(alpha: 0.18),
                              const Color(0xFFF59E0B).withValues(alpha: 0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: supervisor.isAssigned
                          ? primaryColor.withValues(alpha: 0.3)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      supervisor.isAssigned ? Icons.engineering_rounded : Icons.person_rounded,
                      color: supervisor.isAssigned ? primaryColor : const Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              supervisor.supervisorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: supervisor.isAssigned
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: supervisor.isAssigned
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  supervisor.isAssigned ? 'ON SITE' : 'AVAILABLE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: supervisor.isAssigned
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            supervisor.designation,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (supervisor.supervisorId.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• ID: ${supervisor.supervisorId}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (supervisor.phoneNumber.isNotEmpty)
                  InkWell(
                    onTap: () => _makePhoneCall(supervisor.phoneNumber),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: const Icon(
                        Icons.phone_rounded,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Assigned Site Box ───────────────────────────────────────
            if (supervisor.isAssigned)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.domain_rounded, size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'ASSIGNED SITE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (supervisor.siteRawData != null)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SiteFinancialDetailsPage(
                                    siteId: supervisor.siteId,
                                    siteName: supervisor.siteName,
                                    projectName: supervisor.projectName,
                                    ownerName: supervisor.siteRawData?['ownerName']?.toString() ?? '',
                                    initialData: supervisor.siteRawData,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Site Details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_outward_rounded, size: 12, color: primaryColor),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supervisor.siteName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (supervisor.projectName.isNotEmpty &&
                                  supervisor.projectName != supervisor.siteName) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Project: ${supervisor.projectName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            supervisor.siteId,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (supervisor.location.isNotEmpty || supervisor.projectStage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (supervisor.location.isNotEmpty) ...[
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                supervisor.location,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (supervisor.location.isNotEmpty && supervisor.projectStage.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
                          if (supervisor.projectStage.isNotEmpty) ...[
                            const Icon(Icons.stairs_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Stage: ${supervisor.projectStage}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Supervisor currently free / ready for new site assignment.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_SupervisorEntry> _buildUnifiedSupervisors({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> supDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> mapDocs,
    required Map<String, Map<String, dynamic>> siteMetaMap,
  }) {
    final Map<String, _SupervisorEntry> supervisorMap = {};

    // 1. Ingest Master Supervisor registrations
    for (var doc in supDocs) {
      final data = doc.data();
      final name = (data['supervisorName'] ?? data['name'] ?? data['supervisor'] ?? doc.id).toString().trim();
      final id = (data['supervisorId'] ?? data['id'] ?? data['code'] ?? doc.id).toString().trim();
      final phone = (data['phoneNumber'] ?? data['phone'] ?? data['contact'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final designation = (data['designation'] ?? data['role'] ?? 'Site Supervisor').toString().trim();
      final assignedSiteId = (data['assignedSite'] ?? data['siteId'] ?? data['site'] ?? '').toString().trim();

      final key = name.toLowerCase();
      final siteMeta = siteMetaMap[assignedSiteId];

      supervisorMap[key] = _SupervisorEntry(
        supervisorName: name,
        supervisorId: id,
        phoneNumber: phone,
        email: email,
        designation: designation,
        siteId: assignedSiteId,
        siteName: assignedSiteId.isNotEmpty ? ((siteMeta?['siteName'] as String?) ?? assignedSiteId) : '',
        projectName: assignedSiteId.isNotEmpty ? ((siteMeta?['projectName'] as String?) ?? '') : '',
        location: assignedSiteId.isNotEmpty ? ((siteMeta?['location'] as String?) ?? '') : '',
        projectStage: assignedSiteId.isNotEmpty ? ((siteMeta?['stage'] as String?) ?? '') : '',
        isAssigned: assignedSiteId.isNotEmpty,
        siteRawData: assignedSiteId.isNotEmpty ? (siteMeta?['rawData'] as Map<String, dynamic>?) : null,
      );
    }

    // 2. Ingest siteSupervisorMap collection docs
    for (var doc in mapDocs) {
      final data = doc.data();
      final name = (data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final sId = (data['site'] ?? data['siteId'] ?? doc.id).toString().trim();
      final pName = (data['projectName'] ?? data['project'] ?? '').toString().trim();
      final location = (data['location'] ?? '').toString().trim();
      final stage = (data['projectStage'] ?? data['stage'] ?? '').toString().trim();
      final phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString().trim();
      final supId = (data['Supervisor ID'] ?? data['supervisorId'] ?? '').toString().trim();

      final key = name.toLowerCase();
      final existing = supervisorMap[key];
      final siteMeta = siteMetaMap[sId];

      String resolvedSiteName = '';
      if (sId.isNotEmpty) {
        resolvedSiteName = (siteMeta?['siteName'] as String?) ?? (pName.isNotEmpty ? pName : sId);
      }

      String resolvedProjName = pName.isNotEmpty
          ? pName
          : ((siteMeta?['projectName'] as String?) ?? '');

      String resolvedLocation = location.isNotEmpty
          ? location
          : ((siteMeta?['location'] as String?) ?? '');

      String resolvedStage = stage.isNotEmpty
          ? stage
          : ((siteMeta?['stage'] as String?) ?? '');

      supervisorMap[key] = _SupervisorEntry(
        supervisorName: existing?.supervisorName ?? name,
        supervisorId: supId.isNotEmpty ? supId : (existing?.supervisorId ?? ''),
        phoneNumber: phone.isNotEmpty ? phone : (existing?.phoneNumber ?? ''),
        email: existing?.email ?? '',
        designation: existing?.designation ?? 'Site Supervisor',
        siteId: sId,
        siteName: resolvedSiteName,
        projectName: resolvedProjName,
        location: resolvedLocation,
        projectStage: resolvedStage,
        isAssigned: sId.isNotEmpty,
        siteRawData: (siteMeta?['rawData'] as Map<String, dynamic>?) ?? existing?.siteRawData,
      );
    }

    // 3. Ingest assigned supervisors in Site/projects collections not yet matched
    siteMetaMap.forEach((sId, meta) {
      final supName = (meta['supervisor'] ?? '').toString().trim();
      if (supName.isNotEmpty) {
        final key = supName.toLowerCase();
        if (!supervisorMap.containsKey(key)) {
          supervisorMap[key] = _SupervisorEntry(
            supervisorName: supName,
            supervisorId: '',
            phoneNumber: '',
            email: '',
            designation: 'Site Supervisor',
            siteId: sId,
            siteName: meta['siteName'] ?? sId,
            projectName: meta['projectName'] ?? '',
            location: meta['location'] ?? '',
            projectStage: meta['stage'] ?? '',
            isAssigned: true,
            siteRawData: meta['rawData'],
          );
        } else if (!supervisorMap[key]!.isAssigned) {
          final existing = supervisorMap[key]!;
          supervisorMap[key] = _SupervisorEntry(
            supervisorName: existing.supervisorName,
            supervisorId: existing.supervisorId,
            phoneNumber: existing.phoneNumber,
            email: existing.email,
            designation: existing.designation,
            siteId: sId,
            siteName: meta['siteName'] ?? sId,
            projectName: meta['projectName'] ?? '',
            location: meta['location'] ?? '',
            projectStage: meta['stage'] ?? '',
            isAssigned: true,
            siteRawData: meta['rawData'],
          );
        }
      }
    });

    final list = supervisorMap.values.toList();
    list.sort((a, b) {
      // Prioritize assigned supervisors first, then sort alphabetically
      if (a.isAssigned != b.isAssigned) {
        return a.isAssigned ? -1 : 1;
      }
      return a.supervisorName.toLowerCase().compareTo(b.supervisorName.toLowerCase());
    });

    return list;
  }
}

class _SupervisorEntry {
  final String supervisorName;
  final String supervisorId;
  final String phoneNumber;
  final String email;
  final String designation;
  final String siteId;
  final String siteName;
  final String projectName;
  final String location;
  final String projectStage;
  final bool isAssigned;
  final Map<String, dynamic>? siteRawData;

  _SupervisorEntry({
    required this.supervisorName,
    required this.supervisorId,
    required this.phoneNumber,
    required this.email,
    required this.designation,
    required this.siteId,
    required this.siteName,
    required this.projectName,
    required this.location,
    required this.projectStage,
    required this.isAssigned,
    this.siteRawData,
  });
}
