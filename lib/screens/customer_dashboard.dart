import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/screens/Customer_insight_dashboard.dart';
import 'package:demo_cst/screens/Customer_insights_screen.dart';

import 'package:demo_cst/screens/customer_login_page.dart';
import 'package:demo_cst/screens/customer_project_details.dart';
import 'package:demo_cst/screens/customer_worker_details.dart';
import 'package:demo_cst/screens/customer_workers_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerDashboardPage extends StatefulWidget {
  final String ownerName;
  final String ownerPhoneNumber;

  const CustomerDashboardPage({
    super.key,
    required this.ownerName,
    required this.ownerPhoneNumber,
    required String siteId,
  });

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  String? _siteId;
  String? _storedOwnerName;
  String? _storedOwnerPhoneNumber;
  bool _isLoading = true;
  DateTime? currentBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadStoredUserInfo();
  }

  Future<void> _loadStoredUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedOwnerName = prefs.getString('ownerName') ?? widget.ownerName;
      _storedOwnerPhoneNumber =
          prefs.getString('ownerPhoneNumber') ?? widget.ownerPhoneNumber;
      _siteId = prefs.getString('siteId'); // Load siteId from SharedPreferences
    });

    // Always try to fetch latest siteId from Firestore, but don't clear existing one
    await _fetchSiteId();
  }

  Future<void> _fetchSiteId() async {
    try {
      final String ownerNameToUse = _storedOwnerName ?? widget.ownerName;
      final String ownerPhoneToUse =
          _storedOwnerPhoneNumber ?? widget.ownerPhoneNumber;

      print('Fetching siteId for: $ownerNameToUse, $ownerPhoneToUse');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('ownerName', isEqualTo: ownerNameToUse)
          .where('ownerPhoneNumber', isEqualTo: ownerPhoneToUse)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final newSiteId = doc['siteId']?.toString() ?? '';

        // Store siteId in SharedPreferences only if we found a valid one
        if (newSiteId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('siteId', newSiteId);

          setState(() {
            _siteId = newSiteId;
            _isLoading = false;
          });
          print('SiteId found and stored: $_siteId');
        } else {
          // Keep the existing siteId if new one is empty
          setState(() {
            _isLoading = false;
          });
          print(
            'No valid siteId found in Firestore, keeping existing: $_siteId',
          );
        }
      } else {
        // No projects found, but keep the existing siteId
        setState(() {
          _isLoading = false;
        });
        print('No projects found for user, keeping existing siteId: $_siteId');
      }
    } catch (e) {
      // On error, keep the existing siteId
      setState(() {
        _isLoading = false;
      });
      print('Error fetching siteId, keeping existing: $e');
    }
  }

  // Add this method to refresh siteId if needed
  Future<void> _refreshSiteId() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchSiteId();
  }

  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) > Duration(seconds: 2)) {
      currentBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to close app'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  Widget _dashboardButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [color.withOpacity(0.9), color],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,  size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF003768),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('ownerName');
                await prefs.remove('ownerPhoneNumber');
                await prefs.remove('siteId'); // Also remove siteId on logout

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
                  (route) => false,
                );
              },
              child: const Text(
                'Logout',
                style: TextStyle(),
              ),
            ),
          ],
        );
      },
    );
  }

  String get _displayOwnerName {
    return _storedOwnerName ?? widget.ownerName;
  }

  String get _displayOwnerPhoneNumber {
    return _storedOwnerPhoneNumber ?? widget.ownerPhoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003768)),
              ),
              SizedBox(height: 20),
              Text(
                'Loading your dashboard...',
                style: TextStyle(fontSize: 16, ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Customer Dashboard',
            style: TextStyle(),
          ),
          centerTitle: true,
          backgroundColor: Color(0xFF003768),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20.0),
              bottomRight: Radius.circular(20.0),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, ),
            onPressed: () {
              // Drawer/menu functionality if needed
            },
          ),
          actions: [
            // Refresh button to refetch siteId if needed
            IconButton(
              icon: const Icon(Icons.refresh),
              
              onPressed: _refreshSiteId,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back! $_displayOwnerName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your account and services',
                      style: TextStyle(fontSize: 16, ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Site ID: ',
                          style: TextStyle(
                            fontSize: 14,
                            
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _siteId != null && _siteId!.isNotEmpty
                                ? _siteId!
                                : 'No project site found',
                            style: TextStyle(
                              fontSize: 14,
                              color: _siteId != null && _siteId!.isNotEmpty
                                  ? Color(0xFF003768)
                                  : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Dashboard Buttons
              _dashboardButton(
                title: "Project Summary",
                subtitle: "View your project details and progress",
                icon: Icons.assignment,
                color: Color(0xFF003768),
                onPressed: () {
                  print('Navigating to ProjectDetailsPage...');
                  print('SiteId: $_siteId');
                  print('OwnerName: $_displayOwnerName');
                  print('OwnerPhone: $_displayOwnerPhoneNumber');

                  if (_siteId != null && _siteId!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailsPage(
                          siteId: _siteId!,
                          ownerName: _displayOwnerName,
                          ownerPhoneNumber: _displayOwnerPhoneNumber,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project siteId not found'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),

              _dashboardButton(
                title: "Workers List",
                subtitle: "Manage your workers and their details",
                icon: Icons.people,
                color: Color(0xFF003768),
                onPressed: () {
                  if (_siteId != null && _siteId!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CustomerWorkerDetails(siteId: _siteId!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project siteId not found'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),

              _dashboardButton(
                title: "Workers Summary",
                subtitle: "View workers performance and attendance",
                icon: Icons.summarize,
                color: Color(0xFF003768),
                onPressed: () {
                  if (_siteId != null && _siteId!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CustomerWorkersSummary(siteId: _siteId!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project siteId not found'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              _dashboardButton(
                title: "Expenses Summary",
                subtitle: "View workers performance and attendance",
                icon: Icons.summarize,
                color: Color(0xFF003768),
                onPressed: () {
                  if (_siteId != null && _siteId!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerWorkProgress(
                          ownername: _displayOwnerName,
                          ownerphonenumber: _displayOwnerPhoneNumber,
                          siteId: _siteId!,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project siteId not found'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
