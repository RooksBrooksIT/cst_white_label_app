import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'projectStage_expenses_reportpage.dart';
import 'projectStage_site_summary_report.dart';
import 'projectstage_daily_site_report.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

enum ReportType { dailyExpense, expenseRange, siteSummary }

class Customerprojectinsightscreen extends StatefulWidget {
  const Customerprojectinsightscreen({super.key});

  @override
  State<Customerprojectinsightscreen> createState() =>
      _ProjectstageInsightsDashboardState();
}

class _ProjectstageInsightsDashboardState
    extends State<Customerprojectinsightscreen> {
  List<String> allSiteIds = [];
  String? selectedSiteId;
  List<String> projectStages = [];
  String? selectedProjectStage;
  ReportType selectedReportType = ReportType.dailyExpense;
  DateTime? selectedDate = DateTime.now();
  DateTime? fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime? toDate = DateTime.now();
  bool isLoading = true;
  String? _userSiteId;

  double _currentStageCost = 0.0;
  bool _isLoadingCost = false;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final auth = AuthService();
    _userSiteId = auth.userData['siteId'];
    if (_userSiteId != null && _userSiteId!.isNotEmpty) {
      setState(() {
        selectedSiteId = _userSiteId;
        allSiteIds = [_userSiteId!];
      });
      await _fetchProjectStages(_userSiteId!);
    } else {
      await _fetchAllSites();
    }
  }

  Future<void> _fetchAllSites() async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();
      // If we already have _userSiteId from auth, we don't need to fetch all sites
      if (_userSiteId != null && _userSiteId!.isNotEmpty) {
        if (mounted) {
          setState(() {
            allSiteIds = [_userSiteId!];
            selectedSiteId = _userSiteId;
          });
        }
        return;
      }

      final snapshot = await FirestoreService.siteSupervisorMap.get();
      final sites = snapshot.docs
          .map((doc) => doc.data()['site']?.toString())
          .where((v) => v != null)
          .map((v) => v!)
          .toSet()
          .toList();
      if (mounted) {
        setState(() {
          allSiteIds = sites;
          if (allSiteIds.isNotEmpty) {
            selectedSiteId = allSiteIds.first;
          }
        });
        if (selectedSiteId != null) await _fetchProjectStages(selectedSiteId!);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProjectStages(String siteId) async {
    if (mounted) setState(() => isLoading = true);
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();
      final collections = [
        'siteSupervisorEntries',
        'contractorEntries',
        'managerEntries',
        'organizationEntries',
      ];
      Set<String> stageSet = {};
      for (var col in collections) {
        final snap = await FirestoreService.getCollection(
          col,
        ).where('siteId', isEqualTo: siteId).get();
        for (var doc in snap.docs) {
          final data = doc.data();
          final stage = data['projectStage'] ?? data['projectField'];
          if (stage != null && stage.toString().isNotEmpty)
            stageSet.add(stage.toString());
        }
      }
      if (mounted) {
        setState(() {
          projectStages = stageSet.toList()..sort();
          selectedProjectStage = projectStages.isNotEmpty
              ? projectStages.first
              : null;
          isLoading = false;
        });
        if (selectedProjectStage != null) {
          _calculateStageCost();
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  Future<void> _calculateStageCost() async {
    final siteId = selectedSiteId?.trim();
    final stage = selectedProjectStage?.trim();

    if (siteId == null || stage == null) return;

    // For Daily/Range reports, only calculate if dates are selected
    if (selectedReportType == ReportType.dailyExpense && selectedDate == null) {
      setState(() => _currentStageCost = 0.0);
      return;
    }
    if (selectedReportType == ReportType.expenseRange &&
        (fromDate == null || toDate == null)) {
      setState(() => _currentStageCost = 0.0);
      return;
    }

    setState(() => _isLoadingCost = true);

    double total = 0.0;
    try {
      final collections = [
        'siteSupervisorEntries',
        'contractorEntries',
        'managerEntries',
        'organizationEntries',
      ];

      final formattedDateYMD = selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
          : null;
      final formattedDateDMY = selectedDate != null
          ? DateFormat('ddMMyyyy').format(selectedDate!)
          : null;
      final start = fromDate;
      final end = toDate;

      for (var collection in collections) {
        // Special case for supervisor entries in daily mode: fetch by document ID
        if (collection == 'siteSupervisorEntries' &&
            selectedReportType == ReportType.dailyExpense &&
            formattedDateDMY != null) {
          final docId = '${siteId}_$formattedDateDMY';
          final doc = await FirestoreService.getCollection(
            collection,
          ).doc(docId).get();
          if (doc.exists) {
            final data = doc.data();
            final docStage = (data?['projectStage'] ?? data?['projectField'])
                ?.toString()
                .trim();
            if (docStage == stage) {
              total += _toNum(data?['totalAmount']);
            }
          }
          continue;
        }

        Query<Map<String, dynamic>> query = FirestoreService.getCollection(
          collection,
        ).where('siteId', isEqualTo: siteId);

        if (selectedReportType == ReportType.dailyExpense &&
            formattedDateYMD != null) {
          final dateField =
              (collection == 'managerEntries' ||
                  collection == 'organizationEntries')
              ? 'entryDate'
              : 'date';
          query = query.where(dateField, isEqualTo: formattedDateYMD);
        }

        final snapshot = await query.get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final docStage = (data['projectStage'] ?? data['projectField'])
              ?.toString()
              .trim();
          if (docStage != stage) continue;

          if (selectedReportType == ReportType.expenseRange &&
              start != null &&
              end != null) {
            final dateField =
                (collection == 'managerEntries' ||
                    collection == 'organizationEntries')
                ? 'entryDate'
                : 'date';
            final rawDate = data[dateField];
            DateTime? entryDate;
            if (rawDate is Timestamp)
              entryDate = rawDate.toDate();
            else if (rawDate is String)
              entryDate = DateTime.tryParse(rawDate);

            if (entryDate == null ||
                entryDate.isBefore(start.subtract(const Duration(days: 1))) ||
                entryDate.isAfter(end.add(const Duration(days: 1)))) {
              continue;
            }
          }

          if (collection == 'siteSupervisorEntries' ||
              collection == 'contractorEntries') {
            total += _toNum(data['totalAmount'] ?? data['amount']);
          } else {
            if (data.containsKey('bills')) {
              final bills = data['bills'] as List? ?? [];
              for (var bill in bills) {
                if (bill is Map) {
                  if (selectedReportType == ReportType.dailyExpense &&
                      formattedDateYMD != null) {
                    final billDateRaw = bill['billDate'];
                    String? billDateStr;
                    if (billDateRaw is String)
                      billDateStr = billDateRaw;
                    else if (billDateRaw is Timestamp)
                      billDateStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(billDateRaw.toDate());

                    if (billDateStr != formattedDateYMD) continue;
                  }
                  total += _toNum(bill['billAmount']);
                }
              }
            } else {
              total += _toNum(data['totalAmount'] ?? data['amount']);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentStageCost = total;
          _isLoadingCost = false;
        });
      }
    } catch (e) {
      print("Error calculating stage cost: $e");
      if (mounted) setState(() => _isLoadingCost = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Project Stage Insights',
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSiteHeader(theme),
                  const SizedBox(height: 24),
                  _buildStageCostCard(theme),
                  const SizedBox(height: 24),
                  _buildSelectionCard(theme),
                  const SizedBox(height: 24),
                  _buildReportTypeSelector(theme, isMobile),
                  const SizedBox(height: 32),
                  GlassButton(
                    label: 'GENERATE REPORT',
                    onPressed: _openReport,
                    icon: Icons.analytics_outlined,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSiteHeader(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor,
      child: Row(
        children: [
          const Icon(
            Icons.location_city_outlined,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR SITE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  selectedSiteId ?? 'No Site Selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCostCard(ThemeData theme) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedReportType == ReportType.dailyExpense
                    ? 'DAILY STAGE COST'
                    : selectedReportType == ReportType.expenseRange
                    ? 'RANGE STAGE COST'
                    : 'TOTAL STAGE COST',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedProjectStage ?? 'Select Stage',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_isLoadingCost)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              '₹ ${_currentStageCost.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORT PARAMETERS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedProjectStage,
            decoration: const InputDecoration(
              labelText: 'Project Stage',
              prefixIcon: Icon(Icons.layers_outlined),
              border: OutlineInputBorder(),
            ),
            items: projectStages
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              setState(() => selectedProjectStage = v);
              _calculateStageCost();
            },
          ),
          const SizedBox(height: 16),
          if (selectedReportType == ReportType.dailyExpense)
            _buildDatePicker('Report Date', selectedDate, (d) {
              setState(() => selectedDate = d);
              _calculateStageCost();
            }),
          if (selectedReportType == ReportType.expenseRange) ...[
            _buildDatePicker('From Date', fromDate, (d) {
              setState(() => fromDate = d);
              _calculateStageCost();
            }),
            const SizedBox(height: 16),
            _buildDatePicker('To Date', toDate, (d) {
              setState(() => toDate = d);
              _calculateStageCost();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onSelect,
  ) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onSelect(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date),
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector(ThemeData theme, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHOICE OF REPORT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _reportTypeItem(
          ReportType.dailyExpense,
          'Daily Expense',
          'Detailed daily breakdown of all expenditures.',
          Icons.today_outlined,
        ),
        const SizedBox(height: 8),
        _reportTypeItem(
          ReportType.expenseRange,
          'Expense Range',
          'Consolidated financial data over a period.',
          Icons.date_range_outlined,
        ),
        const SizedBox(height: 8),
        _reportTypeItem(
          ReportType.siteSummary,
          'Site Summary',
          'High-level overview of site performance.',
          Icons.summarize_outlined,
        ),
      ],
    );
  }

  Widget _reportTypeItem(
    ReportType type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isSelected = selectedReportType == type;
    return InkWell(
      onTap: () {
        setState(() => selectedReportType = type);
        _calculateStageCost();
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : null,
        border: isSelected
            ? Border.all(color: theme.primaryColor, width: 2)
            : null,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? theme.primaryColor : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.primaryColor : null,
                    ),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _openReport() {
    if (selectedProjectStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project stage.')),
      );
      return;
    }

    Widget destination;
    switch (selectedReportType) {
      case ReportType.dailyExpense:
        if (selectedDate == null) return;
        destination = ProjectStageDailySiteExpensesReportPage(
          supervisorId: 'Customer',
          siteId: selectedSiteId,
          date: selectedDate!,
          projectStage: selectedProjectStage!,
        );
        break;
      case ReportType.expenseRange:
        if (fromDate == null || toDate == null) return;
        destination = ProjectStageExpensesReportPage(
          siteId: selectedSiteId!,
          fromDate: fromDate!,
          toDate: toDate!,
          projectStage: selectedProjectStage!,
        );
        break;
      case ReportType.siteSummary:
        destination = ProjectstageSiteSummaryReport(
          siteId: selectedSiteId!,
          projectStage: selectedProjectStage!,
        );
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }
}
