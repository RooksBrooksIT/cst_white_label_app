import 'package:flutter/material.dart';
import '/services/firestore_service.dart';
import 'package:demo_cst/screens/reports/site_status_report_page.dart';
import '/widgets/glass_scaffold.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import '/utils/app_theme.dart';

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
        final data = doc.data() as Map<String, dynamic>;

        // Extract status
        final statusVal = (data['currentStatus'] ?? data['status'])?.toString();
        if (statusVal != null && statusVal.trim().isNotEmpty) {
          uniqueStatuses.add(statusVal.trim());
        }

        // Aggregate finances
        final budget =
            double.tryParse(data['projectBudget']?.toString() ?? '0') ?? 0.0;
        final spent =
            double.tryParse(data['amountSpent']?.toString() ?? '0') ?? 0.0;

        totalBudget += budget;
        totalSpent += spent;
      }

      // Ensure there is always a fallback list of statuses to pick from if empty
      if (uniqueStatuses.isEmpty) {
        uniqueStatuses.addAll([
          'In-Progress',
          'Pending',
          'Planning',
          'On-Hold',
          'Complete',
        ]);
      }

      if (mounted) {
        setState(() {
          _budgetAmount = totalBudget;
          _spentAmount = totalSpent;
          _spendingPercentage = _budgetAmount > 0
              ? _spentAmount / _budgetAmount
              : 0.0;
          _statusOptions = uniqueStatuses.toList()..sort();
          _selectedStatus = _statusOptions.first;
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
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final cardAccent = AppTheme.getCardAccent(primaryColor);

        return GlassScaffold(
          title: 'Site Status Report',
          appBarForegroundColor: Colors.white,
          onBack: () => Navigator.pop(context),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _buildErrorView(theme)
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(theme, cardAccent),
                          const SizedBox(height: 24),
                          _buildSelectorSection(theme, cardAccent),
                          const SizedBox(height: 40),
                          GlassButton(
                            label: 'GENERATE REPORT',
                            onPressed:
                                (_selectedStatus == null || _statusOptions.isEmpty)
                                ? null
                                : _handleReport,
                          ),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: 'CANCEL',
                            onPressed: () => Navigator.pop(context),
                            isSecondary: true,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            GlassButton(label: 'RETRY', onPressed: _fetchProjectData),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, Color cardAccent) {
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: cardAccent, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Track project status and financial health. Select a status to generate a detailed analytics report.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorSection(ThemeData theme, Color cardAccent) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY STATUS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cardAccent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            dropdownColor: Colors.white,
            iconEnabledColor: cardAccent,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Project State',
              labelStyle: const TextStyle(
                color: Color(0xFF5A759E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(Icons.flag_outlined, color: cardAccent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
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
    );
  }
}
