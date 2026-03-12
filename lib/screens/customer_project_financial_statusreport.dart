import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/financial_status_report.dart';
import 'package:demo_cst/screens/project_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // User data fields
  String? _ownerName;
  String? _ownerPhoneNumber;
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
    _loadUserDataAndFetchSites();
  }

  Future<void> _loadUserDataAndFetchSites() async {
    // Load user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownerName = prefs.getString('ownerName');
      _ownerPhoneNumber = prefs.getString('ownerPhoneNumber');
      _userSiteId = prefs.getString('siteId');
    });

    await _fetchSiteIds();
  }

  Future<void> _fetchSiteIds() async {
    try {
      Query query = FirebaseFirestore.instance.collection('projects');

      // If user has a siteId from login, filter by it
      if (_userSiteId != null && _userSiteId!.isNotEmpty) {
        query = query.where('siteId', isEqualTo: _userSiteId);
      }

      final snapshot = await query.get();
      final ids = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              return data['siteId'];
            }
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

        // If user has a siteId from login and it exists in the list, pre-select it
        if (_userSiteId != null && siteIds.contains(_userSiteId)) {
          selectedSiteId = _userSiteId;
          _loadSiteDetails(_userSiteId!);
        } else if (siteIds.isNotEmpty) {
          selectedSiteId = siteIds.first;
          _loadSiteDetails(siteIds.first);
        }
      });
    } catch (e) {
      setState(() {
        isLoadingSites = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load sites: $e')));
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('projects')
          .where('siteId', isEqualTo: siteId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          siteNameController.text = data?['siteId']?.toString() ?? '';
          projectNameController.text = data?['projectName']?.toString() ?? '';
          ownerNameController.text = data?['ownerName']?.toString() ?? '';
        });
      } else {
        setState(() {
          siteNameController.clear();
          projectNameController.clear();
          ownerNameController.clear();
        });
      }
    } catch (e) {
      setState(() {
        siteNameController.clear();
        projectNameController.clear();
        ownerNameController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load site details: $e')),
      );
    }
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDisplayField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Color(0xFF003768), size: 20),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : 'Not available',
                  style: TextStyle(
                    fontSize: 16,
                    color: value.isNotEmpty ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Project Financial Status Report',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF003768),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card - Displaying login credentials
            const SizedBox(height: 16),

            // Site Information Card
            if (_userSiteId != null)
              _buildModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR SITE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.business, color: Color(0xFF003768)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Site ID',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _userSiteId!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Project Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Color(0xFF003768),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Site Name Display
            _buildModernCard(
              child: _buildDisplayField(
                label: 'SITE NAME',
                value: siteNameController.text,
                icon: Icons.location_on,
              ),
            ),
            SizedBox(height: 20),

            // Project Name Display
            _buildModernCard(
              child: _buildDisplayField(
                label: 'PROJECT NAME',
                value: projectNameController.text,
                icon: Icons.assignment,
              ),
            ),
            SizedBox(height: 20),

            // Owner Name Display
            _buildModernCard(
              child: _buildDisplayField(
                label: 'OWNER NAME',
                value: ownerNameController.text,
                icon: Icons.person,
              ),
            ),
            SizedBox(height: 32),

            // Buttons Section
            if (isSmallScreen) ...[
              _buildPrimaryButton(
                text: 'Financial Status',
                onPressed: () => _showFinancialStatus(),
              ),
              SizedBox(height: 12),
              _buildPrimaryButton(
                text: 'Project Indicator',
                onPressed: () => _showProjectIndicator(),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      text: 'Financial Status',
                      onPressed: () => _showFinancialStatus(),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildPrimaryButton(
                      text: 'Project Indicator',
                      onPressed: () => _showProjectIndicator(),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        SnackBar(content: Text('Please fill all fields before proceeding.')),
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
    // Validate all fields for Project Indicator as well
    if ((selectedSiteId == null || selectedSiteId!.isEmpty) ||
        siteNameController.text.trim().isEmpty ||
        projectNameController.text.trim().isEmpty ||
        ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields before proceeding.')),
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
