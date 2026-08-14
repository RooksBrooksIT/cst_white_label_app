import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/reports/financial_status_report.dart';
import 'package:demo_cst/screens/reports/project_indicator.dart';
import '/services/firestore_service.dart';
import '/widgets/glass_scaffold.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import '/utils/app_theme.dart';

class ProjectFinancialStatusReportPage extends StatefulWidget {
  const ProjectFinancialStatusReportPage({super.key});

  @override
  _ProjectFinancialStatusReportPageState createState() =>
      _ProjectFinancialStatusReportPageState();
}

class _ProjectFinancialStatusReportPageState
    extends State<ProjectFinancialStatusReportPage> {
  String? selectedSiteId;
  final projectNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final siteNameController = TextEditingController();

  List<String> siteIds = [];
  bool isLoadingSites = true;

  @override
  void dispose() {
    projectNameController.dispose();
    ownerNameController.dispose();
    siteNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchSiteIds();
  }

  Future<void> _fetchSiteIds() async {
    try {
      final snapshot = await FirestoreService.getCollection('projects').get();
      final ids = snapshot.docs
          .map((doc) => doc.data()['siteId']?.toString())
          .where((v) => v != null && v!.trim().isNotEmpty)
          .map((v) => v!)
          .toSet()
          .toList();
      ids.sort();
      setState(() {
        siteIds = ids;
        isLoadingSites = false;
      });
    } catch (e) {
      setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      final query = await FirestoreService.getCollection(
        'projects',
      ).where('siteId', isEqualTo: siteId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        siteNameController.text = data['siteId']?.toString() ?? '';
        projectNameController.text = data['projectName']?.toString() ?? '';
        ownerNameController.text = data['ownerName']?.toString() ?? '';
      }
    } catch (e) {
      // Handle error quietly or show snackbar
    }
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
          title: 'Financial Status Entry',
          appBarForegroundColor: Colors.white,
          onBack: () => Navigator.pop(context),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(theme, cardAccent),
                    const SizedBox(height: 24),
                    _buildFormCard(theme, cardAccent),
                    const SizedBox(height: 32),
                    GlassButton(
                      label: 'VIEW FINANCIAL STATUS',
                      onPressed: _showFinancialStatus,
                      icon: Icons.pie_chart_outline,
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'VIEW PROJECT INDICATOR',
                      onPressed: _showProjectIndicator,
                      icon: Icons.analytics_outlined,
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

  Widget _buildInfoCard(ThemeData theme, Color cardAccent) {
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cardAccent, size: 26),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Select a site to generate comprehensive financial and performance analytics.',
              style: TextStyle(
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

  Widget _buildFormCard(ThemeData theme, Color cardAccent) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECT PARAMETERS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cardAccent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          isLoadingSites
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  iconEnabledColor: cardAccent,
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    'Select Site ID',
                    Icons.search,
                    cardAccent,
                  ),
                  items: siteIds
                      .map(
                        (id) => DropdownMenuItem(
                          value: id,
                          child: Text(
                            id,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0A183D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => selectedSiteId = v);
                    if (v != null) _loadSiteDetails(v);
                  },
                ),
          const SizedBox(height: 16),
          TextField(
            controller: siteNameController,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              'Site Name',
              Icons.location_on_outlined,
              cardAccent,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: projectNameController,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              'Project Name',
              Icons.work_outline,
              cardAccent,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ownerNameController,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              'Owner Name',
              Icons.person_outline,
              cardAccent,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color cardAccent) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF5A759E),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: cardAccent),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showFinancialStatus() {
    if (selectedSiteId == null || siteNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialStatusReportPage(
          siteId: selectedSiteId!,
          siteName: siteNameController.text.trim(),
          projectName: projectNameController.text.trim(),
          ownerName: ownerNameController.text.trim(),
        ),
      ),
    );
  }

  void _showProjectIndicator() {
    if (selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectIndicatorPage(
          siteId: selectedSiteId,
          siteName: siteNameController.text.trim(),
          projectName: projectNameController.text.trim(),
          ownerName: ownerNameController.text.trim(),
        ),
      ),
    );
  }
}
