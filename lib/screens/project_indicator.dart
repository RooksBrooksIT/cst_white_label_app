import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class ProjectIndicatorPage extends StatefulWidget {
  final String? siteId;
  final String projectName;
  final String siteName;
  final String ownerName;

  const ProjectIndicatorPage({
    super.key,
    required this.siteId,
    required this.projectName,
    required this.siteName,
    required this.ownerName,
  });

  @override
  State<ProjectIndicatorPage> createState() => _ProjectIndicatorPageState();
}

class _ProjectIndicatorPageState extends State<ProjectIndicatorPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? projectData;
  bool isLoading = true;
  String? errorMsg;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      if (widget.siteId == null || widget.siteId!.isEmpty) {
        setState(() { errorMsg = 'Site ID is missing'; isLoading = false; });
        return;
      }

      final col = FirestoreService.getCollection('projects');
      var query = await col.where('siteId', isEqualTo: widget.siteId).limit(1).get();
      if (query.docs.isEmpty) {
        query = await col.where('siteid', isEqualTo: widget.siteId).limit(1).get();
      }

      if (query.docs.isNotEmpty) {
        setState(() {
          projectData = query.docs.first.data();
          isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() { errorMsg = 'Project not found'; isLoading = false; });
      }
    } catch (e) {
      setState(() { errorMsg = 'Error loading data: $e'; isLoading = false; });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Project Performance',
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? _buildErrorView(theme)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProjectHeader(theme),
                        const SizedBox(height: 24),
                        _buildFinancialHealthIndicator(theme),
                        const SizedBox(height: 24),
                        _buildProjectDetails(theme),
                      ],
                    ),
                  ),
                ),
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
            Text(errorMsg!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlassButton(label: 'RETRY', onPressed: _fetchProjectData),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIVE PROJECT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(widget.projectName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.siteName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFinancialHealthIndicator(ThemeData theme) {
    final paid = _parseNum(projectData?['amountPaid']);
    final spent = _parseNum(projectData?['amountSpent']);
    final balance = _parseNum(projectData?['amountBalance']);
    final progress = paid > 0 ? (spent / paid).clamp(0.0, 1.0) : 0.0;
    
    Color healthColor = theme.primaryColor;
    String status = 'Stable';
    if (progress > 0.9) { healthColor = Colors.red; status = 'Critical'; }
    else if (progress > 0.75) { healthColor = Colors.orange; status = 'Warning'; }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FINANCIAL UTILIZATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: healthColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(status, style: TextStyle(color: healthColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: progress, backgroundColor: theme.colorScheme.surfaceVariant, color: healthColor, minHeight: 12, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(1)}% Utilized', style: theme.textTheme.bodySmall),
              Text('Remaining: ₹${balance.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 40),
          Row(
            children: [
              _statItem('Budget', '₹$paid', theme.primaryColor),
              _statItem('Spent', '₹$spent', healthColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildProjectDetails(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EXECUTION DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          _detailRow('Site Location', projectData?['siteLocation'] ?? '-', Icons.location_on_outlined),
          _detailRow('Project Owner', projectData?['ownerName'] ?? '-', Icons.person_outline),
          _detailRow('Start Date', _formatDate(projectData?['plannedStartDate']), Icons.calendar_today_outlined),
          _detailRow('Estimated Completion', _formatDate(projectData?['plannedEndDate']), Icons.event_available_outlined),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    if (d is Timestamp) return DateFormat('dd MMM yyyy').format(d.toDate());
    if (d is String) return d;
    return '-';
  }
}