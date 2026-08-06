import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'daily_site_report.dart';
import 'site_expenses_reportpage.dart';
import 'site_summary_page.dart';
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
  final String loggedInUserName;
  final String ownerphonenumber;

  const CustomerInsightsScreen({
    super.key,
    required this.loggedInUserName,
    required this.ownerphonenumber,
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

  List<String> _ownerSiteIds = [];
  double _totalSiteCost = 0.0;
  bool _isLoadingCost = false;

  ReportType selectedReportType = ReportType.dailyExpense;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    await _loadUserDataAndFetchEntries();
  }

  Future<void> _loadUserDataAndFetchEntries() async {
    // Load user data from AuthService
    final auth = AuthService();
    if (mounted) {
      final data = auth.userData;
      setState(() {
        _ownerName = data['ownerName'];
        _ownerPhoneNumber = data['ownerPhoneNumber'];
        _userSiteId = data['siteId'];
      });

      // 1. Fetch all sites owned by this customer
      await _fetchOwnerSites();

      // 2. Fetch entries for those sites
      setState(() {
        supervisorEntriesFuture = _fetchSupervisorEntries();
      });
    }
  }

  Future<void> _fetchOwnerSites() async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();

      // Fetch siteId stored in AuthService
      final auth = AuthService();
      String? loginSiteId = auth.userData['siteId'];

      if (loginSiteId != null && loginSiteId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userSiteId = loginSiteId;
            _ownerSiteIds = [loginSiteId];
          });
        }
        await _calculateTotalCost();
        return;
      }

      // If no siteId found, we can't find sites
      if (mounted) setState(() => _ownerSiteIds = []);
    } catch (e) {
      print('Error fetching owner sites: $e');
    }
  }

  Future<void> _calculateTotalCost() async {
    final siteId = _userSiteId?.trim();

    if (siteId == null) return;

    // For Daily/Range reports, only calculate if dates are selected
    if (selectedReportType == ReportType.dailyExpense && selectedDate == null) {
      setState(() => _totalSiteCost = 0.0);
      return;
    }
    if (selectedReportType == ReportType.expenseRange &&
        (fromDate == null || toDate == null)) {
      setState(() => _totalSiteCost = 0.0);
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
            total += _toNum(data?['totalAmount']);
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
          _totalSiteCost = total;
          _isLoadingCost = false;
        });
      }
    } catch (e) {
      print("Error calculating cost: $e");
      if (mounted) setState(() => _isLoadingCost = false);
    }
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  Future<List<CustomerEntry>> _fetchSupervisorEntries() async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();

      if (_ownerSiteIds.isEmpty) return [];

      Query<Map<String, dynamic>> query = FirestoreService.getCollection(
        'siteSupervisorEntries',
      );

      // Strictly filter by owner's sites only
      query = query.where('siteId', whereIn: _ownerSiteIds);

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => CustomerEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching supervisor entries: $e');
      return [];
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
      _calculateTotalCost();
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
      _calculateTotalCost();
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
      _calculateTotalCost();
    }
  }

  void _openReport() {
    if (_userSiteId == null) return;

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
            supervisorId: '', // Customer doesn't need this
            siteId: _userSiteId!,
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
            siteId: _userSiteId!,
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
          builder: (_) => SiteSummaryPage(siteId: _userSiteId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'CST Insights',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20.0),
            bottomRight: Radius.circular(20.0),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: _userSiteId == null && (supervisorEntriesFuture == null)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Site Cost Card
                      _buildModernCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedReportType == ReportType.dailyExpense
                                      ? 'DAILY COST'
                                      : selectedReportType ==
                                            ReportType.expenseRange
                                      ? 'RANGE COST'
                                      : 'TOTAL SITE COST',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Overall Expenses',
                                  style: TextStyle(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                '₹ ${_totalSiteCost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

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

                      // Show empty state message at bottom if no entries found
                      if (_userSiteId != null)
                        FutureBuilder<List<CustomerEntry>>(
                          future: supervisorEntriesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                (!snapshot.hasData || snapshot.data!.isEmpty)) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Center(
                                  child: Text(
                                    'Note: No historical supervisor logs found for this site.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    ? Theme.of(context).primaryColor.withOpacity(
                        0.1,
                      ) // 10% opacity of primary
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
                  Icon(
                    Icons.calendar_month,
                    color: Theme.of(context).primaryColor,
                  ),
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
