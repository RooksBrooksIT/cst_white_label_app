import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';
import 'package:demo_cst/screens/organization/org_site_payment_screen.dart';
import 'package:demo_cst/screens/reports/insights_dashboard.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

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

  final List<String> _statusTabs = ['All', 'Planning', 'In Progress', 'On Hold'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialFilter;
    if (!_statusTabs.contains(_selectedStatus)) {
      _selectedStatus = 'All';
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
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFC),
          bottomNavigationBar: _buildBottomNavigationBar(primaryColor),
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
                    // 1. Top Header (Back Arrow + "Sites" Title)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          if (Navigator.canPop(context))
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
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
                                  hintText: 'Search sites...',
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
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 20,
                                  color: _sortBy != 'Default'
                                      ? const Color(0xFF2563EB)
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
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
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

                    // 4. Scrollable List of Site Cards + Fixed Bottom "+ Add Site" Button
                    Expanded(
                      child: Stack(
                        children: [
                          // Real-time Stream of Projects & Sites
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                      final nameA = (a.data()['siteName'] ?? a.data()['projectName'] ?? '').toString();
                                      final nameB = (b.data()['siteName'] ?? b.data()['projectName'] ?? '').toString();
                                      return nameA.compareTo(nameB);
                                    });
                                  } else if (_sortBy == 'Budget') {
                                    filteredDocs.sort((a, b) {
                                      final budgetA = (a.data()['projectBudget'] ?? 0) as num;
                                      final budgetB = (b.data()['projectBudget'] ?? 0) as num;
                                      return budgetB.compareTo(budgetA);
                                    });
                                  } else if (_sortBy == 'Progress') {
                                    filteredDocs.sort((a, b) {
                                      final progA = _calculateProgress(a.data());
                                      final progB = _calculateProgress(b.data());
                                      return progB.compareTo(progA);
                                    });
                                  }

                                  if (filteredDocs.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.domain_disabled_rounded,
                                              size: 56,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _searchQuery.isNotEmpty
                                                  ? 'No sites matching "$_searchQuery"'
                                                  : 'No sites found in $_selectedStatus',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Tap "+ Add Site" below to create a new site.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 80),
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
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
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
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),

                          // Fixed "+ Add Site" Bottom Floating Button
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProjectSetupWizard(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '+ Add Site',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
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
          borderRadius: BorderRadius.circular(18),
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
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                    children: [
                      const TextSpan(text: 'Project: '),
                      TextSpan(
                        text: projectType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                    children: [
                      const TextSpan(text: 'Supervisor: '),
                      TextSpan(
                        text: supervisor,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Progress Bar Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
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
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 50 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'Balance: ₹ ${_formatCurrency(balance)}',
                      style: const TextStyle(
                        fontSize: 12.5,
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

  // -------------------- 5. BOTTOM NAVIGATION BAR --------------------

  Widget _buildBottomNavigationBar(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: false,
                onTap: () => Navigator.pop(context),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.domain_rounded,
                label: 'Sites',
                isSelected: true,
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Finance',
                isSelected: false,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SitePaymentScreen()),
                  );
                },
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                isSelected: false,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => InsightsDashboard()),
                  );
                },
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.grid_view_rounded,
                label: 'More',
                isSelected: false,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrgMenuScreen(standalone: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF1E40AF); // Deep modern blue

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
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
