import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
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
  State<Customerprojectinsightscreen> createState() => _ProjectstageInsightsDashboardState();
}

class _ProjectstageInsightsDashboardState extends State<Customerprojectinsightscreen> {
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _userSiteId = prefs.getString('siteId');
    await _fetchAllSites();
  }

  Future<void> _fetchAllSites() async {
    try {
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      final sites = snapshot.docs.map((doc) => doc.data()['site']?.toString()).where((v) => v != null).map((v) => v!).toSet().toList();
      setState(() {
        allSiteIds = sites;
        if (_userSiteId != null && allSiteIds.contains(_userSiteId)) {
          selectedSiteId = _userSiteId;
        } else if (allSiteIds.isNotEmpty) {
          selectedSiteId = allSiteIds.first;
        }
      });
      if (selectedSiteId != null) await _fetchProjectStages(selectedSiteId!);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProjectStages(String siteId) async {
    setState(() => isLoading = true);
    try {
      final collections = ['siteSupervisorEntries', 'contractorEntries', 'managerEntries', 'organizationEntries'];
      Set<String> stageSet = {};
      for (var col in collections) {
        final snap = await FirestoreService.getCollection(col).where('siteId', isEqualTo: siteId).get();
        for (var doc in snap.docs) {
          final stage = doc.data()['projectStage'];
          if (stage != null && stage.toString().isNotEmpty) stageSet.add(stage.toString());
        }
      }
      setState(() {
        projectStages = stageSet.toList()..sort();
        selectedProjectStage = projectStages.isNotEmpty ? projectStages.first : null;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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
          const Icon(Icons.location_city_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECTED SITE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Text(selectedSiteId ?? 'No Site Selected', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
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
          const Text('REPORT PARAMETERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedProjectStage,
            decoration: const InputDecoration(labelText: 'Project Stage', prefixIcon: Icon(Icons.layers_outlined), border: OutlineInputBorder()),
            items: projectStages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => selectedProjectStage = v),
          ),
          const SizedBox(height: 16),
          if (selectedReportType == ReportType.dailyExpense)
            _buildDatePicker('Report Date', selectedDate, (d) => setState(() => selectedDate = d)),
          if (selectedReportType == ReportType.expenseRange) ...[
            _buildDatePicker('From Date', fromDate, (d) => setState(() => fromDate = d)),
            const SizedBox(height: 16),
            _buildDatePicker('To Date', toDate, (d) => setState(() => toDate = d)),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) onSelect(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_outlined), border: const OutlineInputBorder()),
        child: Text(date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date)),
      ),
    );
  }

  Widget _buildReportTypeSelector(ThemeData theme, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHOICE OF REPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        _reportTypeItem(ReportType.dailyExpense, 'Daily Expense', 'Detailed daily breakdown of all expenditures.', Icons.today_outlined),
        const SizedBox(height: 8),
        _reportTypeItem(ReportType.expenseRange, 'Expense Range', 'Consolidated financial data over a period.', Icons.date_range_outlined),
        const SizedBox(height: 8),
        _reportTypeItem(ReportType.siteSummary, 'Site Summary', 'High-level overview of site performance.', Icons.summarize_outlined),
      ],
    );
  }

  Widget _reportTypeItem(ReportType type, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = selectedReportType == type;
    return InkWell(
      onTap: () => setState(() => selectedReportType = type),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : null,
        border: isSelected ? Border.all(color: theme.primaryColor, width: 2) : null,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? theme.primaryColor : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? theme.primaryColor : null)),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _openReport() {
    if (selectedProjectStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project stage.')));
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
          projectStage: selectedProjectStage!
        );
        break;
      case ReportType.expenseRange:
        if (fromDate == null || toDate == null) return;
        destination = ProjectStageExpensesReportPage(
          siteId: selectedSiteId!, 
          fromDate: fromDate!, 
          toDate: toDate!, 
          projectStage: selectedProjectStage!
        );
        break;
      case ReportType.siteSummary:
        destination = ProjectstageSiteSummaryReport(
          siteId: selectedSiteId!, 
          projectStage: selectedProjectStage!
        );
        break;
    }
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }
}
