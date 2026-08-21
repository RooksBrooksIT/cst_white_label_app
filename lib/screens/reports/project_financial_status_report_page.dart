import 'package:flutter/material.dart';
import 'package:demo_cst/screens/reports/financial_status_report.dart';
import 'package:demo_cst/screens/reports/project_indicator.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

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
      // Handle error quietly
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Financial Status Entry',
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(primaryColor),
                  const SizedBox(height: 20),
                  _buildFormCard(primaryColor),
                  const SizedBox(height: 28),

                  // View Financial Status Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.pie_chart_rounded, size: 20),
                      label: const Text(
                        'VIEW FINANCIAL STATUS',
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
                      onPressed: _showFinancialStatus,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // View Project Indicator Button
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.analytics_rounded, size: 20, color: primaryColor),
                      label: const Text(
                        'VIEW PROJECT INDICATOR',
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
                      onPressed: _showProjectIndicator,
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

  Widget _buildInfoCard(Color primaryColor) {
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
          Icon(Icons.info_rounded, color: primaryColor, size: 24),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Select a site to generate comprehensive financial and performance analytics.',
              style: TextStyle(
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

  Widget _buildFormCard(Color primaryColor) {
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
              'PROJECT PARAMETERS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF0A183D),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            isLoadingSites
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ))
                : DropdownButtonFormField<String>(
                    value: selectedSiteId,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    iconEnabledColor: primaryColor,
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _inputDecoration(
                      'Select Site ID',
                      Icons.search_rounded,
                      primaryColor,
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
            const SizedBox(height: 14),
            TextField(
              controller: siteNameController,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration(
                'Site Name',
                Icons.location_on_rounded,
                primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: projectNameController,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration(
                'Project Name',
                Icons.work_rounded,
                primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ownerNameController,
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration(
                'Owner Name',
                Icons.person_rounded,
                primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color primaryColor) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
