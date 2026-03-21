import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/projectStage_expenses_reportpage.dart';
import 'package:demo_cst/screens/projectStage_site_summary_report.dart';
import 'package:demo_cst/screens/projectstage_daily_site_report.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final snapshot = await FirebaseFirestore.instance
      .collection('siteSupervisorMap')
      .get();
  return snapshot.docs
      .map((doc) => SiteSupervisorMapEntry.fromFirestore(doc))
      .toList();
}

enum ReportType { dailyExpense, expenseRange, siteSummary }

class Customerprojectinsightscreen extends StatefulWidget {
  const Customerprojectinsightscreen({super.key});

  @override
  State<Customerprojectinsightscreen> createState() =>
      _ProjectstageInsightsDashboardState();
}

class _ProjectstageInsightsDashboardState
    extends State<Customerprojectinsightscreen> {
  Future<List<SupervisorEntry>>?
  supervisorEntriesFuture; // Changed to nullable Future
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

  // User data fields
  String? _ownerName;
  String? _ownerPhoneNumber;
  String? _userSiteId;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchEntries();
  }

  Future<void> _loadUserDataAndFetchEntries() async {
    // Load user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownerName = prefs.getString('ownerName');
      _ownerPhoneNumber = prefs.getString('ownerPhoneNumber');
      _userSiteId = prefs.getString('siteId');
    });

    // Initialize the futures
    setState(() {
      supervisorEntriesFuture = _fetchSupervisorEntriesFromFirestore();
    });
    await _fetchAllSites();
  }

  Future<void> _fetchAllSites() async {
    final siteEntries = await fetchAllSiteSupervisorMapEntries();
    setState(() {
      allSiteEntries = siteEntries;
      allSiteIds = siteEntries.map((e) => e.site).toSet().toList();

      // If user has a siteId from login, use it as default
      if (_userSiteId != null && allSiteIds.contains(_userSiteId)) {
        selectedSiteId = _userSiteId;
      } else if (allSiteIds.isNotEmpty && selectedSiteId == null) {
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
        selectedProjectStage = projectStages.isNotEmpty
            ? projectStages.first
            : null;

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
    try {
      Query query = FirebaseFirestore.instance.collection(
        'siteSupervisorEntries',
      );

      // If user has a siteId from login, filter by it
      if (_userSiteId != null && _userSiteId!.isNotEmpty) {
        query = query.where('siteId', isEqualTo: _userSiteId);
      }

      final querySnapshot = await query.get();
      final entries = querySnapshot.docs
          .map((doc) => SupervisorEntry.fromFirestore(doc))
          .toList();

      _allSupervisorEntriesCached = entries;
      return entries;
    } catch (e) {
      print('Error fetching supervisor entries: $e');
      return [];
    }
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
      selectedSupervisorEntry = entriesForSite.isNotEmpty
          ? entriesForSite.first
          : null;
    } else {
      final filteredEntries = entriesForSite
          .where((entry) => entry.projectStage == selectedProjectStage)
          .toList();
      selectedSupervisorEntry = filteredEntries.isNotEmpty
          ? filteredEntries.first
          : null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
          const SnackBar(content: Text('Missing report criteria')),
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
          const SnackBar(
            content: Text('Missing report criteria for Expense Range'),
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
          const SnackBar(content: Text('Missing site selection for summary')),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Project Stage Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        
        foregroundColor: const Color(0xFF003768),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: supervisorEntriesFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<SupervisorEntry>>(
              future: supervisorEntriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userSiteId != null
                              ? 'No data found for your site'
                              : 'No supervisor entries found',
                          style: TextStyle(),
                        ),
                        if (_userSiteId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Site ID: $_userSiteId',
                            style: TextStyle(
                              color: Color(0xFF003768),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                if (_allSupervisorEntriesCached == null) {
                  _allSupervisorEntriesCached = snapshot.data!;
                }

                final supervisorEntries = snapshot.data!;
                final entriesForSite = siteSupervisorEntries.isNotEmpty
                    ? siteSupervisorEntries
                    : supervisorEntries
                          .where((e) => e.siteId == selectedSiteId)
                          .toList();

                final filteredEntries = selectedProjectStage == null
                    ? entriesForSite
                    : entriesForSite
                          .where(
                            (entry) =>
                                entry.projectStage == selectedProjectStage,
                          )
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
                      // User Info Card - Displaying login credentials
                      // _buildModernCard(
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       const Text('LOGIN INFORMATION',
                      //           style: TextStyle(
                      //             fontSize: 12,
                      //             fontWeight: FontWeight.bold,
                      //             color: Colors.grey,
                      //             letterSpacing: 1.2,
                      //           )),
                      //       const SizedBox(height: 12),
                      //       // Display Owner Name
                      //       Row(
                      //         children: [
                      //           Icon(Icons.person, color: Color(0xFF772323)),
                      //           const SizedBox(width: 12),
                      //           Expanded(
                      //             child: Column(
                      //               crossAxisAlignment:
                      //                   CrossAxisAlignment.start,
                      //               children: [
                      //                 Text(
                      //                   'Name',
                      //                   style: TextStyle(
                      //                     fontSize: 12,
                      //                     
                      //                   ),
                      //                 ),
                      //                 Text(
                      //                   _ownerName ?? 'Not available',
                      //                   style: const TextStyle(
                      //                     fontSize: 16,
                      //                     fontWeight: FontWeight.bold,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //       const SizedBox(height: 16),
                      //       // Display Phone Number (Password)
                      //       Row(
                      //         children: [
                      //           Icon(Icons.phone, color: Color(0xFF772323)),
                      //           const SizedBox(width: 12),
                      //           Expanded(
                      //             child: Column(
                      //               crossAxisAlignment:
                      //                   CrossAxisAlignment.start,
                      //               children: [
                      //                 Text(
                      //                   'Phone Number',
                      //                   style: TextStyle(
                      //                     fontSize: 12,
                      //                     
                      //                   ),
                      //                 ),
                      //                 Text(
                      //                   _ownerPhoneNumber ?? 'Not available',
                      //                   style: const TextStyle(
                      //                     fontSize: 16,
                      //                     fontWeight: FontWeight.bold,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      const SizedBox(height: 16),

                      // Site Information Card
                      if (_userSiteId != null)
                        _buildModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YOUR SITE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    color: Color(0xFF003768),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Site ID',
                                          style: TextStyle(
                                            fontSize: 12,
                                            
                                          ),
                                        ),
                                        Text(
                                          _userSiteId!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Site Selection Card (only show if multiple sites)
                      _buildModernCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROJECT STAGE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedProjectStage,
                              items: projectStages.map((stage) {
                                return DropdownMenuItem<String>(
                                  value: stage,
                                  child: Text(
                                    stage,
                                    style: const TextStyle(fontSize: 16),
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
                                  final entriesForSite =
                                      siteSupervisorEntries.isNotEmpty
                                      ? siteSupervisorEntries
                                      : _allSupervisorEntriesCached!
                                            .where(
                                              (e) => e.siteId == selectedSiteId,
                                            )
                                            .toList();

                                  if (newStage == null) {
                                    selectedSupervisorEntry =
                                        entriesForSite.isNotEmpty
                                        ? entriesForSite.first
                                        : null;
                                  } else {
                                    final filteredEntries = entriesForSite
                                        .where(
                                          (entry) =>
                                              entry.projectStage == newStage,
                                        )
                                        .toList();
                                    selectedSupervisorEntry =
                                        filteredEntries.isNotEmpty
                                        ? filteredEntries.first
                                        : null;
                                  }
                                });
                              },
                              decoration: _inputDecoration(),
                              borderRadius: BorderRadius.circular(12),
                              elevation: 2,
                              isExpanded: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                            _buildDateInputSection(
                              title: 'TO DATE',
                              date: toDate,
                              onTap: () => _selectToDate(context),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      _buildModernCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REPORT TYPE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildReportOption(
                              type: ReportType.dailyExpense,
                              icon: Icons.today,
                              title: 'Daily Expense',
                              subtitle: 'View expenses for a specific day',
                            ),
                            const Divider(height: 24, thickness: 0.5),
                            _buildReportOption(
                              type: ReportType.expenseRange,
                              icon: Icons.date_range,
                              title: 'Expense Range',
                              subtitle: 'View expenses between dates',
                            ),
                            const Divider(height: 24, thickness: 0.5),
                            _buildReportOption(
                              type: ReportType.siteSummary,
                              icon: Icons.summarize,
                              title: 'Site Summary',
                              subtitle: 'Overview of site progress',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                                  const SnackBar(
                                    content: Text(
                                      'Please select a Site ID, Date, and Project Stage before generating the report.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final supervisorEntries = snapshot.data!;
                              final filteredEntries = supervisorEntries.where((
                                entry,
                              ) {
                                final entryDate = entry.date != null
                                    ? DateTime(
                                        entry.date!.year,
                                        entry.date!.month,
                                        entry.date!.day,
                                      )
                                    : null;
                                final selectedDateOnly = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                );
                                return (entry.siteId?.trim().toLowerCase() ??
                                            '') ==
                                        (selectedSiteId?.trim().toLowerCase() ??
                                            '') &&
                                    (entry.projectStage ==
                                        selectedProjectStage) &&
                                    (entryDate == selectedDateOnly);
                              }).toList();
                              if (filteredEntries.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No data found'),
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
                                  const SnackBar(
                                    content: Text(
                                      'Please select a Site ID, Project Stage, From Date, and To Date before generating the report.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final supervisorEntries = snapshot.data!;
                              final filteredEntries =
                                  selectedProjectStage == null
                                  ? supervisorEntries
                                  : supervisorEntries
                                        .where(
                                          (entry) =>
                                              entry.projectStage ==
                                              selectedProjectStage,
                                        )
                                        .toList();

                              if (filteredEntries.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No data found for the selected Site ID and Project Stage.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              try {
                                selectedSupervisorEntry = filteredEntries
                                    .firstWhere(
                                      (entry) =>
                                          (entry.siteId?.trim().toLowerCase() ??
                                              '') ==
                                          (selectedSiteId
                                                  ?.trim()
                                                  .toLowerCase() ??
                                              ''),
                                    );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No data found for the selected Site ID and Project Stage.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _openReport();
                            } else if (selectedReportType ==
                                ReportType.siteSummary) {
                              if (selectedSiteId == null ||
                                  selectedSiteId!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a Site ID before generating the report.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _openReport();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003768),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 2,
                          ),
                          child: const Text(
                            'GENERATE REPORT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedReportType == type
                    ? const Color(0x1AFF003768)
                    : Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selectedReportType == type
                    ? const Color(0xFF003768)
                    : Colors.grey,
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
                      fontWeight: FontWeight.bold,
                      color: selectedReportType == type
                          ? const Color(0xFF003768)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedReportType == type
                          ? const Color(0xFF003768).withOpacity(0.7)
                          : Colors.grey,
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
              activeColor: const Color(0xFF003768),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
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
                      color: date != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.calendar_month, color: Color(0xFF003768)),
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
