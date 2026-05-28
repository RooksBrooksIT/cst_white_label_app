import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'financial_status_report.dart';
import 'project_indicator.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class customerProjectFinancialStatusReportPage extends StatefulWidget {
  @override
  _customerProjectFinancialStatusReportPageState createState() =>
      _customerProjectFinancialStatusReportPageState();
}

class _customerProjectFinancialStatusReportPageState
    extends State<customerProjectFinancialStatusReportPage> {
  String? selectedSiteId;
  final projectNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final siteNameController = TextEditingController();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  String? _userSiteId;

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
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final auth = AuthService();
    _userSiteId = auth.userData['siteId'];
    await _fetchSiteIds();
  }

  Future<void> _fetchSiteIds() async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();

      // If we have _userSiteId from auth, use it directly
      if (_userSiteId != null && _userSiteId!.isNotEmpty) {
        if (mounted) {
          setState(() {
            siteIds = [_userSiteId!];
            selectedSiteId = _userSiteId;
            isLoadingSites = false;
          });
          await _loadSiteDetails(_userSiteId!);
        }
        return;
      }

      Query<Map<String, dynamic>> query = FirestoreService.getCollection(
        'projects',
      );

      final snapshot = await query.get();
      final ids = snapshot.docs
          .map(
            (doc) => doc.data() is Map
                ? (doc.data() as Map)['siteId']?.toString()
                : null,
          )
          .where((v) => v != null && v!.trim().isNotEmpty)
          .map((v) => v!)
          .toSet()
          .toList();
      ids.sort();

      if (mounted) {
        setState(() {
          siteIds = ids;
          isLoadingSites = false;
          if (_userSiteId != null && siteIds.contains(_userSiteId)) {
            selectedSiteId = _userSiteId;
            _loadSiteDetails(_userSiteId!);
          } else if (siteIds.isNotEmpty) {
            selectedSiteId = siteIds.first;
            _loadSiteDetails(siteIds.first);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();
      final query = await FirestoreService.getCollection(
        'projects',
      ).where('siteId', isEqualTo: siteId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (mounted) {
          setState(() {
            siteNameController.text = data['siteId']?.toString() ?? '';
            projectNameController.text = data['projectName']?.toString() ?? '';
            ownerNameController.text = data['ownerName']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      // Handle error quietly
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Project Status Report',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_userSiteId != null) _buildUserSiteHeader(theme),
            const SizedBox(height: 24),
            _buildDetailsCard(theme),
            const SizedBox(height: 32),
            GlassButton(
              label: 'FINANCIAL STATUS',
              onPressed: _showFinancialStatus,
              icon: Icons.pie_chart_outline,
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: 'PROJECT INDICATOR',
              onPressed: _showProjectIndicator,
              icon: Icons.analytics_outlined,
              isSecondary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSiteHeader(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.business_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR SITE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  _userSiteId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROJECT INFORMATION',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          _displayField('Site ID', siteNameController.text, Icons.tag),
          const SizedBox(height: 16),
          _displayField(
            'Project Name',
            projectNameController.text,
            Icons.assignment_outlined,
          ),
          const SizedBox(height: 16),
          _displayField(
            'Owner Name',
            ownerNameController.text,
            Icons.person_outline,
          ),
        ],
      ),
    );
  }

  Widget _displayField(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFinancialStatus() {
    if (selectedSiteId == null) return;
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
    if (selectedSiteId == null) return;
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
