import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';
import 'package:demo_cst/screens/organization/site_financial_details_page.dart';

class OrgFinancePage extends StatefulWidget {
  const OrgFinancePage({super.key});

  @override
  State<OrgFinancePage> createState() => _OrgFinancePageState();
}

class _OrgFinancePageState extends State<OrgFinancePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedStatusTab = 'All';
  String _searchQuery = '';
  String _sortBy = 'Default'; // 'Default', 'Income', 'Expenses', 'Budget', 'Name'

  final List<String> _statusTabs = [
    'All',
    'Live',
    'In Progress',
    'Planning',
    'Completed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCurrency(num value) {
    if (value == 0) return '0';
    final isNegative = value < 0;
    final absVal = value.abs().round();
    final str = absVal.toString();
    if (str.length <= 3) {
      return isNegative ? '-$str' : str;
    }

    final last3 = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    final formatted = buffer.toString();
    return isNegative ? '-$formatted' : formatted;
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(',', '').replaceAll('₹', '').trim();
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('finish') || s.contains('done')) {
      return const Color(0xFF10B981);
    }
    if (s.contains('plan') || s.contains('draft') || s.contains('setup')) {
      return const Color(0xFF6366F1);
    }
    if (s.contains('hold') || s.contains('pause') || s.contains('pending')) {
      return const Color(0xFFF59E0B);
    }
    if (s.contains('delay') || s.contains('overdue')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF0284C7); // Live / In Progress
  }

  Map<String, Map<String, dynamic>> _buildUnifiedSiteDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> projectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> supervisorDocs,
  }) {
    final Map<String, Map<String, dynamic>> unified = {};

    // 1. Ingest Site collection docs
    for (var doc in siteDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      final siteId = (data['siteId'] ?? data['siteid'] ?? doc.id).toString().trim();
      if (siteId.isNotEmpty) {
        data['docId'] = doc.id;
        data['siteId'] = siteId;
        data['siteName'] = data['siteName'] ?? data['sitename'] ?? siteId;
        data['ownerName'] = data['ownerName'] ?? data['ownername'] ?? data['clientName'] ?? '';
        data['ownerPhoneNumber'] = data['ownerPhoneNumber'] ?? data['ownerPhone'] ?? data['phone'] ?? '';
        data['projectBudget'] = data['projectBudget'] ?? data['budget'] ?? 0;
        data['amountPaid'] = data['amountPaid'] ?? data['paid'] ?? 0;
        data['amountSpent'] = data['amountSpent'] ?? data['spent'] ?? 0;
        data['amountBalance'] = data['amountBalance'] ?? data['balance'] ?? 0;
        data['currentStatus'] = data['currentStatus'] ?? data['status'] ?? 'OnProgress';
        unified[siteId] = data;
      }
    }

    // 2. Ingest & overlay projects collection docs
    for (var doc in projectDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      final siteId = (data['siteId'] ?? data['siteid'] ?? data['site'] ?? doc.id).toString().trim();
      final siteName = (data['siteName'] ?? data['sitename'] ?? data['projectName'] ?? '').toString().trim();

      String matchKey = siteId;
      if (!unified.containsKey(matchKey) && siteName.isNotEmpty) {
        for (var existingKey in unified.keys) {
          final existingName = (unified[existingKey]?['siteName'] ?? '').toString().trim();
          if (existingName.isNotEmpty && existingName.toLowerCase() == siteName.toLowerCase()) {
            matchKey = existingKey;
            break;
          }
        }
      }

      if (unified.containsKey(matchKey)) {
        final existing = unified[matchKey]!;
        for (var entry in data.entries) {
          if (entry.value != null && entry.value.toString().isNotEmpty) {
            existing[entry.key] = entry.value;
          }
        }
        unified[matchKey] = existing;
      } else {
        data['docId'] = doc.id;
        data['siteId'] = siteId;
        data['siteName'] = siteName.isNotEmpty ? siteName : siteId;
        data['ownerName'] = data['ownerName'] ?? data['ownername'] ?? data['clientName'] ?? '';
        data['ownerPhoneNumber'] = data['ownerPhoneNumber'] ?? data['ownerPhone'] ?? data['phone'] ?? '';
        data['projectBudget'] = data['projectBudget'] ?? data['budget'] ?? 0;
        data['amountPaid'] = data['amountPaid'] ?? data['paid'] ?? 0;
        data['amountSpent'] = data['amountSpent'] ?? data['spent'] ?? 0;
        data['amountBalance'] = data['amountBalance'] ?? data['balance'] ?? 0;
        data['currentStatus'] = data['currentStatus'] ?? data['status'] ?? 'OnProgress';
        unified[siteId] = data;
      }
    }

    // 3. Ingest siteSupervisorMap
    for (var doc in supervisorDocs) {
      final data = doc.data();
      final siteId = (data['siteId'] ?? data['siteid'] ?? doc.id).toString().trim();
      final supervisorName = (data['supervisorName'] ?? data['supervisor'] ?? data['name'] ?? '').toString().trim();

      if (supervisorName.isNotEmpty) {
        if (unified.containsKey(siteId)) {
          unified[siteId]!['supervisorName'] = supervisorName;
        } else {
          for (var k in unified.keys) {
            final sName = (unified[k]?['siteName'] ?? '').toString().trim();
            if (sName.isNotEmpty && sName.toLowerCase() == siteId.toLowerCase()) {
              unified[k]!['supervisorName'] = supervisorName;
              break;
            }
          }
        }
      }
    }

    return unified;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final dynamicGradientColors =
            AppTheme.getBackgroundGradientColors(primaryColor);

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dynamicGradientColors,
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              bottomNavigationBar: const BottomNav(currentIndex: 2),
              appBar: _buildAppBar(context, primaryColor, darkAccent),
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Responsive.maxContentWidth,
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.getCollection('Site').snapshots(),
                      builder: (context, siteSnap) {
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirestoreService.getCollection('projects').snapshots(),
                          builder: (context, projSnap) {
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
                              builder: (context, mapSnap) {
                                final siteDocs = siteSnap.hasData
                                    ? siteSnap.data!.docs
                                    : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                final projDocs = projSnap.hasData
                                    ? projSnap.data!.docs
                                    : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                final supDocs = mapSnap.hasData
                                    ? mapSnap.data!.docs
                                    : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                final allSitesMap = _buildUnifiedSiteDocs(
                                  siteDocs: siteDocs,
                                  projectDocs: projDocs,
                                  supervisorDocs: supDocs,
                                );

                                return _buildFinanceBody(
                                  context,
                                  allSitesMap,
                                  primaryColor,
                                  darkAccent,
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
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, darkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Financial Overview',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded, color: Colors.white, size: 22),
          tooltip: 'Sort Sites',
          onSelected: (val) => setState(() => _sortBy = val),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Default', child: Text('Default Order')),
            const PopupMenuItem(value: 'Income', child: Text('Highest Income')),
            const PopupMenuItem(value: 'Expenses', child: Text('Highest Expenses')),
            const PopupMenuItem(value: 'Budget', child: Text('Highest Budget')),
            const PopupMenuItem(value: 'Name', child: Text('Site Name (A-Z)')),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildFinanceBody(
    BuildContext context,
    Map<String, Map<String, dynamic>> allSitesMap,
    Color primaryColor,
    Color darkAccent,
  ) {
    final hPad = Responsive.horizontalPadding(context);

    // Compute Global Metrics
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    int liveSitesCount = 0;
    int completedSitesCount = 0;
    int planningSitesCount = 0;

    for (var site in allSitesMap.values) {
      final inc = _parseNum(site['amountPaid'] ?? site['paid']);
      final exp = _parseNum(site['amountSpent'] ?? site['spent']);

      totalIncome += inc;
      totalExpenses += exp;

      final s = (site['currentStatus'] ?? site['status'] ?? 'Live')
          .toString()
          .trim()
          .toLowerCase();
      if (s.contains('complete') || s.contains('finish') || s.contains('done')) {
        completedSitesCount++;
      } else if (s.contains('plan') || s.contains('draft') || s.contains('setup')) {
        planningSitesCount++;
      } else {
        liveSitesCount++;
      }
    }

    final netProfit = totalIncome - totalExpenses;

    // Filter Sites
    final filteredList = allSitesMap.values.where((site) {
      final siteName = (site['siteName'] ?? '').toString().toLowerCase();
      final projectName = (site['projectName'] ?? '').toString().toLowerCase();
      final ownerName = (site['ownerName'] ?? '').toString().toLowerCase();
      final siteId = (site['siteId'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = q.isEmpty ||
          siteName.contains(q) ||
          projectName.contains(q) ||
          ownerName.contains(q) ||
          siteId.contains(q);

      if (!matchesQuery) return false;

      final s = (site['currentStatus'] ?? site['status'] ?? 'Live')
          .toString()
          .trim()
          .toLowerCase();

      if (_selectedStatusTab == 'Live' || _selectedStatusTab == 'In Progress') {
        return !s.contains('complete') && !s.contains('finish') && !s.contains('done') && !s.contains('plan');
      } else if (_selectedStatusTab == 'Planning') {
        return s.contains('plan') || s.contains('draft') || s.contains('setup');
      } else if (_selectedStatusTab == 'Completed') {
        return s.contains('complete') || s.contains('finish') || s.contains('done');
      }
      return true;
    }).toList();

    // Sort Sites
    if (_sortBy == 'Income') {
      filteredList.sort((a, b) => _parseNum(b['amountPaid'] ?? b['paid']).compareTo(_parseNum(a['amountPaid'] ?? a['paid'])));
    } else if (_sortBy == 'Expenses') {
      filteredList.sort((a, b) => _parseNum(b['amountSpent'] ?? b['spent']).compareTo(_parseNum(a['amountSpent'] ?? a['spent'])));
    } else if (_sortBy == 'Budget') {
      filteredList.sort((a, b) => _parseNum(b['projectBudget'] ?? b['budget']).compareTo(_parseNum(a['projectBudget'] ?? a['budget'])));
    } else if (_sortBy == 'Name') {
      filteredList.sort((a, b) => (a['siteName'] ?? '').toString().compareTo((b['siteName'] ?? '').toString()));
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // 1. Top Financial Overview Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 14),
            child: _buildFinancialOverviewCard(
              totalIncome: totalIncome,
              totalExpenses: totalExpenses,
              netProfit: netProfit,
              liveSitesCount: liveSitesCount,
              completedSitesCount: completedSitesCount,
              planningSitesCount: planningSitesCount,
              primaryColor: primaryColor,
              darkAccent: darkAccent,
            ),
          ),
        ),

        // 2. Search & Filter Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search site, project, or client...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _statusTabs.map((tab) {
                      final isSelected = _selectedStatusTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tab),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedStatusTab = tab);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Section Title: "Sites Financial Breakdown"
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sites Financial Breakdown',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${filteredList.length} ${filteredList.length == 1 ? 'Site' : 'Sites'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Sites Financial Cards List
        if (filteredList.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 40),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 52,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No sites found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Try adjusting your search query or status filter.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final site = filteredList[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSiteFinancialCard(
                      context,
                      site,
                      primaryColor,
                    ),
                  );
                },
                childCount: filteredList.length,
              ),
            ),
          ),
      ],
    );
  }

  // -------------------- TOP FINANCIAL OVERVIEW CARD --------------------
  Widget _buildFinancialOverviewCard({
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
    required int liveSitesCount,
    required int completedSitesCount,
    required int planningSitesCount,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            darkAccent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header Title & Live Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Total Organization Finance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record_rounded,
                      size: 8,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Live Backend Data',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: Total Income & Total Expenses Big KPIs
          Row(
            children: [
              // Total Income
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Total Income',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹ ${_formatCurrency(totalIncome)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Total Expenses
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Total Expenses',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹ ${_formatCurrency(totalExpenses)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: Site Counts Row (Live, Completed, Planning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountIndicator(
                  label: 'Live Sites',
                  count: liveSitesCount < 10 ? '0$liveSitesCount' : '$liveSitesCount',
                  color: const Color(0xFF38BDF8),
                  icon: Icons.domain_rounded,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _buildCountIndicator(
                  label: 'Completed',
                  count: completedSitesCount < 10 ? '0$completedSitesCount' : '$completedSitesCount',
                  color: const Color(0xFF34D399),
                  icon: Icons.check_circle_rounded,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _buildCountIndicator(
                  label: 'Planning',
                  count: planningSitesCount < 10 ? '0$planningSitesCount' : '$planningSitesCount',
                  color: const Color(0xFFA78BFA),
                  icon: Icons.architecture_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountIndicator({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------- SITE FINANCIAL CARD --------------------
  Widget _buildSiteFinancialCard(
    BuildContext context,
    Map<String, dynamic> site,
    Color primaryColor,
  ) {
    final siteId = (site['siteId'] ?? '').toString();
    final siteName = (site['siteName'] ?? siteId).toString();
    final projectName = (site['projectName'] ?? siteName).toString();
    final category = (site['projectCategory'] ?? 'House').toString();
    final subCategory = (site['projectSubCategory'] ?? '2BHK').toString();
    final ownerName = (site['ownerName'] ?? '').toString();
    final ownerPhone = (site['ownerPhoneNumber'] ?? '').toString();
    final status = (site['currentStatus'] ?? site['status'] ?? 'Live').toString();
    final statusColor = _getStatusColor(status);

    final budget = _parseNum(site['projectBudget'] ?? site['budget']);
    final income = _parseNum(site['amountPaid'] ?? site['paid']);
    final expenses = _parseNum(site['amountSpent'] ?? site['spent']);
    final balance = _parseNum(site['amountBalance'] ?? site['balance']);

    final usageRatio = budget > 0 ? (expenses / budget).clamp(0.0, 1.0) : 0.0;
    final usagePercent = (usageRatio * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SiteFinancialDetailsPage(
                  siteId: siteId,
                  siteName: siteName,
                  projectName: projectName,
                  ownerName: ownerName,
                  initialData: site,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Site / Project Name & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                siteName,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (projectName.isNotEmpty && projectName != siteName) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    projectName,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$category • $subCategory ${ownerName.isNotEmpty ? '• Owner: $ownerName${ownerPhone.isNotEmpty ? ' ($ownerPhone)' : ''}' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // 4 Financial Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Budget',
                        amount: '₹ ${_formatCurrency(budget)}',
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Income',
                        amount: '₹ ${_formatCurrency(income)}',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Expenses',
                        amount: '₹ ${_formatCurrency(expenses)}',
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Balance',
                        amount: '₹ ${_formatCurrency(balance)}',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Budget Usage Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: usageRatio,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            usageRatio > 0.85
                                ? const Color(0xFFEF4444)
                                : primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$usagePercent% spent',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
