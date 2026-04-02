import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
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
      final snapshot = await FirestoreService.getCollection('siteSupervisorMap')
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
                .map((doc) => doc.data())
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Weekly Financial Report',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (supervisorMaps.isEmpty) {
      return _buildEmptyState(context);
    }
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: theme.dividerColor),
              ),
              child: _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No Sites Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No site supervisor data available',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Select Site',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: selectedIndex < supervisorMaps.length ? selectedIndex : null,
          decoration: _inputDecoration(context, 'Choose Site'),
          dropdownColor: theme.cardColor,
          isExpanded: true,
          items: List.generate(
            supervisorMaps.length,
            (index) => DropdownMenuItem(
              value: index,
              child: Text(
                supervisorMaps[index]['site'] ?? 'Site',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
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
        const SizedBox(height: 32),
        Text(
          'Select Period',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedYear,
          decoration: _inputDecoration(context, 'Select Year'),
          dropdownColor: theme.cardColor,
          style: TextStyle(color: colorScheme.onSurface),
          items: List.generate(
            5,
            (i) => DropdownMenuItem(
              value: DateTime.now().year - 2 + i,
              child: Text((DateTime.now().year - 2 + i).toString()),
            ),
          ),
          onChanged: (val) => setState(() => _selectedYear = val),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedMonth,
          decoration: _inputDecoration(context, 'Select Month'),
          dropdownColor: theme.cardColor,
          style: TextStyle(color: colorScheme.onSurface),
          items: List.generate(
            12,
            (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i])),
          ),
          onChanged: (val) => setState(() => _selectedMonth = val),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Week',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            5,
            (i) => ChoiceChip(
              label: Text('Week ${i + 1}'),
              selected: _selectedWeek == i + 1,
              onSelected: (selected) {
                setState(() => _selectedWeek = selected ? i + 1 : null);
              },
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceVariant,
              labelStyle: TextStyle(
                color: _selectedWeek == i + 1
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: _selectedWeek == i + 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              showCheckmark: false,
            ),
          ),
        ),
        const SizedBox(height: 40),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _onGenerateReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Generate Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              side: BorderSide(color: theme.dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _showNoDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Data Found'),
        content: const Text('No report is available for the selected period.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
