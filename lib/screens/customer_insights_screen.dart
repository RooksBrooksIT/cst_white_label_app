import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:demo_cst/screens/daily_site_report.dart';
import 'package:demo_cst/screens/site_expenses_reportpage.dart';
import 'package:demo_cst/screens/site_summary_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- SupervisorEntry Model ---
class CustomerEntry {
  final String supervisorId;
  final String? siteId;
  final String? siteName;
  final DateTime? date;
  final num? amount;
  final num? totalamount;

  CustomerEntry({
    required this.supervisorId,
    this.siteId,
    this.siteName,
    this.date,
    this.amount,
    this.totalamount,
  });

  factory CustomerEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomerEntry(
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
    );
  }
}

enum ReportType { dailyExpense, expenseRange, siteSummary }

class CustomerInsightsScreen extends StatefulWidget {
  const CustomerInsightsScreen({
    super.key,
    required String loggedInUserName,
    required String ownerphonenumber,
  });

  @override
  State<CustomerInsightsScreen> createState() => _CustomerInsightsScreenState();
}

class _CustomerInsightsScreenState extends State<CustomerInsightsScreen> {
  Future<List<CustomerEntry>>? supervisorEntriesFuture;
  CustomerEntry? selectedSupervisorEntry;

  String? _ownerName;
  String? _ownerPhoneNumber;
  String? _userSiteId;

  ReportType selectedReportType = ReportType.dailyExpense;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchEntries();
    _fetchSupervisorEntries();
  }

  Future<void> _loadUserDataAndFetchEntries() async {
    // Load user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownerName = prefs.getString('ownerName');
      _ownerPhoneNumber = prefs.getString('ownerPhoneNumber');
      _userSiteId = prefs.getString('siteId');
    });

    // Initialize the future
    setState(() {
      supervisorEntriesFuture = _fetchSupervisorEntries();
    });
  }

  Future<List<CustomerEntry>> _fetchSupervisorEntries() async {
    try {
      // First, fetch user's siteId if we have user data
      if (_ownerName != null && _ownerPhoneNumber != null) {
        await _fetchUserSiteId();
      }

      Query query = FirestoreService.siteSupervisorEntries;

      // If user has a siteId, filter by it
      if (_userSiteId != null && _userSiteId!.isNotEmpty) {
        query = query.where('siteId', isEqualTo: _userSiteId);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => CustomerEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching supervisor entries: $e');
      return [];
    }
  }

  Future<void> _fetchUserSiteId() async {
    try {
      final querySnapshot = await FirestoreService.projects
          .where('ownerName', isEqualTo: _ownerName)
          .where('ownerPhoneNumber', isEqualTo: _ownerPhoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _userSiteId = querySnapshot.docs.first['siteId'].toString();
        });
      }
    } catch (e) {
      print('Error fetching user siteId: $e');
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
    if (selectedSupervisorEntry == null) return;

    if (selectedReportType == ReportType.dailyExpense) {
      if (selectedDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a date')));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailySiteExpensesReportPage(
            supervisorId: selectedSupervisorEntry!.supervisorId,
            siteId: selectedSupervisorEntry!.siteId,
            date: selectedDate!,
          ),
        ),
      );
    } else if (selectedReportType == ReportType.expenseRange) {
      if (fromDate == null || toDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both dates')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteExpensesReportPage(
            siteId: selectedSupervisorEntry!.siteId!,
            fromDate: fromDate!,
            toDate: toDate!,
            supervisorId: '',
          ),
        ),
      );
    } else if (selectedReportType == ReportType.siteSummary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SiteSummaryPage(siteId: selectedSupervisorEntry!.siteId!),
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
          'CST Insights',
          style: TextStyle(fontWeight: FontWeight.bold, ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20.0),
            bottomRight: Radius.circular(20.0),
          ),
        ),
      ),
      body: supervisorEntriesFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<CustomerEntry>>(
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
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final supervisorEntries = snapshot.data!;
                final uniqueSiteIds = supervisorEntries
                    .where(
                      (entry) =>
                          entry.siteId != null && entry.siteId!.isNotEmpty,
                    )
                    .map((entry) => entry.siteId!)
                    .toSet()
                    .toList();

                selectedSupervisorEntry ??= supervisorEntries.firstWhere(
                  (entry) => entry.siteId == uniqueSiteIds.first,
                  orElse: () => supervisorEntries.first,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // // User Info Card - Displaying login credentials
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
                                    color: Theme.of(context).primaryColor,
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
                      if (uniqueSiteIds.length > 1)
                        _buildModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SELECT SITE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedSupervisorEntry?.siteId,
                                items: uniqueSiteIds.map((siteId) {
                                  return DropdownMenuItem<String>(
                                    value: siteId,
                                    child: Text(
                                      siteId,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newSiteId) {
                                  setState(() {
                                    selectedSupervisorEntry = supervisorEntries
                                        .firstWhere(
                                          (entry) => entry.siteId == newSiteId,
                                          orElse: () => supervisorEntries.first,
                                        );
                                  });
                                },
                                decoration: _inputDecoration(),
                                borderRadius: BorderRadius.circular(12),
                                elevation: 2,
                                isExpanded: true,
                              ),
                            ],
                          ),
                        )
                      else if (uniqueSiteIds.length == 1)
                        // Dynamic Input Section (Date/Range)
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

                      // Report Type Selection
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

                      // Generate Report Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _openReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
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
                    ? Theme.of(context).primaryColor.withOpacity(0.1) // 10% opacity of primary
                    : Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selectedReportType == type
                    ? Theme.of(context).primaryColor
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
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedReportType == type
                          ? Theme.of(context).primaryColor.withOpacity(0.7)
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
              activeColor: Theme.of(context).primaryColor,
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
                  Icon(Icons.calendar_month, color: Theme.of(context).primaryColor),
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
