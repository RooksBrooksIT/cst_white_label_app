import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';
import 'package:demo_cst/screens/organization/site_financial_details_page.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

class ManagerSitesListPage extends StatefulWidget {
  final String initialFilter;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ManagerSitesListPage({
    super.key,
    this.initialFilter = 'All',
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<ManagerSitesListPage> createState() => _ManagerSitesListPageState();
}

class _ManagerSitesListPageState extends State<ManagerSitesListPage> {
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
      // Find matching case
      final match = _statusTabs.firstWhere(
        (t) => t.toLowerCase() == _selectedStatus.toLowerCase(),
        orElse: () => 'All',
      );
      _selectedStatus = match;
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ['Default', 'Name', 'Budget', 'Progress'].map((option) {
                        final isSelected = _sortBy == option;
                        return ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1A56DB),
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
                          if ((widget.showBackButton &&
                                  Navigator.canPop(context)) ||
                              widget.onBack != null)
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (widget.onBack != null) {
                                  widget.onBack!();
                                } else if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Sites & Projects',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Manage live sites & track project stages',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
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
                                  hintText: 'Search by name, ID, supervisor...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
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
                                      ? const Color(0xFF1A56DB)
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
                                      ? const Color(0xFF1A56DB)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Dynamic Status Tabs & 4. Scrollable List of Site Cards
                    Expanded(
                      child: Stack(
                        children: [
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirestoreService.getCollection('Site').snapshots(),
                            builder: (context, siteSnap) {
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirestoreService.projects.snapshots(),
                                builder: (context, projSnap) {
                                  if (siteSnap.connectionState == ConnectionState.waiting && projSnap.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final siteDocs = siteSnap.hasData ? siteSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                                  final projectDocs = projSnap.hasData ? projSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
                                    builder: (context, mapSnap) {
                                      final supervisorDocs = mapSnap.hasData ? mapSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                      final supervisorMap = <String, String>{};
                                      for (var d in supervisorDocs) {
                                        final data = d.data();
                                        final sName = data['supervisor'] ?? data['supervisorName'];
                                        final sId = (data['siteId'] ?? data['site'] ?? d.id).toString();
                                        if (sName != null) {
                                          supervisorMap[sId] = sName.toString();
                                        }
                                      }

                                      final unifiedMap = _buildUnifiedSiteDocs(
                                        siteDocs: siteDocs,
                                        projectDocs: projectDocs,
                                        supervisorDocs: supervisorDocs,
                                      );

                                      final rawDocs = unifiedMap.entries
                                          .map((e) => _SiteEntry(docId: e.key, data: e.value))
                                          .toList();

                                      // Compute Dynamic Tab Counts from Actual Backend Documents
                                      int allCount = rawDocs.length;
                                      int liveCount = 0;
                                      int inProgressCount = 0;
                                      int planningCount = 0;
                                      int completedCount = 0;
                                      int onHoldCount = 0;

                                      for (final entry in rawDocs) {
                                        final data = entry.data;
                                        if (_isCompleted(data)) {
                                          completedCount++;
                                        } else if (_isPlanning(data)) {
                                          planningCount++;
                                        } else if (_isOnHold(data)) {
                                          onHoldCount++;
                                          liveCount++;
                                        } else if (_isInProgress(data)) {
                                          inProgressCount++;
                                          liveCount++;
                                        } else {
                                          inProgressCount++;
                                          liveCount++;
                                        }
                                      }

                                      // Filter by Search Query & Selected Status Tab
                                      final q = _searchQuery.trim().toLowerCase();
                                      final filteredDocs = rawDocs.where((entry) {
                                        final data = entry.data;
                                        final name = (data['siteName'] ?? data['projectName'] ?? '').toString();
                                        final siteId = (data['siteId'] ?? entry.docId).toString();
                                        final projectType = (data['projectType'] ?? data['projectCategory'] ?? data['projectSubCategory'] ?? '').toString();
                                        final supervisor = (data['supervisor'] ?? data['supervisorName'] ?? supervisorMap[siteId] ?? '').toString();
                                        final status = (data['currentStatus'] ?? data['status'] ?? 'Live').toString();

                                        // Search Query match
                                        final matchesQuery = q.isEmpty ||
                                            name.toLowerCase().contains(q) ||
                                            siteId.toLowerCase().contains(q) ||
                                            projectType.toLowerCase().contains(q) ||
                                            supervisor.toLowerCase().contains(q) ||
                                            status.toLowerCase().contains(q);

                                        // Status Tab match
                                        bool matchesStatus = true;
                                        if (_selectedStatus == 'Live') {
                                          matchesStatus = _isLive(data);
                                        } else if (_selectedStatus == 'In Progress') {
                                          matchesStatus = _isInProgress(data);
                                        } else if (_selectedStatus == 'Planning') {
                                          matchesStatus = _isPlanning(data);
                                        } else if (_selectedStatus == 'Completed') {
                                          matchesStatus = _isCompleted(data);
                                        } else if (_selectedStatus == 'On Hold') {
                                          matchesStatus = _isOnHold(data);
                                        }

                                        return matchesQuery && matchesStatus;
                                      }).toList();

                                      // Apply Sorting
                                      if (_sortBy == 'Name') {
                                        filteredDocs.sort((a, b) {
                                          final nameA = (a.data['siteName'] ?? a.data['projectName'] ?? '').toString().toLowerCase();
                                          final nameB = (b.data['siteName'] ?? b.data['projectName'] ?? '').toString().toLowerCase();
                                          return nameA.compareTo(nameB);
                                        });
                                      } else if (_sortBy == 'Budget') {
                                        filteredDocs.sort((a, b) {
                                          final budgetA = (a.data['projectBudget'] is num ? (a.data['projectBudget'] as num).toDouble() : (a.data['budget'] is num ? (a.data['budget'] as num).toDouble() : 0.0));
                                          final budgetB = (b.data['projectBudget'] is num ? (b.data['projectBudget'] as num).toDouble() : (b.data['budget'] is num ? (b.data['budget'] as num).toDouble() : 0.0));
                                          return budgetB.compareTo(budgetA);
                                        });
                                      } else if (_sortBy == 'Progress') {
                                        filteredDocs.sort((a, b) {
                                          final progA = _calculateProgress(a.data);
                                          final progB = _calculateProgress(b.data);
                                          return progB.compareTo(progA);
                                        });
                                      }

                                      return Column(
                                        children: [
                                          // Dynamic Status Tabs with Live Counters
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            child: Row(
                                              children: _statusTabs.map((status) {
                                                final isSelected = _selectedStatus.toLowerCase() == status.toLowerCase();
                                                final tabCount = _getCountForTab(
                                                  status,
                                                  all: allCount,
                                                  live: liveCount,
                                                  inProgress: inProgressCount,
                                                  planning: planningCount,
                                                  completed: completedCount,
                                                  onHold: onHoldCount,
                                                );

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
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? const Color(0xFF1A56DB) : Colors.white,
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                                        boxShadow: isSelected
                                                            ? [
                                                                BoxShadow(
                                                                  color: const Color(0xFF1A56DB).withValues(alpha: 0.3),
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
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            status,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: isSelected
                                                                  ? Colors.white.withValues(alpha: 0.25)
                                                                  : const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            child: Text(
                                                              '$tabCount',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w800,
                                                                color: isSelected ? Colors.white : const Color(0xFF475569),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                          // Site Cards List or Empty State
                                          Expanded(
                                            child: filteredDocs.isEmpty
                                                ? Center(
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(24),
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
                                                            child: const Icon(
                                                              Icons.domain_disabled_rounded,
                                                              size: 48,
                                                              color: Color(0xFF1A56DB),
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
                                                  )
                                                : ListView.builder(
                                                    controller: _scrollController,
                                                    physics: const AlwaysScrollableScrollPhysics(
                                                      parent: BouncingScrollPhysics(),
                                                    ),
                                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 95),
                                                    itemCount: filteredDocs.length,
                                                    itemBuilder: (context, index) {
                                                      final entry = filteredDocs[index];
                                                      final data = entry.data;
                                                      final siteDocId = entry.docId;

                                                      return _buildSiteCard(
                                                        context: context,
                                                        data: data,
                                                        siteDocId: siteDocId,
                                                        supervisorMap: supervisorMap,
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
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
                                  color: const Color(0xFF1A56DB),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1A56DB).withValues(alpha: 0.35),
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
    if (status.contains('complete') || status.contains('finish')) return 100.0;
    if (status.contains('progress') || status.contains('ongoing')) return 45.0;
    if (status.contains('plan')) return 10.0;
    if (status.contains('live') || status.contains('active')) return 30.0;
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
    final category = (data['projectCategory'] ?? data['projectType'] ?? '').toString().trim();
    final subCategory = (data['projectSubCategory'] ?? '').toString().trim();
    final projectType = (category.isNotEmpty && subCategory.isNotEmpty)
        ? '$category • $subCategory'
        : (category.isNotEmpty ? category : (subCategory.isNotEmpty ? subCategory : 'General Project'));

    final supervisor = (data['supervisor'] ??
            data['supervisorName'] ??
            (data['ownerName'] != null && data['ownerName'].toString().trim().isNotEmpty ? 'Owner: ${data['ownerName']}' : null) ??
            supervisorMap[siteId] ??
            'Not Assigned')
        .toString();

    final rawStatus = (data['currentStatus'] ?? data['status'] ?? 'Live').toString();
    final statusBadge = _getStatusBadge(rawStatus, data);

    final budget = (data['projectBudget'] is num ? (data['projectBudget'] as num).toDouble() : (data['budget'] is num ? (data['budget'] as num).toDouble() : (double.tryParse(data['projectBudget']?.toString() ?? '') ?? 0.0)));
    final balance = (data['amountBalance'] is num ? (data['amountBalance'] as num).toDouble() : (data['balance'] is num ? (data['balance'] as num).toDouble() : (data['amountPaid'] is num ? (data['amountPaid'] as num).toDouble() : budget)));
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
                builder: (context) => SiteFinancialDetailsPage(
                  siteId: siteId,
                  siteName: siteName,
                  projectName: (data['projectName'] ?? siteName).toString(),
                  ownerName: (data['ownerName'] ?? '').toString(),
                  initialData: data,
                ),
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
                      progress >= 100
                          ? const Color(0xFF7C3AED)
                          : progress >= 50
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1A56DB),
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

  bool _isCompleted(Map<String, dynamic> data) {
    final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return s.contains('complete') || s.contains('finish') || s.contains('closed') || s.contains('done');
  }

  bool _isPlanning(Map<String, dynamic> data) {
    if (_isCompleted(data)) return false;
    final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return s.contains('plan') || s.contains('draft') || s.contains('setup') || s.contains('upcoming');
  }

  bool _isOnHold(Map<String, dynamic> data) {
    if (_isCompleted(data)) return false;
    final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return s.contains('hold') || s.contains('delay') || s.contains('overdue') || s.contains('pause') || s.contains('suspend');
  }

  bool _isInProgress(Map<String, dynamic> data) {
    if (_isCompleted(data) || _isPlanning(data) || _isOnHold(data)) return false;
    final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return s.contains('progress') || s.contains('ongoing') || s.contains('execution') || s.contains('active') || s.isEmpty;
  }

  bool _isLive(Map<String, dynamic> data) {
    if (_isCompleted(data) || _isPlanning(data)) return false;
    final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return s.contains('live') || s.contains('active') || _isInProgress(data) || _isOnHold(data) || s.isEmpty;
  }

  int _getCountForTab(
    String status, {
    required int all,
    required int live,
    required int inProgress,
    required int planning,
    required int completed,
    required int onHold,
  }) {
    switch (status.toLowerCase()) {
      case 'all':
        return all;
      case 'live':
        return live;
      case 'in progress':
        return inProgress;
      case 'planning':
        return planning;
      case 'completed':
        return completed;
      case 'on hold':
        return onHold;
      default:
        return 0;
    }
  }

  _StatusBadgeData _getStatusBadge(String rawStatus, Map<String, dynamic> data) {
    if (_isCompleted(data)) {
      return _StatusBadgeData(
        label: 'Completed',
        bgColor: const Color(0xFFF3E8FF),
        textColor: const Color(0xFF7C3AED),
      );
    } else if (_isPlanning(data)) {
      return _StatusBadgeData(
        label: 'Planning',
        bgColor: const Color(0xFFFEF3C7),
        textColor: const Color(0xFFD97706),
      );
    } else if (_isOnHold(data)) {
      return _StatusBadgeData(
        label: 'On Hold',
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
      );
    } else if (_isInProgress(data)) {
      return _StatusBadgeData(
        label: 'In Progress',
        bgColor: const Color(0xFFDBEAFE),
        textColor: const Color(0xFF1D4ED8),
      );
    } else if (_isLive(data)) {
      return _StatusBadgeData(
        label: 'Live',
        bgColor: const Color(0xFFDCFCE7),
        textColor: const Color(0xFF16A34A),
      );
    }
    return _StatusBadgeData(
      label: rawStatus.isNotEmpty ? rawStatus : 'Live',
      bgColor: const Color(0xFFDCFCE7),
      textColor: const Color(0xFF16A34A),
    );
  }

  Map<String, Map<String, dynamic>> _buildUnifiedSiteDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> projectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> supervisorDocs,
  }) {
    final unifiedMap = <String, Map<String, dynamic>>{};

    String? findMatchingKey(String siteId, String docId, String siteName) {
      final cleanSiteId = siteId.trim().toLowerCase();
      final cleanDocId = docId.trim().toLowerCase();
      final cleanName = siteName.trim().toLowerCase();

      for (var key in unifiedMap.keys) {
        final k = key.trim().toLowerCase();
        final data = unifiedMap[key]!;
        final sId = (data['siteId'] ?? '').toString().trim().toLowerCase();
        final sName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim().toLowerCase();

        if (k == cleanDocId || k == cleanSiteId) return key;
        if (cleanSiteId.isNotEmpty && (sId == cleanSiteId || k.startsWith(cleanSiteId) || cleanDocId.startsWith(sId))) return key;
        if (cleanDocId.isNotEmpty && (cleanDocId == k || cleanDocId.contains(k) || k.contains(cleanDocId))) return key;
        if (cleanName.isNotEmpty && sName.isNotEmpty && cleanName == sName) return key;
      }
      return null;
    }

    // 1. Ingest Site collection docs (Primary created via Wizard)
    for (var doc in siteDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['docId'] = doc.id;
      final sId = (data['siteId'] ?? '').toString();
      final sName = (data['siteName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      if (existingKey != null) {
        unifiedMap[existingKey]!.addAll(data);
      } else {
        unifiedMap[doc.id] = data;
      }
    }

    // 2. Ingest / Merge projects collection docs
    for (var doc in projectDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['projectDocId'] = doc.id;
      final sId = (data['siteId'] ?? data['site'] ?? '').toString();
      final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      if (existingKey != null) {
        data.forEach((k, v) {
          if (v != null) {
            unifiedMap[existingKey]![k] = v;
          }
        });
      } else {
        unifiedMap[sId.isNotEmpty ? sId : doc.id] = data;
      }
    }

    // 3. Ingest / Merge siteSupervisorMap collection docs
    for (var doc in supervisorDocs) {
      final data = doc.data();
      final sId = (data['siteId'] ?? data['site'] ?? '').toString();
      final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      final target = existingKey != null ? unifiedMap[existingKey] : null;

      if (target != null) {
        final sSupervisor = data['supervisor'] ?? data['supervisorName'];
        if (sSupervisor != null && target['supervisor'] == null) {
          target['supervisor'] = sSupervisor;
        }
        if (data['projectBudget'] != null && (target['projectBudget'] == null || target['projectBudget'] == 0)) {
          target['projectBudget'] = data['projectBudget'];
        }
        if (data['amountSpent'] != null && target['amountSpent'] == null) {
          target['amountSpent'] = data['amountSpent'];
        }
        if (data['amountPaid'] != null && (target['amountPaid'] == null || target['amountPaid'] == 0)) {
          target['amountPaid'] = data['amountPaid'];
        }
        if (data['amountBalance'] != null && target['amountBalance'] == null) {
          target['amountBalance'] = data['amountBalance'];
        }
      }
    }

    return unifiedMap;
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

class _SiteEntry {
  final String docId;
  final Map<String, dynamic> data;

  _SiteEntry({
    required this.docId,
    required this.data,
  });
}

