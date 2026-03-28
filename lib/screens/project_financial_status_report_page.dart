import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'financial_status_report.dart';
import 'project_indicator.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class ProjectFinancialStatusReportPage extends StatefulWidget {
  const ProjectFinancialStatusReportPage({super.key});

  @override
  _ProjectFinancialStatusReportPageState createState() => _ProjectFinancialStatusReportPageState();
}

class _ProjectFinancialStatusReportPageState extends State<ProjectFinancialStatusReportPage> {
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
      final query = await FirestoreService.getCollection('projects')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();
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

    return GlassScaffold(
      title: 'Financial Status Entry',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(theme),
            const SizedBox(height: 24),
            _buildFormCard(theme),
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
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Select a site to generate comprehensive financial and performance analytics.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROJECT PARAMETERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          isLoadingSites
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  decoration: _inputDecoration('Select Site ID', Icons.search),
                  items: siteIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
                  onChanged: (v) {
                    setState(() => selectedSiteId = v);
                    if (v != null) _loadSiteDetails(v);
                  },
                ),
          const SizedBox(height: 16),
          TextField(
            controller: siteNameController,
            decoration: _inputDecoration('Site Name', Icons.location_on_outlined),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: projectNameController,
            decoration: _inputDecoration('Project Name', Icons.work_outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ownerNameController,
            decoration: _inputDecoration('Owner Name', Icons.person_outline),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showFinancialStatus() {
    if (selectedSiteId == null || siteNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a site first.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a site first.')));
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