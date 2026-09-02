import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';
import 'package:demo_cst/screens/organization/org_site_payment_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';

class OrgSitesListPage extends StatefulWidget {
  final String initialFilter;

  const OrgSitesListPage({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<OrgSitesListPage> createState() => _OrgSitesListPageState();
}

class _OrgSitesListPageState extends State<OrgSitesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _selectedStatus;
  String _searchQuery = '';
  String _sortBy = 'Default'; // 'Default', 'Name', 'Budget', 'Progress'

  final List<String> _statusTabs = [
    'All',
    'Live',
    'In Progress',
    'Planning',
    'Completed',
    'On Hold',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialFilter;
    if (!_statusTabs.any((t) => t.toLowerCase() == _selectedStatus.toLowerCase())) {
      _selectedStatus = 'All';
    } else {
      _selectedStatus = _statusTabs.firstWhere(
        (t) => t.toLowerCase() == _selectedStatus.toLowerCase(),
        orElse: () => 'All',
      );
    }
  }

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

  void _showSortFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sort & Filter Sites',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    const SizedBox(height: 8),
                    const Text(
                      'SORT BY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Default', 'Name', 'Budget', 'Progress'].map((option) {
                        final isSelected = _sortBy == option;
                        return ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _sortBy = option);
                              setModalState(() {});
                              Navigator.pop(context);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final dynamicGradientColors = AppTheme.getBackgroundGradientColors(primaryColor);
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Container(
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
            bottomNavigationBar: const BottomNav(currentIndex: 1),
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Header (Back Arrow + "Sites" Title + "+ Add Site" Action)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (Navigator.canPop(context))
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                const Text(
                                  'Sites',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            // "+ Add Site" Header Action Button
                            InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProjectSetupWizard(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryColor, darkAccent],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add Site',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Search Bar and Filter Option Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Search TextField Container
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
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
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search sites by name, ID, status...',
                                    hintStyle: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Filter Button
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showSortFilterBottomSheet();
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _sortBy != 'Default'
                                        ? primaryColor
                                        : const Color(0xFFE2E8F0),
                                    width: _sortBy != 'Default' ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: _sortBy != 'Default'
                                        ? primaryColor
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Status Tabs (All, Planning, In Progress, On Hold)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: _statusTabs.map((status) {
                            final isSelected = _selectedStatus.toLowerCase() ==
                                status.toLowerCase();

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _selectedStatus = status);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [primaryColor, darkAccent],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isSelected
                                        ? null
                                        : Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // 4. Scrollable List of Site Cards
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirestoreService.projects.snapshots(),
                          builder: (context, projSnap) {
                            if (projSnap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final rawDocs = projSnap.hasData ? projSnap.data!.docs : [];

                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
                              builder: (context, mapSnap) {
                                final supervisorMap = <String, String>{};
                                if (mapSnap.hasData) {
                                  for (var d in mapSnap.data!.docs) {
                                    final data = d.data();
                                    final sName = data['supervisor'] ?? data['supervisorName'];
                                    final sId = data['siteId'] ?? data['site'];
                                    if (sId != null && sName != null) {
                                      supervisorMap[sId.toString()] = sName.toString();
                                    }
                                  }
                                }

                                // Filter by Search Query & Selected Status Tab
                                final q = _searchQuery.trim().toLowerCase();
                                final filteredDocs = rawDocs.where((doc) {
                                  final data = doc.data();
                                  final name = (data['siteName'] ?? data['projectName'] ?? '').toString();
                                  final siteId = (data['siteId'] ?? doc.id).toString();
                                  final projectType = (data['projectType'] ?? data['projectCategory'] ?? data['projectSubCategory'] ?? '').toString();
                                  final supervisor = (data['supervisor'] ?? data['supervisorName'] ?? supervisorMap[siteId] ?? '').toString();
                                  final status = (data['currentStatus'] ?? data['status'] ?? 'Ongoing').toString();

                                  // Search Query match
                                  final matchesQuery = q.isEmpty ||
                                      name.toLowerCase().contains(q) ||
                                      siteId.toLowerCase().contains(q) ||
                                      projectType.toLowerCase().contains(q) ||
                                      supervisor.toLowerCase().contains(q) ||
                                      status.toLowerCase().contains(q);

                                  // Status Tab match
                                  bool matchesStatus = true;
                                  final statusLower = status.toLowerCase();
                                  if (_selectedStatus == 'Planning') {
                                    matchesStatus = statusLower.contains('plan') ||
                                        statusLower.contains('draft') ||
                                        statusLower.contains('setup') ||
                                        statusLower.contains('upcoming');
                                  } else if (_selectedStatus == 'In Progress') {
                                    matchesStatus = statusLower.contains('progress') ||
                                        statusLower.contains('ongoing') ||
                                        statusLower.contains('active') ||
                                        statusLower.contains('execution');
                                  } else if (_selectedStatus == 'On Hold') {
                                    matchesStatus = statusLower.contains('hold') ||
                                        statusLower.contains('delay') ||
                                        statusLower.contains('overdue') ||
                                        statusLower.contains('pause') ||
                                        statusLower.contains('suspend');
                                  }

                                  return matchesQuery && matchesStatus;
                                }).toList();

                                // Apply Sorting
                                if (_sortBy == 'Name') {
                                  filteredDocs.sort((a, b) {
                                    final aName = (a.data()['siteName'] ?? a.data()['projectName'] ?? '').toString().toLowerCase();
                                    final bName = (b.data()['siteName'] ?? b.data()['projectName'] ?? '').toString().toLowerCase();
                                    return aName.compareTo(bName);
                                  });
                                } else if (_sortBy == 'Budget') {
                                  filteredDocs.sort((a, b) {
                                    final aB = (a.data()['projectBudget'] is num ? (a.data()['projectBudget'] as num).toDouble() : 0.0);
                                    final bB = (b.data()['projectBudget'] is num ? (b.data()['projectBudget'] as num).toDouble() : 0.0);
                                    return bB.compareTo(aB); // Descending
                                  });
                                } else if (_sortBy == 'Progress') {
                                  filteredDocs.sort((a, b) {
                                    final aP = _calculateProgress(a.data());
                                    final bP = _calculateProgress(b.data());
                                    return bP.compareTo(aP); // Descending
                                  });
                                }

                                if (filteredDocs.isEmpty) {
                                  return Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.domain_disabled_rounded,
                                              size: 48,
                                              color: primaryColor.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No Sites Found',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No projects matching "$_searchQuery"'
                                                : 'No projects available under $_selectedStatus.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 90),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 95),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = filteredDocs[index];
                                    final data = doc.data();
                                    final siteDocId = doc.id;

                                    return _buildSiteCard(
                                      context: context,
                                      data: data,
                                      siteDocId: siteDocId,
                                      supervisorMap: supervisorMap,
                                      primaryColor: primaryColor,
                                      darkAccent: darkAccent,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateProgress(Map<String, dynamic> data) {
    if (data['progress'] is num) {
      return (data['progress'] as num).toDouble();
    }
    final budget = (data['projectBudget'] is num ? (data['projectBudget'] as num).toDouble() : 0.0);
    final spent = (data['amountSpent'] is num ? (data['amountSpent'] as num).toDouble() : 0.0);
    if (budget > 0) {
      final p = (spent / budget) * 100;
      return p > 100 ? 100.0 : p;
    }
    final status = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    if (status.contains('complete')) return 100.0;
    if (status.contains('progress') || status.contains('ongoing')) return 45.0;
    if (status.contains('plan')) return 10.0;
    return 0.0;
  }

  Widget _buildSiteCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String siteDocId,
    required Map<String, String> supervisorMap,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    final siteName = (data['siteName'] ?? data['projectName'] ?? 'Unnamed Site').toString();
    final siteId = (data['siteId'] ?? siteDocId).toString();
    final projectType = (data['projectType'] ??
            data['projectCategory'] ??
            data['projectSubCategory'] ??
            'General Project')
        .toString();

    final supervisor = (data['supervisor'] ??
            data['supervisorName'] ??
            data['ownerName'] ??
            supervisorMap[siteId] ??
            'Not Assigned')
        .toString();

    final rawStatus = (data['currentStatus'] ?? data['status'] ?? 'Ongoing').toString();
    final statusBadge = _getStatusBadge(rawStatus);

    final budget = (data['projectBudget'] is num ? (data['projectBudget'] as num).toDouble() : 0.0);
    final balance = (data['amountBalance'] is num ? (data['amountBalance'] as num).toDouble() : budget);
    final progress = _calculateProgress(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SitePaymentScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Site Name + Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            siteName,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            siteId,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBadge.bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusBadge.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: statusBadge.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Project & Supervisor Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.category_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            projectType,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                supervisor,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stage Progress',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${progress.round()}%',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 100
                          ? const Color(0xFF16A34A)
                          : primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Row: Budget & Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget: ₹ ${_formatCurrency(budget)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Balance: ₹ ${_formatCurrency(balance)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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

  _StatusBadgeData _getStatusBadge(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing') || s.contains('active')) {
      return _StatusBadgeData(
        label: 'In Progress',
        bgColor: const Color(0xFFDCFCE7),
        textColor: const Color(0xFF16A34A),
      );
    } else if (s.contains('plan') || s.contains('draft') || s.contains('setup')) {
      return _StatusBadgeData(
        label: 'Planning',
        bgColor: const Color(0xFFFEF3C7),
        textColor: const Color(0xFFD97706),
      );
    } else if (s.contains('hold') || s.contains('delay') || s.contains('overdue')) {
      return _StatusBadgeData(
        label: 'On Hold',
        bgColor: const Color(0xFFEDE9FE),
        textColor: const Color(0xFF7C3AED),
      );
    } else if (s.contains('complete') || s.contains('finish')) {
      return _StatusBadgeData(
        label: 'Completed',
        bgColor: const Color(0xFFDBEAFE),
        textColor: const Color(0xFF2563EB),
      );
    }
    return _StatusBadgeData(
      label: rawStatus.isNotEmpty ? rawStatus : 'Planning',
      bgColor: const Color(0xFFFEF3C7),
      textColor: const Color(0xFFD97706),
    );
  }

}

class _StatusBadgeData {
  final String label;
  final Color bgColor;
  final Color textColor;

  _StatusBadgeData({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}
