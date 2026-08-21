import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'dart:async';
import 'package:demo_cst/screens/reports/site_weekly_financial_report2.dart';

class SiteWeeklyFinancialReports extends StatefulWidget {
  const SiteWeeklyFinancialReports({super.key});

  @override
  State<SiteWeeklyFinancialReports> createState() =>
      _SiteWeeklyFinancialReportState();
}

class _SiteWeeklyFinancialReportState
    extends State<SiteWeeklyFinancialReports> {
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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    fetchSupervisorData();
  }

  Future<void> fetchSupervisorData() async {
    try {
      final snapshot = await FirestoreService.getCollection('siteSupervisorMap')
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

      if (!mounted) return;

      supervisorMaps = snapshot.docs.isEmpty
          ? []
          : snapshot.docs.map((doc) => doc.data()).toList();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching supervisor data: $e');
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
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Weekly Financial Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 650.0,
            ),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (supervisorMaps.isEmpty) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Weekly Financial Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select site, year, month & week to compile financial overview',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 1: SITE & SUPERVISOR
          _buildSectionHeader(
            title: '1. Select Site & Supervisor',
            subtitle: 'Choose target project site for reporting',
            icon: Icons.place_rounded,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildSiteDropdown(),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // SECTION 2: YEAR & MONTH
          _buildSectionHeader(
            title: '2. Select Financial Year & Month',
            subtitle: 'Choose target year and month',
            icon: Icons.calendar_month_rounded,
            color: Colors.indigo,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildYearDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildMonthDropdown()),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // SECTION 3: WEEK
          _buildSectionHeader(
            title: '3. Select Week',
            subtitle: 'Pick week number to generate report',
            icon: Icons.date_range_rounded,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildWeekChips(),
          const SizedBox(height: 28),

          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16),
            Text(
              'No Sites Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A183D),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No site supervisor mappings available in system.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Site *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: selectedIndex < supervisorMaps.length ? selectedIndex : null,
          decoration: _inputDecoration('Choose Site', Icons.place_rounded),
          dropdownColor: Colors.white,
          isExpanded: true,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          items: List.generate(
            supervisorMaps.length,
            (index) => DropdownMenuItem(
              value: index,
              child: Text(
                supervisorMaps[index]['site'] ?? 'Site',
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          onChanged: (int? newIndex) {
            if (newIndex != null) {
              setState(() => selectedIndex = newIndex);
            }
          },
        ),
      ],
    );
  }

  Widget _buildYearDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Year *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _selectedYear,
          isExpanded: true,
          decoration: _inputDecoration('Select Year', Icons.calendar_today_rounded),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          items: List.generate(
            5,
            (i) => DropdownMenuItem(
              value: DateTime.now().year - 2 + i,
              child: Text(
                (DateTime.now().year - 2 + i).toString(),
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          onChanged: (val) => setState(() {
            _selectedYear = val;
            _selectedWeek = null;
          }),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _selectedMonth,
          isExpanded: true,
          decoration: _inputDecoration('Select Month', Icons.calendar_month_rounded),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          items: List.generate(
            12,
            (i) => DropdownMenuItem(
              value: i + 1,
              child: Text(
                _monthNames[i],
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          onChanged: (val) => setState(() {
            _selectedMonth = val;
            _selectedWeek = null;
          }),
        ),
      ],
    );
  }

  Widget _buildWeekChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        5,
        (i) {
          final isSelected = _selectedWeek == i + 1;
          return ChoiceChip(
            label: Text('Week ${i + 1}'),
            selected: isSelected,
            onSelected: (selected) {
              setState(() => _selectedWeek = selected ? i + 1 : null);
            },
            selectedColor: primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
              width: isSelected ? 1.8 : 1.0,
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0A183D),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _onGenerateReport,
              icon: const Icon(Icons.assessment_rounded, size: 20),
              label: const Text(
                'Generate Financial Report',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: primaryColor.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A183D),
                side: const BorderSide(
                  color: Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  Future<void> _onGenerateReport() async {
    if (supervisorMaps.isEmpty || selectedIndex >= supervisorMaps.length) {
      _showSnackBar('No sites available to select.', Colors.red);
      return;
    }
    if (_selectedYear == null ||
        _selectedMonth == null ||
        _selectedWeek == null) {
      _showSnackBar('Please select year, month, and week.', Colors.orange);
      return;
    }

    final selectedSite = supervisorMaps[selectedIndex];
    final monthName = _monthNames[_selectedMonth! - 1].substring(0, 3);
    final paymentPeriod = "${_selectedYear}_${monthName}_Week$_selectedWeek";

    try {
      final query =
          await FirestoreService.getCollection('siteSupervisorPayments')
              .where('paymentPeriod', isEqualTo: paymentPeriod)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (query.docs.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SiteWeeklyFinancialReport2(
              siteDetails: selectedSite,
              paymentPeriod: paymentPeriod,
            ),
          ),
        );
      } else {
        _showNoDataDialog();
      }
    } catch (e) {
      _showSnackBar('Failed to load report. Please try again.', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showNoDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'No Data Found',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
        ),
        content: const Text(
          'No report is available for the selected period.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
