import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/screens/reports/site_status_report_page.dart';
import 'package:ebricks/widgets/glass_card.dart';
import 'package:ebricks/utils/app_theme.dart';

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
      final results = await Future.wait([
        FirestoreService.getCollection('projects').get(),
        FirestoreService.getCollection('Site').get(),
      ]);

      final projectsSnapshot = results[0];
      final sitesSnapshot = results[1];

      Set<String> uniqueStatuses = {};
      double totalBudget = 0.0;
      double totalSpent = 0.0;

      final seenDocIds = <String>{};
      final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (var doc in [...projectsSnapshot.docs, ...sitesSnapshot.docs]) {
        if (seenDocIds.add(doc.id)) {
          allDocs.add(doc);
        }
      }

      for (var doc in allDocs) {
        final data = doc.data();

        final statusVal = (data['currentStatus'] ?? data['status'] ?? data['siteStatus'])?.toString();
        if (statusVal != null && statusVal.trim().isNotEmpty) {
          uniqueStatuses.add(statusVal.trim());
        }

        final budget =
            double.tryParse(data['projectBudget']?.toString() ?? data['budget']?.toString() ?? '0') ?? 0.0;
        final spent =
            double.tryParse(data['amountSpent']?.toString() ?? data['spent']?.toString() ?? '0') ?? 0.0;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site/Project Status Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _errorMessage != null
                  ? _buildErrorView()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
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
                            'Select a project status to generate insights',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Status Selection Card
                          _buildSelectorSection(theme),
                          const SizedBox(height: 24),

                          // Generate Report Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.analytics_rounded, size: 20),
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
                                elevation: 3,
                              ),
                              onPressed: (_selectedStatus == null || _statusOptions.isEmpty)
                                  ? null
                                  : _handleReport,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Info Card
                          GlassCard(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Select a project status to generate detailed status reports',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildSelectorSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            dropdownColor: theme.cardColor,
            iconEnabledColor: primaryColor,
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(context),
            borderRadius: BorderRadius.circular(12),
            items: _statusOptions
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedStatus = v),
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
