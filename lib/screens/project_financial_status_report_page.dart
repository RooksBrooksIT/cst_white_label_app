import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/financial_status_report.dart';
import 'package:demo_cst/screens/project_indicator.dart';
import 'package:demo_cst/services/firestore_service.dart';


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

  // Define our color scheme
  final Color primaryColor = const Color(0xFF0b3470);
  final Color secondaryColor = const Color(0xFF1a4a8f);
  final Color accentColor = const Color(0xFF4a7de2);
  final Color backgroundColor = const Color(0xFFf8f9fa);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color successColor = const Color(0xFF2ecc71);
  final Color warningColor = const Color(0xFFf39c12);
  final Color dangerColor = const Color(0xFFe74c3c);

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
      final snapshot =
          await FirestoreService.getCollection('projects').get();
      final ids = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['siteId'];
                      return null;
          })
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .map((value) => value.toString())
          .toSet()
          .toList();
      ids.sort();
      setState(() {
        siteIds = ids;
        isLoadingSites = false;
      });
    } catch (e) {
      setState(() {
        isLoadingSites = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sites: $e'),
          backgroundColor: dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Project Financial Status Report',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.w600,
            
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                secondaryColor,
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
        ),
        iconTheme: const IconThemeData(),
      ),
      body: Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.description,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Project Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select a site ID or enter project details manually',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Site ID Dropdown
                      _buildInputLabel('Site ID'),
                      const SizedBox(height: 8),
                      isLoadingSites
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: selectedSiteId,
                              hint: Text(
                                "Select Site ID",
                                style: TextStyle(),
                              ),
                              onChanged: (value) async {
                                setState(() {
                                  selectedSiteId = value;
                                });
                                if (value != null) {
                                  try {
                                    final query = await FirestoreService.getCollection('projects')
                                        .where('siteId', isEqualTo: value)
                                        .limit(1)
                                        .get();
                                    if (query.docs.isNotEmpty) {
                                      final data = query.docs.first.data();
                                      siteNameController.text =
                                          data['siteId']?.toString() ?? '';
                                      projectNameController.text =
                                          data['projectName']?.toString() ?? '';
                                      ownerNameController.text =
                                          data['ownerName']?.toString() ?? '';
                                    } else {
                                      siteNameController.clear();
                                      projectNameController.clear();
                                      ownerNameController.clear();
                                    }
                                  } catch (e) {
                                    siteNameController.clear();
                                    projectNameController.clear();
                                    ownerNameController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to load site details: $e'),
                                        backgroundColor: dangerColor,
                                      ),
                                    );
                                  }
                                }
                              },
                              items: siteIds.map((id) {
                                return DropdownMenuItem(
                                  value: id,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width - 100,
                                    ),
                                    child: Text(
                                      id,
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: primaryColor.withOpacity(0.7),
                                ),
                              ),
                              icon: Icon(Icons.arrow_drop_down,
                                  color: primaryColor),
                              borderRadius: BorderRadius.circular(12),
                              style: TextStyle(color: textColor),
                              dropdownColor: cardColor,
                              isExpanded: true, // This is the key fix
                            ),
                      const SizedBox(height: 20),

                      // Site Name TextField
                      _buildInputLabel('Site Name'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: siteNameController,
                        decoration: _buildInputDecoration(
                            hintText: 'Enter site name',
                            icon: Icons.location_on),
                        style: TextStyle(fontSize: 16, color: textColor),
                      ),
                      const SizedBox(height: 20),

                      // Project Name TextField
                      _buildInputLabel('Project Name'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: projectNameController,
                        decoration: _buildInputDecoration(
                            hintText: 'Enter project name',
                            icon: Icons.work),
                        style: TextStyle(fontSize: 16, color: textColor),
                      ),
                      const SizedBox(height: 20),

                      // Owner Name TextField
                      _buildInputLabel('Owner Name'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ownerNameController,
                        decoration: _buildInputDecoration(
                            hintText: 'Enter owner name', icon: Icons.person),
                        style: TextStyle(fontSize: 16, color: textColor),
                      ),
                      const SizedBox(height: 32),

                      // Buttons Section
                      if (isSmallScreen) ...[
                        _buildPrimaryButton(
                          text: 'Financial Status',
                          icon: Icons.pie_chart,
                          onPressed: () => _showFinancialStatus(),
                        ),
                        const SizedBox(height: 12),
                        _buildPrimaryButton(
                          text: 'Project Indicator',
                          icon: Icons.analytics,
                          onPressed: () => _showProjectIndicator(),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildPrimaryButton(
                                text: 'Financial Status',
                                icon: Icons.pie_chart,
                                onPressed: () => _showFinancialStatus(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPrimaryButton(
                                text: 'Project Indicator',
                                icon: Icons.analytics,
                                onPressed: () => _showProjectIndicator(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  InputDecoration _buildInputDecoration({String? hintText, IconData? icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primaryColor,
          width: 2,
        ),
      ),
      filled: true,
      
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              color: primaryColor.withOpacity(0.7),
            )
          : null,
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: primaryColor.withOpacity(0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFinancialStatus() {
    // Validate all fields
    if ((selectedSiteId == null || selectedSiteId!.isEmpty) ||
        siteNameController.text.trim().isEmpty ||
        projectNameController.text.trim().isEmpty ||
        ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields before proceeding.'),
          backgroundColor: warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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