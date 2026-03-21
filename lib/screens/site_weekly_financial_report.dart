import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'site_weekly_financial_report2.dart';

class SiteWeeklyFinancialReports extends StatefulWidget {
  const SiteWeeklyFinancialReports({super.key});

  @override
  State<SiteWeeklyFinancialReports> createState() =>
      _SiteWeeklyFinancialReportState();
}

class _SiteWeeklyFinancialReportState
    extends State<SiteWeeklyFinancialReports> {
  // Color constants
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLightColor = const Color(0xFF1e4a8e);
  final Color accentColor = const Color(0xFF4285F4);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color secondaryTextColor = const Color(0xFF7f8c8d);

  // List to hold all documents
  List<Map<String, dynamic>> supervisorMaps = [];
  int selectedIndex = 0;
  bool isLoading = true;

  // New state for year, week, and month
  int? _selectedYear = DateTime.now().year;
  int? _selectedWeek;
  int? _selectedMonth = DateTime.now().month;
  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    fetchSupervisorData();
  }

  Future<void> fetchSupervisorData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('Firestore query timeout - returning empty result');
              throw TimeoutException(
                'Query timeout',
                const Duration(seconds: 10),
              );
            },
          );

      if (!mounted) return;

      supervisorMaps = snapshot.docs.isEmpty
          ? []
          : snapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          supervisorMaps = [];
          selectedIndex = 0;
        });
      }
    } catch (e) {
      print('Error fetching supervisor data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          selectedIndex = 0;
          supervisorMaps = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weekly Financial Report',
          style: TextStyle( fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(),
      ),
      backgroundColor: backgroundColor,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : supervisorMaps.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Sites Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No site supervisor data available',
                    style: TextStyle(fontSize: 14, color: secondaryTextColor),
                  ),
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bar_chart,
                                size: 30,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Site Weekly Financial Report',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // SECTION 1: Select Site
                      Text(
                        'Select Site',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: selectedIndex < supervisorMaps.length
                              ? selectedIndex
                              : null,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            labelText: 'Choose Site',
                            labelStyle: TextStyle(color: secondaryTextColor),
                          ),
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: primaryColor,
                          ),
                          items: List.generate(
                            supervisorMaps.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(
                                supervisorMaps[index]['site'] ?? 'Site',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (int? newIndex) {
                            if (newIndex != null &&
                                newIndex < supervisorMaps.length) {
                              setState(() {
                                selectedIndex = newIndex;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // SECTION 2: Financial Details
                      Text(
                        'Select Period',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Year selection
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            labelText: 'Select Year',
                            labelStyle: TextStyle(color: secondaryTextColor),
                          ),
                          items: List.generate(
                            5,
                            (i) => DropdownMenuItem(
                              value: DateTime.now().year - 2 + i,
                              child: Text(
                                (DateTime.now().year - 2 + i).toString(),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (int? val) {
                            setState(() {
                              _selectedYear = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Month selection
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            labelText: 'Select Month',
                            labelStyle: TextStyle(color: secondaryTextColor),
                          ),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(
                                _monthNames[i],
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (int? val) {
                            setState(() {
                              _selectedMonth = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Week selection
                      Text(
                        'Select Week',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          5,
                          (i) => ChoiceChip(
                            label: Text(
                              'Week ${i + 1}',
                              style: TextStyle(
                                color: _selectedWeek == i + 1
                                    ? Colors.white
                                    : primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: _selectedWeek == i + 1,
                            selectedColor: primaryColor,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            onSelected: (selected) {
                              setState(() {
                                _selectedWeek = selected ? i + 1 : null;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: primaryColor.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Selected period summary
                      if (_selectedWeek != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Period:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Year: $_selectedYear',
                                style: TextStyle(color: textColor),
                              ),
                              Text(
                                'Month: ${_selectedMonth != null ? _monthNames[_selectedMonth! - 1] : ''}',
                                style: TextStyle(color: textColor),
                              ),
                              Text(
                                'Week: Week $_selectedWeek',
                                style: TextStyle(color: textColor),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (supervisorMaps.isEmpty ||
                                    selectedIndex >= supervisorMaps.length) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'No site available to select.',
                                      ),
                                      backgroundColor: Colors.red[400],
                                    ),
                                  );
                                  return;
                                }
                                if (_selectedYear == null ||
                                    _selectedMonth == null ||
                                    _selectedWeek == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select year, month, and week.',
                                      ),
                                      backgroundColor: Colors.orange[400],
                                    ),
                                  );
                                  return;
                                }
                                final selectedSite =
                                    supervisorMaps[selectedIndex];
                                final monthName =
                                    _monthNames[_selectedMonth! - 1].substring(
                                      0,
                                      3,
                                    );
                                final paymentPeriod =
                                    "${_selectedYear}_${monthName}_Week$_selectedWeek";

                                final query = await FirebaseFirestore.instance
                                    .collection('siteSupervisorPayments')
                                    .where(
                                      'paymentPeriod',
                                      isEqualTo: paymentPeriod,
                                    )
                                    .limit(1)
                                    .get()
                                    .timeout(
                                      const Duration(seconds: 10),
                                      onTimeout: () {
                                        throw TimeoutException(
                                          'Query timeout',
                                          const Duration(seconds: 10),
                                        );
                                      },
                                    );

                                try {
                                  if (query.docs.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SiteWeeklyFinancialReport2(
                                              siteDetails: selectedSite,
                                              paymentPeriod: paymentPeriod,
                                            ),
                                      ),
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          'No Data Found',
                                          style: TextStyle(color: primaryColor),
                                        ),
                                        content: const Text(
                                          'No report is available for the selected period.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              'OK',
                                              style: TextStyle(
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Error loading report: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Failed to load report. Please try again.',
                                      ),
                                      backgroundColor: Colors.red[400],
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Generate Report',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
}
