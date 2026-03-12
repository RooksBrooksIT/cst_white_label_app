import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/projectStage_expenses_reportpage.dart';
import 'package:demo_cst/screens/projectStage_site_summary_report.dart';
import 'package:demo_cst/screens/projectstage_daily_site_report.dart';
import 'package:intl/intl.dart';


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
      await FirebaseFirestore.instance.collection('siteSupervisorMap').get();
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
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4a7cda);
  static const Color backgroundColor = Color(0xFFf8f9fa);
  static const Color textColor = Color(0xFF2c3e50);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF2e7d32);
  static const Color warningColor = Color(0xFFed6c02);

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
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
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
      print("Error fetching project stages: $e");
      setState(() {
        projectStages = [];
        selectedProjectStage = null;
        selectedSupervisorEntry = null;
      });
    }
  }

  Future<List<SupervisorEntry>> _fetchSupervisorEntriesFromFirestore() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorEntries')
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
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textColor,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textColor,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textColor,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
            content: Text('Missing report criteria'),
            backgroundColor: warningColor,
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
            content: Text('Missing report criteria for Expense Range'),
            backgroundColor: warningColor,
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
            content: Text('Missing site selection for summary'),
            backgroundColor: warningColor,
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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Project Stage Insights',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<SupervisorEntry>>(
        future: supervisorEntriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No supervisor entries found.',
                style: TextStyle(color: textColor),
              ),
            );
          }
          _allSupervisorEntriesCached ??= snapshot.data!;

          final supervisorEntries = snapshot.data!;
          final entriesForSite = siteSupervisorEntries.isNotEmpty
              ? siteSupervisorEntries
              : supervisorEntries
                  .where((e) => e.siteId == selectedSiteId)
                  .toList();

          final filteredEntries = selectedProjectStage == null
              ? entriesForSite
              : entriesForSite
                  .where((entry) => entry.projectStage == selectedProjectStage)
                  .toList();

          if (filteredEntries.isEmpty) {
            selectedSupervisorEntry = null;
          } else {
            selectedSupervisorEntry = filteredEntries.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Project Stage Reports',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Generate detailed reports by project stage',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 24),

                // Site Selection
                _buildModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT SITE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSiteId,
                        items: allSiteIds.map((siteId) {
                          return DropdownMenuItem<String>(
                            value: siteId,
                            child: Text(
                              siteId,
                              style: TextStyle(fontSize: 16, color: textColor),
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
                        decoration: _inputDecoration(),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 2,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        dropdownColor: cardColor,
                      ),
                      SizedBox(height: 12),
                      if (selectedSupervisorEntry?.siteName != null &&
                          selectedSupervisorEntry!.siteName!.isNotEmpty)
                        Text(
                          'Project Name: ${selectedSupervisorEntry!.siteName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Project Stage Selection
                _buildModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT STAGE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedProjectStage,
                        items: projectStages.map((stage) {
                          return DropdownMenuItem<String>(
                            value: stage,
                            child: Text(
                              stage,
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newStage) {
                          setState(() {
                            selectedProjectStage = newStage;
                            if (_allSupervisorEntriesCached == null) {
                              selectedSupervisorEntry = null;
                              return;
                            }
                            final entriesForSite = siteSupervisorEntries
                                    .isNotEmpty
                                ? siteSupervisorEntries
                                : _allSupervisorEntriesCached!
                                    .where((e) => e.siteId == selectedSiteId)
                                    .toList();

                            if (newStage == null) {
                              selectedSupervisorEntry =
                                  entriesForSite.isNotEmpty
                                      ? entriesForSite.first
                                      : null;
                            } else {
                              final filteredEntries = entriesForSite
                                  .where(
                                      (entry) => entry.projectStage == newStage)
                                  .toList();
                              selectedSupervisorEntry =
                                  filteredEntries.isNotEmpty
                                      ? filteredEntries.first
                                      : null;
                            }
                          });
                        },
                        decoration: _inputDecoration(),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 2,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        dropdownColor: cardColor,
                      )
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Report Type Selection
                _buildModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REPORT TYPE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildReportOption(
                        type: ReportType.dailyExpense,
                        icon: Icons.today,
                        title: 'Daily Expense',
                        subtitle: 'View expenses for a specific day',
                      ),
                      Divider(height: 20, thickness: 0.5, color: Colors.grey[300]),
                      _buildReportOption(
                        type: ReportType.expenseRange,
                        icon: Icons.date_range,
                        title: 'Expense Range',
                        subtitle: 'View expenses between dates',
                      ),
                      Divider(height: 20, thickness: 0.5, color: Colors.grey[300]),
                      _buildReportOption(
                        type: ReportType.siteSummary,
                        icon: Icons.summarize,
                        title: 'Site Summary',
                        subtitle: 'Overview of site progress',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Date Selection
                if (selectedReportType == ReportType.dailyExpense)
                  _buildDateInputSection(
                    title: 'SELECT DATE',
                    date: selectedDate,
                    onTap: () => _selectDate(context),
                  ),

                if (selectedReportType == ReportType.expenseRange)
                  Column(
                    children: [
                      _buildDateInputSection(
                        title: 'FROM DATE',
                        date: fromDate,
                        onTap: () => _selectFromDate(context),
                      ),
                      SizedBox(height: 16),
                      _buildDateInputSection(
                        title: 'TO DATE',
                        date: toDate,
                        onTap: () => _selectToDate(context),
                      ),
                    ],
                  ),
                SizedBox(height: 24),

                // Generate Report Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedReportType == ReportType.dailyExpense) {
                        if (selectedSiteId == null ||
                            selectedSiteId!.isEmpty ||
                            selectedDate == null ||
                            selectedProjectStage == null ||
                            selectedProjectStage!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Please select a Site ID, Date, and Project Stage before generating the report.'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        final supervisorEntries = snapshot.data!;
                        final filteredEntries =
                            supervisorEntries.where((entry) {
                          final entryDate = entry.date != null
                              ? DateTime(entry.date!.year, entry.date!.month,
                                  entry.date!.day)
                              : null;
                          final selectedDateOnly = DateTime(selectedDate!.year,
                              selectedDate!.month, selectedDate!.day);
                          return (entry.siteId?.trim().toLowerCase() ?? '') ==
                                  (selectedSiteId?.trim().toLowerCase() ??
                                      '') &&
                              (entry.projectStage == selectedProjectStage) &&
                              (entryDate == selectedDateOnly);
                        }).toList();
                        if (filteredEntries.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No data found'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        selectedSupervisorEntry = filteredEntries.first;
                        _openReport();
                      } else if (selectedReportType ==
                          ReportType.expenseRange) {
                        if (selectedSiteId == null ||
                            selectedSiteId!.isEmpty ||
                            fromDate == null ||
                            toDate == null ||
                            selectedProjectStage == null ||
                            selectedProjectStage!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Please select a Site ID, Project Stage, From Date, and To Date before generating the report.'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        final supervisorEntries = snapshot.data!;
                        final filteredEntries = selectedProjectStage == null
                            ? supervisorEntries
                            : supervisorEntries
                                .where((entry) =>
                                    entry.projectStage == selectedProjectStage)
                                .toList();

                        if (filteredEntries.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'No data found for the selected Site ID and Project Stage.'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        try {
                          selectedSupervisorEntry = filteredEntries.firstWhere(
                            (entry) =>
                                (entry.siteId?.trim().toLowerCase() ?? '') ==
                                (selectedSiteId?.trim().toLowerCase() ?? ''),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'No data found for the selected Site ID and Project Stage.'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        _openReport();
                      } else if (selectedReportType == ReportType.siteSummary) {
                        if (selectedSiteId == null || selectedSiteId!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Please select a Site ID before generating the report.'),
                              backgroundColor: warningColor,
                            ),
                          );
                          return;
                        }
                        _openReport();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                    child: Text(
                      'GENERATE REPORT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryColor, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select a site and project stage to generate detailed reports',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.8),
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

  Widget _buildModernCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReportOption({
    required ReportType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          selectedReportType = type;
          selectedDate = null;
          fromDate = null;
          toDate = null;
        });
        },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selectedReportType == type
                    ? primaryColor.withOpacity(0.1)
                    : Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selectedReportType == type ? primaryColor : Colors.grey[600],
                size: 22,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selectedReportType == type ? primaryColor : textColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedReportType == type
                          ? primaryColor.withOpacity(0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<ReportType>(
              value: type,
              groupValue: selectedReportType,
              onChanged: (ReportType? value) {
                if (value == null) return;
                setState(() {
                  selectedReportType = value;
                  selectedDate = null;
                  fromDate = null;
                  toDate = null;
                });
              },
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInputSection({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? textColor : Colors.grey[600],
                    ),
                  ),
                  Icon(Icons.calendar_month, color: primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}