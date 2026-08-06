import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/daily_site_report.dart';
import 'package:demo_cst/screens/site_expenses_reportpage.dart';
import 'package:demo_cst/screens/site_summary_page.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/list_extensions.dart';

import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

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
    if (doc.data() == null) return SupervisorEntry(supervisorId: '');
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
    try {
      final querySnapshot = await FirestoreService.getCollection('siteSupervisorEntries').get();
      final List<SupervisorEntry> entries = querySnapshot.docs
          .map((doc) => SupervisorEntry.fromFirestore(doc))
          .toList();

      final sitesSnapshot = await FirestoreService.getCollection('Site').get();
      final Set<String> loggedSiteIds = entries
          .where((e) => e.siteId != null && e.siteId!.isNotEmpty)
          .map((e) => e.siteId!)
          .toSet();

      for (var doc in sitesSnapshot.docs) {
        final sId = doc.id;
        if (!loggedSiteIds.contains(sId)) {
          final sData = doc.data();
          entries.add(SupervisorEntry(
            supervisorId: 'Not Assigned',
            siteId: sId,
            siteName: sData['siteName']?.toString() ?? sId,
          ));
        }
      }

      return entries;
    } catch (e) {
      debugPrint('Error fetching supervisor entries: $e');
      return [];
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              onSurface: colorScheme.onSurface,
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              onSurface: colorScheme.onSurface,
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              onSurface: colorScheme.onSurface,
            ),
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return GlassScaffold(
      title: 'Expenses Report',
      appBarBackgroundColor: Theme.of(context).colorScheme.primary,
      appBarForegroundColor: Theme.of(context).colorScheme.onPrimary,
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: FutureBuilder<List<SupervisorEntry>>(
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
                    style: TextStyle(color: theme.colorScheme.onSurface),
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

              if (uniqueSiteIds.isNotEmpty) {
                selectedSupervisorEntry ??= supervisorEntries.firstWhereOrNull(
                  (entry) => entry.siteId == uniqueSiteIds.first,
                ) ?? supervisorEntries.firstOrNull;
              } else {
                selectedSupervisorEntry ??= supervisorEntries.firstOrNull;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Generate Reports',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a site and report type to generate insights',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

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
                              color: colorScheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedSupervisorEntry?.siteId,
                            items: uniqueSiteIds.map((siteId) {
                              return DropdownMenuItem<String>(
                                value: siteId,
                                child: Text(
                                  siteId,
                                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
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
                            decoration: _inputDecoration(context),
                            borderRadius: BorderRadius.circular(12),
                            elevation: 2,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                            dropdownColor: theme.cardColor,
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
                              color: colorScheme.primary,
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

                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          label: 'GENERATE REPORT',
                          onPressed: _openReport,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return GlassCard(
      child: child,
    );
  }

  Widget _buildReportOption({
    required ReportType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    ? colorScheme.primary.withOpacity(0.1)
                    : theme.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selectedReportType == type ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
                      fontWeight: FontWeight.w600,
                      color: selectedReportType == type ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedReportType == type
                          ? colorScheme.primary.withOpacity(0.7)
                          : colorScheme.onSurfaceVariant,
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
              activeColor: colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
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
                      color: date != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(Icons.calendar_month, color: colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: theme.cardColor,
    );
  }
}