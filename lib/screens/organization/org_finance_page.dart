import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/responsive.dart';
import 'package:ebricks/widgets/bottom_nav.dart';
import 'package:ebricks/screens/organization/site_financial_details_page.dart';

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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> totalsDocs = const [],
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
        data['amountPaid'] = data['amountPaid'] ?? data['paid'] ?? data['amountReceived'] ?? 0;
        data['amountSpent'] = data['amountSpent'] ?? data['amountSpend'] ?? data['spent'] ?? data['totalAllExpenses'] ?? 0;
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
        data['amountPaid'] = data['amountPaid'] ?? data['paid'] ?? data['amountReceived'] ?? 0;
        data['amountSpent'] = data['amountSpent'] ?? data['amountSpend'] ?? data['spent'] ?? data['totalAllExpenses'] ?? 0;
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

    // 4. Ingest & overlay totalSiteExpensesPerDay aggregation docs
    for (var doc in totalsDocs) {
      final data = doc.data();
      final siteId = (data['siteId'] ?? doc.id).toString().trim();
      final siteName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim();

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
        double totalExp = 0.0;
        if (data['totalAllExpenses'] is num) {
          totalExp = (data['totalAllExpenses'] as num).toDouble();
        } else {
          final sExp = _parseNum(data['totalSiteExpense']);
          final mExp = _parseNum(data['totalMgrExpense']);
          final oExp = _parseNum(data['totalOrgExpense']);
          final cExp = _parseNum(data['totalContractorExpense']);
          final iExp = _parseNum(data['totalIncentiveExpenses']);
          totalExp = sExp + mExp + oExp + cExp + iExp;
        }

        final currentSpent = _parseNum(existing['amountSpent'] ?? existing['spent']);
        if (totalExp > 0 || currentSpent == 0) {
          existing['amountSpent'] = totalExp > 0 ? totalExp : currentSpent;
          final budget = _parseNum(existing['projectBudget'] ?? existing['budget']);
          final income = _parseNum(existing['amountPaid'] ?? existing['paid'] ?? existing['amountReceived']);
          final effectiveSpent = existing['amountSpent'] as double;
          existing['amountBalance'] = budget > 0 ? (budget - effectiveSpent) : (income - effectiveSpent);
        }
        unified[matchKey] = existing;
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

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
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
                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirestoreService.getCollection('totalSiteExpensesPerDay').snapshots(),
                                  builder: (context, totalsSnap) {
                                    final siteDocs = siteSnap.hasData
                                        ? siteSnap.data!.docs
                                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                    final projDocs = projSnap.hasData
                                        ? projSnap.data!.docs
                                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                    final supDocs = mapSnap.hasData
                                        ? mapSnap.data!.docs
                                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                    final totalsDocs = totalsSnap.hasData
                                        ? totalsSnap.data!.docs
                                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                    final allSitesMap = _buildUnifiedSiteDocs(
                                      siteDocs: siteDocs,
                                      projectDocs: projDocs,
                                      supervisorDocs: supDocs,
                                      totalsDocs: totalsDocs,
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
                        );
                      },
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
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Financial Overview',
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
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
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
        const SizedBox(width: 4),
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
      final inc = _parseNum(site['amountPaid'] ?? site['paid'] ?? site['amountReceived']);
      final exp = _parseNum(site['amountSpent'] ?? site['amountSpend'] ?? site['spent'] ?? site['totalAllExpenses']);

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
      filteredList.sort((a, b) => _parseNum(b['amountPaid'] ?? b['paid'] ?? b['amountReceived']).compareTo(_parseNum(a['amountPaid'] ?? a['paid'] ?? a['amountReceived'])));
    } else if (_sortBy == 'Expenses') {
      filteredList.sort((a, b) => _parseNum(b['amountSpent'] ?? b['amountSpend'] ?? b['spent'] ?? b['totalAllExpenses']).compareTo(_parseNum(a['amountSpent'] ?? a['amountSpend'] ?? a['spent'] ?? a['totalAllExpenses'])));
    } else if (_sortBy == 'Budget') {
      filteredList.sort((a, b) => _parseNum(b['projectBudget'] ?? b['budget']).compareTo(_parseNum(a['projectBudget'] ?? a['budget'])));
    } else if (_sortBy == 'Name') {
      filteredList.sort((a, b) => (a['siteName'] ?? '').toString().compareTo((b['siteName'] ?? '').toString()));
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // 1. Top Financial Overview Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 12),
            child: _buildFinancialOverviewCard(
              context: context,
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
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
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
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

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
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                Expanded(
                  child: Row(
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
                      const Flexible(
                        child: Text(
                          'Sites Financial Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${filteredList.length} ${filteredList.length == 1 ? 'Site' : 'Sites'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
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
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 38,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No sites found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Try adjusting your search query or status filter.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchQuery.isNotEmpty || _selectedStatusTab != 'All') ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedStatusTab = 'All';
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Reset Filters',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              0,
              hPad,
              kBottomNavigationBarHeight + bottomInset + 24,
            ),
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
    required BuildContext context,
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
    required int liveSitesCount,
    required int completedSitesCount,
    required int planningSitesCount,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    final isSmall = Responsive.isSmallMobile(context);
    final cardPadding = isSmall ? 14.0 : 18.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header Title & Live Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: primaryColor,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total Organization Finance',
                  style: TextStyle(
                    fontSize: isSmall ? 12.5 : 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Live Backend Data',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 12 : 16),

          // Row 2: Total Income & Total Expenses Big KPIs
          Row(
            children: [
              // Total Income
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 12,
                    vertical: isSmall ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 11,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Total Income',
                              style: TextStyle(
                                fontSize: isSmall ? 10.5 : 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹ ${_formatCurrency(totalIncome)}',
                          style: TextStyle(
                            fontSize: isSmall ? 15 : 17,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isSmall ? 8 : 10),

              // Total Expenses
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 12,
                    vertical: isSmall ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 11,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Total Expenses',
                              style: TextStyle(
                                fontSize: isSmall ? 10.5 : 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹ ${_formatCurrency(totalExpenses)}',
                          style: TextStyle(
                            fontSize: isSmall ? 15 : 17,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFDC2626),
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),

          // Row 3: Site Counts Row (Live, Completed, Planning)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 8 : 12,
              vertical: isSmall ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCountIndicator(
                    label: 'Live Sites',
                    count: liveSitesCount < 10 ? '0$liveSitesCount' : '$liveSitesCount',
                    color: const Color(0xFF0284C7),
                    icon: Icons.domain_rounded,
                    isSmall: isSmall,
                  ),
                ),
                Container(
                  width: 1,
                  height: 22,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildCountIndicator(
                    label: 'Completed',
                    count: completedSitesCount < 10 ? '0$completedSitesCount' : '$completedSitesCount',
                    color: const Color(0xFF059669),
                    icon: Icons.check_circle_rounded,
                    isSmall: isSmall,
                  ),
                ),
                Container(
                  width: 1,
                  height: 22,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildCountIndicator(
                    label: 'Planning',
                    count: planningSitesCount < 10 ? '0$planningSitesCount' : '$planningSitesCount',
                    color: const Color(0xFF7C3AED),
                    icon: Icons.architecture_rounded,
                    isSmall: isSmall,
                  ),
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
    required bool isSmall,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isSmall ? 13 : 15, color: color),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- SITE FINANCIAL CARD --------------------
  Widget _buildSiteFinancialCard(
    BuildContext context,
    Map<String, dynamic> site,
    Color primaryColor,
  ) {
    final isSmall = Responsive.isSmallMobile(context);
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
    final income = _parseNum(site['amountPaid'] ?? site['paid'] ?? site['amountReceived']);
    final expenses = _parseNum(site['amountSpent'] ?? site['amountSpend'] ?? site['spent'] ?? site['totalAllExpenses']);
    final rawBalance = _parseNum(site['amountBalance'] ?? site['balance']);
    final balance = rawBalance != 0 ? rawBalance : (budget > 0 ? (budget - expenses) : (income - expenses));

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
            padding: EdgeInsets.all(isSmall ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Site / Project Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  siteName,
                                  style: TextStyle(
                                    fontSize: isSmall ? 14.5 : 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (projectName.isNotEmpty && projectName != siteName) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      projectName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$category • $subCategory ${ownerName.isNotEmpty ? '• Owner: $ownerName${ownerPhone.isNotEmpty ? ' ($ownerPhone)' : ''}' : ''}',
                            style: TextStyle(
                              fontSize: isSmall ? 10.5 : 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: isSmall ? 10 : 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
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
                        isSmall: isSmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Income',
                        amount: '₹ ${_formatCurrency(income)}',
                        color: const Color(0xFF10B981),
                        isSmall: isSmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Expenses',
                        amount: '₹ ${_formatCurrency(expenses)}',
                        color: const Color(0xFFEF4444),
                        isSmall: isSmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Balance',
                        amount: '₹ ${_formatCurrency(balance)}',
                        color: const Color(0xFF8B5CF6),
                        isSmall: isSmall,
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
                      style: TextStyle(
                        fontSize: isSmall ? 9.5 : 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
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
    required bool isSmall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 9.5 : 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
