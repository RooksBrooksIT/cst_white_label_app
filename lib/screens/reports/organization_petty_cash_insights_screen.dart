import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../utils/app_theme.dart';
import '../organization/petty_cash_report_pdf_helper.dart';

class OrganizationPettyCashInsightsScreen extends StatefulWidget {
  const OrganizationPettyCashInsightsScreen({super.key});

  @override
  State<OrganizationPettyCashInsightsScreen> createState() =>
      _OrganizationPettyCashInsightsScreenState();
}

class _OrganizationPettyCashInsightsScreenState
    extends State<OrganizationPettyCashInsightsScreen> {
  final PettyCashService _pettyCashService = PettyCashService();

  // Time filters
  String _timeFilter = 'All Time'; // 'All Time', 'Today', 'This Month', 'Custom Range'
  DateTime? _fromDate;
  DateTime? _toDate;

  // Dimension filters
  String _selectedSite = 'All Sites';
  String _selectedProject = 'All Projects';
  String _selectedSupervisor = 'All Supervisors';
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setTimeFilter(String filter) {
    setState(() {
      _timeFilter = filter;
      final now = DateTime.now();
      if (filter == 'Today') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filter == 'This Month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (filter == 'All Time') {
        _fromDate = null;
        _toDate = null;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeFilter = 'Custom Range';
        _fromDate = picked.start;
        _toDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Petty Cash Insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
        actions: [
          IconButton(
            tooltip: 'Export PDF Report',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            onPressed: () => _exportPdf(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000.0 : (isTablet ? 750.0 : double.infinity),
            ),
            child: StreamBuilder<List<PettyCashRequest>>(
              stream: _pettyCashService.streamAllRequests(),
              builder: (context, reqSnap) {
                return StreamBuilder<List<PettyCashTransaction>>(
                  stream: _pettyCashService.streamAllTransactions(),
                  builder: (context, txnSnap) {
                    if (reqSnap.connectionState == ConnectionState.waiting &&
                        !reqSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allRequests = reqSnap.data ?? [];
                    final allTransactions = txnSnap.data ?? [];

                    // Calculate Site-Wise Summaries
                    final siteSummaries = _pettyCashService.calculateSiteWiseSummaries(
                      requests: allRequests,
                      transactions: allTransactions,
                      siteFilter: _selectedSite != 'All Sites' ? _selectedSite : null,
                      supervisorFilter: _selectedSupervisor != 'All Supervisors'
                          ? _selectedSupervisor
                          : null,
                      projectFilter:
                          _selectedProject != 'All Projects' ? _selectedProject : null,
                      categoryFilter:
                          _selectedCategory != 'All Categories' ? _selectedCategory : null,
                      fromDate: _fromDate,
                      toDate: _toDate,
                    );

                    // Dynamic filter lists
                    final siteOptions = {'All Sites'};
                    final projectOptions = {'All Projects'};
                    final supervisorOptions = {'All Supervisors'};
                    final categoryOptions = {'All Categories'};

                    for (final r in allRequests) {
                      if (r.siteName != null && r.siteName!.isNotEmpty) {
                        siteOptions.add(r.siteName!);
                      }
                      if (r.projectName != null && r.projectName!.isNotEmpty) {
                        projectOptions.add(r.projectName!);
                      }
                      if (r.supervisorName.isNotEmpty) {
                        supervisorOptions.add(r.supervisorName);
                      }
                    }

                    for (final t in allTransactions) {
                      if (t.siteName != null && t.siteName!.isNotEmpty) {
                        siteOptions.add(t.siteName!);
                      }
                      if (t.projectName != null && t.projectName!.isNotEmpty) {
                        projectOptions.add(t.projectName!);
                      }
                      if (t.supervisorName.isNotEmpty) {
                        supervisorOptions.add(t.supervisorName);
                      }
                      if (t.expenseCategory.isNotEmpty) {
                        categoryOptions.add(t.expenseCategory);
                      }
                    }

                    // Apply Search Query Filter on summaries
                    final filteredSummaries = siteSummaries.where((s) {
                      if (_searchQuery.isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      return s.siteName.toLowerCase().contains(q) ||
                          s.siteId.toLowerCase().contains(q);
                    }).toList();

                    // Overall Aggregated Totals
                    double totalReceived = 0;
                    double totalExpenses = 0;
                    double totalOtherExpenses = 0;
                    for (final s in filteredSummaries) {
                      totalReceived += s.totalReceived;
                      totalExpenses += s.totalExpenses;
                      totalOtherExpenses += s.otherExpenses;
                    }
                    final netRemaining = totalReceived - totalExpenses;

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          32,
                        ),
                        children: [
                          // Header banner
                          _buildHeaderBanner(
                            totalSites: filteredSummaries.length,
                            totalAllocations: filteredSummaries.fold(
                              0,
                              (prev, s) => prev + s.allocations.length,
                            ),
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 16),

                          // Time Filter Controls
                          _buildTimeFilterBar(primaryColor),
                          const SizedBox(height: 12),

                          // Search & Dimension Filters
                          _buildDimensionFilters(
                            siteOptions.toList()..sort(),
                            projectOptions.toList()..sort(),
                            supervisorOptions.toList()..sort(),
                            categoryOptions.toList()..sort(),
                            primaryColor,
                          ),
                          const SizedBox(height: 16),

                          // Executive KPI Cards
                          _buildExecutiveKpiCards(
                            totalReceived: totalReceived,
                            totalExpenses: totalExpenses,
                            totalOtherExpenses: totalOtherExpenses,
                            netRemaining: netRemaining,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 20),

                          // Section Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Site-Wise Petty Cash Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Showing ${filteredSummaries.length} tracked site(s)',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (_timeFilter != 'All Time')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _timeFilter == 'Custom Range' &&
                                            _fromDate != null &&
                                            _toDate != null
                                        ? '${DateFormat('d MMM').format(_fromDate!)} - ${DateFormat('d MMM').format(_toDate!)}'
                                        : _timeFilter,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Site Cards List
                          if (filteredSummaries.isEmpty)
                            _buildEmptyState()
                          else
                            ...filteredSummaries.map(
                              (s) => _buildSiteInsightCard(
                                s,
                                primaryColor,
                                allTransactions,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Supervisor-Wise Breakdown
                          _buildSupervisorWiseSection(
                            allRequests: allRequests,
                            allTransactions: allTransactions,
                            primaryColor: primaryColor,
                          ),

                          const SizedBox(height: 24),

                          // Category & Other Expenses Breakdown
                          _buildCategoryBreakdownSection(
                            allTransactions: allTransactions,
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Header Banner
  Widget _buildHeaderBanner({
    required int totalSites,
    required int totalAllocations,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.query_stats_rounded, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site Petty Cash Tracking',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Real-time site balances, verified receipts, and Other expenses tracking',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Time Filter Bar
  Widget _buildTimeFilterBar(Color primaryColor) {
    final filters = ['All Time', 'Today', 'This Month', 'Custom Range'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _timeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f == 'Custom Range' &&
                        isSelected &&
                        _fromDate != null &&
                        _toDate != null
                    ? '${DateFormat('dd/MM').format(_fromDate!)} - ${DateFormat('dd/MM').format(_toDate!)}'
                    : f,
              ),
              selected: isSelected,
              onSelected: (val) {
                if (f == 'Custom Range') {
                  _pickCustomDateRange();
                } else {
                  _setTimeFilter(f);
                }
              },
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Dimension Filters & Search Box
  Widget _buildDimensionFilters(
    List<String> siteOptions,
    List<String> projectOptions,
    List<String> supervisorOptions,
    List<String> categoryOptions,
    Color primaryColor,
  ) {
    return Column(
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          decoration: InputDecoration(
            hintText: 'Search site name or site ID...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
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
        const SizedBox(height: 8),

        // Dropdown Filters Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Site Dropdown
              _buildDropdownFilter(
                value: _selectedSite,
                options: siteOptions,
                icon: Icons.location_on_outlined,
                onChanged: (val) => setState(() => _selectedSite = val ?? 'All Sites'),
              ),
              const SizedBox(width: 8),

              // Project Dropdown
              _buildDropdownFilter(
                value: _selectedProject,
                options: projectOptions,
                icon: Icons.business_rounded,
                onChanged: (val) => setState(() => _selectedProject = val ?? 'All Projects'),
              ),
              const SizedBox(width: 8),

              // Supervisor Dropdown
              _buildDropdownFilter(
                value: _selectedSupervisor,
                options: supervisorOptions,
                icon: Icons.person_outline_rounded,
                onChanged: (val) =>
                    setState(() => _selectedSupervisor = val ?? 'All Supervisors'),
              ),
              const SizedBox(width: 8),

              // Category Dropdown
              _buildDropdownFilter(
                value: _selectedCategory,
                options: categoryOptions,
                icon: Icons.category_outlined,
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? 'All Categories'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> options,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = options.contains(value) ? value : options.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: effectiveValue != options.first
              ? const Color(0xFF2563EB)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: effectiveValue != options.first
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: effectiveValue,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.arrow_drop_down, size: 18),
            style: TextStyle(
              fontSize: 12,
              fontWeight: effectiveValue != options.first
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: effectiveValue != options.first
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF334155),
            ),
            items: options.map((opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(
                  opt.length > 22 ? '${opt.substring(0, 20)}...' : opt,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Executive KPI Cards
  Widget _buildExecutiveKpiCards({
    required double totalReceived,
    required double totalExpenses,
    required double totalOtherExpenses,
    required double netRemaining,
    required Color primaryColor,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Received',
                amount: PettyCashService.formatCurrency(totalReceived),
                subtitle: 'From Approved Petty Cash',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Expenses',
                amount: PettyCashService.formatCurrency(totalExpenses),
                subtitle: 'All Recorded Spends',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Other / Misc Expenses',
                amount: PettyCashService.formatCurrency(totalOtherExpenses),
                subtitle: 'Linked to Sites',
                icon: Icons.more_horiz_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Net Remaining',
                amount: PettyCashService.formatCurrency(netRemaining),
                subtitle: 'Received − Expenses',
                icon: Icons.savings_rounded,
                iconColor: netRemaining >= 0
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFEF4444),
                bgColor: netRemaining >= 0
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: iconColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Site Insight Card
  Widget _buildSiteInsightCard(
    SitePettyCashSummary summary,
    Color primaryColor,
    List<PettyCashTransaction> allTransactions,
  ) {
    final double percentSpent = summary.totalReceived > 0
        ? (summary.totalExpenses / summary.totalReceived).clamp(0.0, 1.0)
        : (summary.totalExpenses > 0 ? 1.0 : 0.0);

    final Color statusColor;
    final String statusLabel;
    if (summary.remainingBalance < 0) {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Overspent';
    } else if (summary.remainingBalance == 0 && summary.totalReceived > 0) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Fully Spent';
    } else if (summary.remainingBalance < 1000 && summary.totalReceived > 0) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Low Balance';
    } else {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Healthy';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.siteName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ID: ${summary.siteId}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (summary.allocations.isNotEmpty &&
                              summary.allocations.first.supervisorName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '•  ${summary.allocations.first.supervisorName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Metrics breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol(
                      label: 'Received',
                      amount: PettyCashService.formatCurrency(summary.totalReceived),
                      color: const Color(0xFF059669),
                    ),
                    _buildStatCol(
                      label: 'Spent',
                      amount: PettyCashService.formatCurrency(summary.totalExpenses),
                      color: const Color(0xFFDC2626),
                    ),
                    _buildStatCol(
                      label: 'Other Exp.',
                      amount: PettyCashService.formatCurrency(summary.otherExpenses),
                      color: const Color(0xFFD97706),
                    ),
                    _buildStatCol(
                      label: 'Remaining',
                      amount: PettyCashService.formatCurrency(summary.remainingBalance),
                      color: summary.remainingBalance >= 0
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFDC2626),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Utilization Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Petty Cash Spent',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(percentSpent * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: percentSpent > 0.9
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percentSpent,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentSpent >= 1.0
                              ? const Color(0xFFDC2626)
                              : (percentSpent > 0.8
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // View Site Ledger & Drill-down button
                InkWell(
                  onTap: () => _openSiteDetailModal(summary, allTransactions),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_rounded,
                          size: 15,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Site Ledger & Receipts (${summary.transactions.length} items)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol({
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
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // Drill-down Site Ledger Bottom Sheet Modal
  void _openSiteDetailModal(
    SitePettyCashSummary summary,
    List<PettyCashTransaction> allTransactions,
  ) {
    // Filter transactions for this site and timeframe
    final siteTxns = summary.transactions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.siteName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Site ID: ${summary.siteId} • Ledger & Expenses',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Modal Content List
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Site Summary Bar
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildModalKpi(
                                'Received',
                                PettyCashService.formatCurrency(summary.totalReceived),
                                const Color(0xFF059669),
                              ),
                              _buildModalKpi(
                                'Spent',
                                PettyCashService.formatCurrency(summary.totalExpenses),
                                const Color(0xFFDC2626),
                              ),
                              _buildModalKpi(
                                'Other Exp.',
                                PettyCashService.formatCurrency(summary.otherExpenses),
                                const Color(0xFFD97706),
                              ),
                              _buildModalKpi(
                                'Balance',
                                PettyCashService.formatCurrency(summary.remainingBalance),
                                summary.remainingBalance >= 0
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDC2626),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section: Site Transactions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Expense Items & Receipts',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${siteTxns.length} record(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (siteTxns.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Text(
                              'No expense transactions recorded for this site in the selected period.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...siteTxns.map((t) => _buildTransactionDetailItem(t)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalKpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetailItem(PettyCashTransaction txn) {
    final isOther = txn.expenseCategory.toLowerCase().contains('other') ||
        txn.expenseCategory.toLowerCase().contains('misc');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOther ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOther
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOther)
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Color(0xFFD97706),
                      ),
                    if (isOther) const SizedBox(width: 4),
                    Text(
                      txn.expenseCategory,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOther
                            ? const Color(0xFFB45309)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Expense amount
              Text(
                PettyCashService.formatCurrency(txn.amount),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description & Vendor
          Text(
            txn.description.isNotEmpty ? txn.description : 'No description provided',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 6),

          // Meta info: Supervisor, Vendor, Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'By: ${txn.supervisorName}${txn.vendorName != null ? ' • Vendor: ${txn.vendorName}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(txn.transactionDate),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Supervisor-Wise Section
  Widget _buildSupervisorWiseSection({
    required List<PettyCashRequest> allRequests,
    required List<PettyCashTransaction> allTransactions,
    required Color primaryColor,
  }) {
    // Map supervisors
    final Map<String, _SupervisorBreakdown> supMap = {};

    for (final r in allRequests) {
      if (r.supervisorId.isEmpty) continue;
      final isReceived = r.isReceived || r.receivedAt != null || r.status == 'received';
      if (!isReceived) continue;

      final amount = r.approvedAmount > 0
          ? r.approvedAmount
          : (r.allocatedAmount > 0 ? r.allocatedAmount : r.requestedAmount);

      final entry = supMap.putIfAbsent(
        r.supervisorId,
        () => _SupervisorBreakdown(
          supervisorId: r.supervisorId,
          supervisorName: r.supervisorName,
        ),
      );
      entry.totalReceived += amount;
      if (r.siteName != null && r.siteName!.isNotEmpty) {
        entry.assignedSites.add(r.siteName!);
      }
    }

    for (final t in allTransactions) {
      if (t.supervisorId.isEmpty) continue;
      final entry = supMap.putIfAbsent(
        t.supervisorId,
        () => _SupervisorBreakdown(
          supervisorId: t.supervisorId,
          supervisorName: t.supervisorName,
        ),
      );
      entry.totalSpent += t.amount;
      if (t.expenseCategory.toLowerCase().contains('other') ||
          t.expenseCategory.toLowerCase().contains('misc')) {
        entry.otherSpent += t.amount;
      }
      if (t.siteName != null && t.siteName!.isNotEmpty) {
        entry.assignedSites.add(t.siteName!);
      }
    }

    final supervisors = supMap.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Supervisor-Wise Petty Cash',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${supervisors.length} Supervisors',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (supervisors.isEmpty)
            const Text(
              'No supervisor petty cash records found.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            )
          else
            ...supervisors.map((sup) {
              final balance = sup.totalReceived - sup.totalSpent;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sup.supervisorName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Bal: ${PettyCashService.formatCurrency(balance)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: balance >= 0
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rec: ${PettyCashService.formatCurrency(sup.totalReceived)}  •  Spent: ${PettyCashService.formatCurrency(sup.totalSpent)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (sup.assignedSites.isNotEmpty)
                          Text(
                            sup.assignedSites.first,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Category & Other Expenses Breakdown
  Widget _buildCategoryBreakdownSection({
    required List<PettyCashTransaction> allTransactions,
    required Color primaryColor,
  }) {
    final Map<String, double> catMap = {};
    double total = 0;

    for (final t in allTransactions) {
      final cat = t.expenseCategory.isNotEmpty ? t.expenseCategory : 'General';
      catMap[cat] = (catMap[cat] ?? 0) + t.amount;
      total += t.amount;
    }

    final sortedEntries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Category Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Detailed distribution including Other & Miscellaneous spends',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (sortedEntries.isEmpty)
            const Text(
              'No expense records found.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            )
          else
            ...sortedEntries.map((e) {
              final pct = total > 0 ? (e.value / total) : 0.0;
              final isOther = e.key.toLowerCase().contains('other') ||
                  e.key.toLowerCase().contains('misc');

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isOther)
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                            if (isOther) const SizedBox(width: 4),
                            Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isOther
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${PettyCashService.formatCurrency(e.value)} (${(pct * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOther
                              ? const Color(0xFFD97706)
                              : primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Site Petty Cash Records Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No petty cash allocations or expenses match your selected filters.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _exportPdf(BuildContext context) {
    PettyCashReportPdfHelper.generateAndDownloadPdf(
      context: context,
      requests: const [],
      primaryColor: Theme.of(context).primaryColor,
    );
  }
}

class _SupervisorBreakdown {
  final String supervisorId;
  final String supervisorName;
  double totalReceived = 0;
  double totalSpent = 0;
  double otherSpent = 0;
  final Set<String> assignedSites = {};

  _SupervisorBreakdown({
    required this.supervisorId,
    required this.supervisorName,
  });
}
