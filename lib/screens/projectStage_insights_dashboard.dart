import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/projectStage_expenses_reportpage.dart';
import 'package:demo_cst/screens/projectStage_site_summary_report.dart';
import 'package:demo_cst/screens/projectstage_daily_site_report.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

// --- SupervisorEntry Model ---
class SupervisorEntry {
  final String supervisorId;
  final String? siteId;
  final String? siteName;
  final DateTime? date;
  final num? amount;
  final num? totalamount;
  final String? projectStage;

  SupervisorEntry({
    required this.supervisorId,
    this.siteId,
    this.siteName,
    this.date,
    this.amount,
    this.totalamount,
    this.projectStage,
  });

  factory SupervisorEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupervisorEntry(
      supervisorId: data['supervisorId'] ?? '',
      siteId: data['siteId'] ?? '',
      siteName: data['siteName'],
      date: data['date'] != null
          ? (data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.tryParse(data['date'].toString()))
          : null,
      amount: data['amount'],
      totalamount: data['totalamount'],
      projectStage: data['projectStage'],
    );
  }
}

// --- SiteSupervisorMapEntry Model ---
class SiteSupervisorMapEntry {
  final String supervisorId;
  final String joinedOn;
  final String location;
  final String projectName;
  final String projectStage;
  final String site;
  final String siteComments;
  final String supervisor;

  SiteSupervisorMapEntry({
    required this.supervisorId,
    required this.joinedOn,
    required this.location,
    required this.projectName,
    required this.projectStage,
    required this.site,
    required this.siteComments,
    required this.supervisor,
  });

  factory SiteSupervisorMapEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SiteSupervisorMapEntry(
      supervisorId: data['Supervisor ID'] ?? '',
      joinedOn: data['joinedOn'] ?? '',
      location: data['location'] ?? '',
      projectName: data['projectName'] ?? '',
      projectStage: data['projectStage'] ?? '',
      site: data['site'] ?? '',
      siteComments: data['siteComments'] ?? '',
      supervisor: data['supervisor'] ?? '',
    );
  }
}

Future<List<SiteSupervisorMapEntry>> fetchAllSiteSupervisorMapEntries() async {
  final snapshot =
      await FirestoreService.getCollection('siteSupervisorMap').get();
  return snapshot.docs
      .map((doc) => SiteSupervisorMapEntry.fromFirestore(doc))
      .toList();
}

enum ReportType {
  dailyExpense,
  expenseRange,
  siteSummary,
}

class ProjectstageInsightsDashboard extends StatefulWidget {
  const ProjectstageInsightsDashboard({super.key});

  @override
  State<ProjectstageInsightsDashboard> createState() =>
      _ProjectstageInsightsDashboardState();
}

class _ProjectstageInsightsDashboardState
    extends State<ProjectstageInsightsDashboard> {
  late Future<List<SupervisorEntry>> supervisorEntriesFuture;
  SupervisorEntry? selectedSupervisorEntry;

  List<String> allSiteIds = [];
  String? selectedSiteId;

  List<SiteSupervisorMapEntry> allSiteEntries = [];

  List<String> projectStages = [];
  String? selectedProjectStage;
  List<SupervisorEntry> siteSupervisorEntries = [];

  ReportType selectedReportType = ReportType.dailyExpense;

  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  List<SupervisorEntry>? _allSupervisorEntriesCached;

  @override
  void initState() {
    super.initState();
    supervisorEntriesFuture = _fetchSupervisorEntriesFromFirestore();
    _fetchAllSites();
  }

  Future<void> _fetchAllSites() async {
    final siteEntries = await fetchAllSiteSupervisorMapEntries();
    setState(() {
      allSiteEntries = siteEntries;
      allSiteIds = siteEntries.map((e) => e.site).toSet().toList();
      if (allSiteIds.isNotEmpty && selectedSiteId == null) {
        selectedSiteId = allSiteIds.first;
      }
    });
    await _fetchProjectStagesForSite(selectedSiteId);
  }

  Future<void> _fetchProjectStagesForSite(String? siteId) async {
    if (siteId == null) {
      setState(() {
        projectStages = [];
        selectedProjectStage = null;
        siteSupervisorEntries = [];
      });
      return;
    }
    try {
      final collections = [
        'siteSupervisorEntries',
        'contractorEntries',
        'managerEntries',
        'organizationEntries',
      ];
      Set<String> stageSet = {};

      final futures = collections.map((collection) async {
        final snapshot = await FirestoreService.getCollection(collection)
            .where('siteId', isEqualTo: siteId)
            .get();
        for (var doc in snapshot.docs) {
          if (doc.data().containsKey('projectStage')) {
            final stage = doc['projectStage'];
            if (stage != null && stage.toString().trim().isNotEmpty) {
              stageSet.add(stage.toString());
            }
          }
        }
      }).toList();

      await Future.wait(futures);

      setState(() {
        projectStages = stageSet.toList();
        selectedProjectStage =
            projectStages.isNotEmpty ? projectStages.first : null;

        _updateSelectedSupervisorEntry();
      });
    } catch (e) {
      debugPrint("Error fetching project stages: $e");
      setState(() {
        projectStages = [];
        selectedProjectStage = null;
        selectedSupervisorEntry = null;
      });
    }
  }

  Future<List<SupervisorEntry>> _fetchSupervisorEntriesFromFirestore() async {
    final querySnapshot = await FirestoreService.getCollection('siteSupervisorEntries')
        .get();
    final entries = querySnapshot.docs
        .map((doc) => SupervisorEntry.fromFirestore(doc))
        .toList();

    _allSupervisorEntriesCached = entries;
    return entries;
  }

  void _updateSelectedSupervisorEntry() {
    if (_allSupervisorEntriesCached == null) {
      selectedSupervisorEntry = null;
      return;
    }

    final entriesForSite = siteSupervisorEntries.isNotEmpty
        ? siteSupervisorEntries
        : _allSupervisorEntriesCached!
            .where((e) => e.siteId == selectedSiteId)
            .toList();

    if (selectedProjectStage == null) {
      selectedSupervisorEntry =
          entriesForSite.isNotEmpty ? entriesForSite.first : null;
    } else {
      final filteredEntries = entriesForSite
          .where((entry) => entry.projectStage == selectedProjectStage)
          .toList();
      selectedSupervisorEntry =
          filteredEntries.isNotEmpty ? filteredEntries.first : null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: const DialogThemeData(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: const DialogThemeData(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != fromDate) {
      setState(() {
        fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: const DialogThemeData(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != toDate) {
      setState(() {
        toDate = picked;
      });
    }
  }

  void _openReport() {
    if (selectedReportType == ReportType.dailyExpense) {
      if (selectedSupervisorEntry == null ||
          selectedDate == null ||
          selectedProjectStage == null ||
          selectedSupervisorEntry!.siteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Missing report criteria'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectStageDailySiteExpensesReportPage(
            supervisorId: selectedSupervisorEntry!.supervisorId,
            siteId: selectedSupervisorEntry!.siteId!,
            date: selectedDate!,
            projectStage: selectedProjectStage!,
          ),
        ),
      );
    } else if (selectedReportType == ReportType.expenseRange) {
      if (selectedSupervisorEntry == null ||
          fromDate == null ||
          toDate == null ||
          selectedProjectStage == null ||
          selectedSupervisorEntry!.siteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Missing report criteria for Expense Range'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectStageExpensesReportPage(
            siteId: selectedSupervisorEntry!.siteId!,
            fromDate: fromDate!,
            toDate: toDate!,
            projectStage: selectedProjectStage!,
          ),
        ),
      );
    } else if (selectedReportType == ReportType.siteSummary) {
      if (selectedSupervisorEntry == null ||
          selectedSupervisorEntry!.siteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Missing site selection for summary'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectstageSiteSummaryReport(
            siteId: selectedSupervisorEntry!.siteId!,
            projectStage: selectedProjectStage ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Project Stage Insights',
      body: FutureBuilder<List<SupervisorEntry>>(
        future: supervisorEntriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No supervisor entries found.',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          _allSupervisorEntriesCached ??= snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Project Stage Reports',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate detailed reports by project stage',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Site Selection
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT SITE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSiteId,
                        items: allSiteIds.map((siteId) {
                          return DropdownMenuItem<String>(
                            value: siteId,
                            child: Text(
                              siteId,
                              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newSiteId) async {
                          setState(() {
                            selectedSiteId = newSiteId;
                            selectedProjectStage = null;
                            projectStages = [];
                            siteSupervisorEntries = [];
                            selectedSupervisorEntry = null;
                          });
                          await _fetchProjectStagesForSite(newSiteId);
                        },
                        decoration: _inputDecoration(theme),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 2,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                        dropdownColor: theme.cardColor,
                      ),
                      if (selectedSupervisorEntry?.siteName != null &&
                          selectedSupervisorEntry!.siteName!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Project Name: ${selectedSupervisorEntry!.siteName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Project Stage Selection
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT STAGE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedProjectStage,
                        items: projectStages.map((stage) {
                          return DropdownMenuItem<String>(
                            value: stage,
                            child: Text(
                              stage,
                              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newStage) {
                          setState(() {
                            selectedProjectStage = newStage;
                            _updateSelectedSupervisorEntry();
                          });
                        },
                        decoration: _inputDecoration(theme),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 2,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                        dropdownColor: theme.cardColor,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Report Type Selection
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REPORT TYPE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildReportOption(
                        type: ReportType.dailyExpense,
                        icon: Icons.today_outlined,
                        title: 'Daily Expense',
                        subtitle: 'View expenses for a specific day',
                        theme: theme,
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildReportOption(
                        type: ReportType.expenseRange,
                        icon: Icons.date_range_outlined,
                        title: 'Expense Range',
                        subtitle: 'View expenses between dates',
                        theme: theme,
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildReportOption(
                        type: ReportType.siteSummary,
                        icon: Icons.summarize_outlined,
                        title: 'Site Summary',
                        subtitle: 'Overview of site progress',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Date Selection
                if (selectedReportType == ReportType.dailyExpense)
                  _buildDateInputSection(
                    title: 'SELECT DATE',
                    date: selectedDate,
                    onTap: () => _selectDate(context),
                    theme: theme,
                  ),

                if (selectedReportType == ReportType.expenseRange)
                  Column(
                    children: [
                      _buildDateInputSection(
                        title: 'FROM DATE',
                        date: fromDate,
                        onTap: () => _selectFromDate(context),
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildDateInputSection(
                        title: 'TO DATE',
                        date: toDate,
                        onTap: () => _selectToDate(context),
                        theme: theme,
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // Generate Report Button
                GlassButton(
                  label: 'GENERATE REPORT',
                  icon: Icons.analytics_outlined,
                  onPressed: () => _handleGenerateReport(theme, snapshot.data!),
                ),
                const SizedBox(height: 32),
                GlassCard(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select a site and project stage to generate detailed reports',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleGenerateReport(ThemeData theme, List<SupervisorEntry> supervisorEntries) {
    if (selectedReportType == ReportType.dailyExpense) {
      if (selectedSiteId == null ||
          selectedSiteId!.isEmpty ||
          selectedDate == null ||
          selectedProjectStage == null ||
          selectedProjectStage!.isEmpty) {
        _showErrorSnackBar(theme, 'Please select a Site ID, Date, and Project Stage.');
        return;
      }
      final filteredEntries = supervisorEntries.where((entry) {
        final entryDate = entry.date != null
            ? DateTime(entry.date!.year, entry.date!.month, entry.date!.day)
            : null;
        final selectedDateOnly = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
        return (entry.siteId?.trim().toLowerCase() ?? '') == (selectedSiteId?.trim().toLowerCase() ?? '') &&
            (entry.projectStage == selectedProjectStage) &&
            (entryDate == selectedDateOnly);
      }).toList();

      if (filteredEntries.isEmpty) {
        _showErrorSnackBar(theme, 'No data found for the selected criteria.');
        return;
      }
      selectedSupervisorEntry = filteredEntries.first;
      _openReport();
    } else if (selectedReportType == ReportType.expenseRange) {
      if (selectedSiteId == null ||
          selectedSiteId!.isEmpty ||
          fromDate == null ||
          toDate == null ||
          selectedProjectStage == null ||
          selectedProjectStage!.isEmpty) {
        _showErrorSnackBar(theme, 'Please select a Site ID, Project Stage, and Date Range.');
        return;
      }
      _openReport();
    } else if (selectedReportType == ReportType.siteSummary) {
      if (selectedSiteId == null || selectedSiteId!.isEmpty) {
        _showErrorSnackBar(theme, 'Please select a Site ID.');
        return;
      }
      _openReport();
    }
  }

  void _showErrorSnackBar(ThemeData theme, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }

  Widget _buildReportOption({
    required ReportType type,
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    final isSelected = selectedReportType == type;
    return InkWell(
      onTap: () => setState(() {
        selectedReportType = type;
        selectedDate = null;
        fromDate = null;
        toDate = null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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

  Widget _buildDateInputSection({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date != null
                          ? DateFormat('dd MMM, yyyy').format(date)
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: 15,
                        color: date != null 
                            ? theme.colorScheme.onSurface 
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(Icons.calendar_today_outlined, color: theme.primaryColor, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ThemeData theme) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
    );
  }
}