import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/reports/site_status_report_page.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SiteStatusReportScreen extends StatefulWidget {
  const SiteStatusReportScreen({super.key});

  @override
  State<SiteStatusReportScreen> createState() => _SiteStatusReportScreenState();
}

class _SiteStatusReportScreenState extends State<SiteStatusReportScreen> {
  String? _selectedStatus;
  List<String> _statusOptions = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _spendingPercentage = 0.0;
  double _budgetAmount = 0.0;
  double _spentAmount = 0.0;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      final projectsSnapshot = await FirestoreService.getCollection(
        'projects',
      ).get();

      Set<String> uniqueStatuses = {};
      double totalBudget = 0.0;
      double totalSpent = 0.0;

      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();

        final statusVal = (data['currentStatus'] ?? data['status'])?.toString();
        if (statusVal != null && statusVal.trim().isNotEmpty) {
          uniqueStatuses.add(statusVal.trim());
        }

        final budget =
            double.tryParse(data['projectBudget']?.toString() ?? '0') ?? 0.0;
        final spent =
            double.tryParse(data['amountSpent']?.toString() ?? '0') ?? 0.0;

        totalBudget += budget;
        totalSpent += spent;
      }

      // Also fetch custom user-defined statuses from projectStatus collection
      try {
        final statusSnapshot = await FirestoreService.getCollection(
          'projectStatus',
        ).get();
        for (var doc in statusSnapshot.docs) {
          final data = doc.data();
          final statusVal = (data['projectState'] ?? data['projectStatus'])?.toString().trim();
          if (statusVal != null && statusVal.isNotEmpty) {
            uniqueStatuses.add(statusVal);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _budgetAmount = totalBudget;
          _spentAmount = totalSpent;
          _spendingPercentage = _budgetAmount > 0
              ? _spentAmount / _budgetAmount
              : 0.0;
          _statusOptions = uniqueStatuses.toList()..sort();
          _selectedStatus = _statusOptions.isNotEmpty ? _statusOptions.first : null;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects status data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleReport() {
    if (!mounted) return;
    if (_selectedStatus != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SiteStatusReportPage(
            status: _selectedStatus!,
            budgetData: {
              'percentage': _spendingPercentage,
              'budget': _budgetAmount,
              'spent': _spentAmount,
              'status': _getSpendingStatus(_spendingPercentage),
            },
          ),
        ),
      );
    }
  }

  String _getSpendingStatus(double percentage) {
    if (percentage < 0.25) return 'On Budget';
    if (percentage < 0.5) return 'Moderate Spending';
    if (percentage < 0.75) return 'High Spending';
    return 'Critical Spending';
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Status Report',
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
              maxWidth: isDesktop ? 800.0 : (isTablet ? 650.0 : double.infinity),
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _errorMessage != null
                    ? _buildErrorView()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(isDesktop ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 20),
                            _buildSelectorSection(),
                            const SizedBox(height: 28),

                            // Generate Report Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_rounded, size: 20),
                                label: const Text(
                                  'GENERATE REPORT',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: (_selectedStatus == null || _statusOptions.isEmpty)
                                    ? null
                                    : _handleReport,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Cancel Button
                            SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                label: const Text(
                                  'CANCEL',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0A183D),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A183D),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _fetchProjectData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insights_rounded,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Track project status and financial health. Select a status to generate a detailed analytics report.',
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorSection() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTER BY STATUS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF0A183D),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: Colors.white,
              iconEnabledColor: primaryColor,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Project State',
                labelStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(Icons.flag_rounded, color: primaryColor, size: 20),
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStatus = v),
            ),
          ],
        ),
      ),
    );
  }
}
