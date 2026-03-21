import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/daily_site_report.dart';
import 'package:demo_cst/screens/site_expenses_reportpage.dart';
import 'package:demo_cst/screens/site_summary_page.dart';
import 'package:intl/intl.dart';


// --- SupervisorEntry Model ---
class SupervisorEntry {
  final String supervisorId;
  final String? siteId;
  final String? siteName;
  final DateTime? date;
  final num? amount;
  final num? totalamount;

  SupervisorEntry({
    required this.supervisorId,
    this.siteId,
    this.siteName,
    this.date,
    this.amount,
    this.totalamount,
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
    );
  }
}

enum ReportType {
  dailyExpense,
  expenseRange,
  siteSummary,
}

class OrganizationInsightsScreen extends StatefulWidget {
  const OrganizationInsightsScreen({super.key});

  @override
  State<OrganizationInsightsScreen> createState() =>
      _OrganizationInsightsScreenState();
}

class _OrganizationInsightsScreenState
    extends State<OrganizationInsightsScreen> {
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4a7cda);
  static const Color backgroundColor = Color(0xFFf8f9fa);
  static const Color textColor = Color(0xFF2c3e50);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF2e7d32);
  static const Color warningColor = Color(0xFFed6c02);

  late Future<List<SupervisorEntry>> supervisorEntriesFuture;
  SupervisorEntry? selectedSupervisorEntry;

  ReportType selectedReportType = ReportType.dailyExpense;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    supervisorEntriesFuture = _fetchSupervisorEntriesFromFirestore();
  }

  Future<List<SupervisorEntry>> _fetchSupervisorEntriesFromFirestore() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorEntries')
        .get();
    return querySnapshot.docs
        .map((doc) => SupervisorEntry.fromFirestore(doc))
        .toList();
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
            ), dialogTheme: DialogThemeData(),
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
            ), dialogTheme: DialogThemeData(),
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
            ), dialogTheme: DialogThemeData(),
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
    if (selectedSupervisorEntry == null) return;

    if (selectedReportType == ReportType.dailyExpense) {
      if (selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a date'),
            backgroundColor: warningColor,
          ),
        );
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
          SnackBar(
            content: Text('Please select both dates'),
            backgroundColor: warningColor,
          ),
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
          builder: (_) => SiteSummaryPage(
            siteId: selectedSupervisorEntry!.siteId!,
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
          'CST Insights',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(),
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
          final supervisorEntries = snapshot.data!;
          final uniqueSiteIds = supervisorEntries
              .where(
                  (entry) => entry.siteId != null && entry.siteId!.isNotEmpty)
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
                // Header
                Text(
                  'Generate Reports',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select a site and report type to generate insights',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 24),

                // Site Selection Card
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
                        value: selectedSupervisorEntry?.siteId,
                        items: uniqueSiteIds.map((siteId) {
                          return DropdownMenuItem<String>(
                            value: siteId,
                            child: Text(
                              siteId,
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newSiteId) {
                          setState(() {
                            selectedSupervisorEntry =
                                supervisorEntries.firstWhere(
                              (entry) => entry.siteId == newSiteId,
                              orElse: () => supervisorEntries.first,
                            );
                          });
                        },
                        decoration: _inputDecoration(),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 2,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        dropdownColor: cardColor,
                      ),
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
                      Divider(height: 20, thickness: 0.5, ),
                      _buildReportOption(
                        type: ReportType.expenseRange,
                        icon: Icons.date_range,
                        title: 'Expense Range',
                        subtitle: 'View expenses between dates',
                      ),
                      Divider(height: 20, thickness: 0.5, ),
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
                    onPressed: _openReport,
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
                border: Border.all(color: Colors.grey),
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
        borderSide: BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey),
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