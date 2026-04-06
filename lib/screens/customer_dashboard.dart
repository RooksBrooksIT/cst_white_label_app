import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Customer_insight_dashboard.dart';
import 'customer_project_details.dart';
import 'customer_worker_details.dart';
import 'customer_workers_summary.dart';
import '../widgets/glass_scaffold.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

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
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadStoredUserInfo();
  }

  Future<void> _loadStoredUserInfo() async {
    final auth = AuthService();
    if (auth.isLoggedIn && auth.userRole == UserRole.customer) {
      final data = auth.userData;
      setState(() {
        _storedOwnerName = data['ownerName'] ?? widget.ownerName;
        _storedOwnerPhoneNumber = data['ownerPhoneNumber'] ?? widget.ownerPhoneNumber;
        _siteId = data['siteId'] ?? _siteId;
      });
    }

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

        // Store siteId in AuthService only if we found a valid one
        if (newSiteId.isNotEmpty) {
          await AuthService().updateUserData({'siteId': newSiteId});

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



  Widget _dashboardButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: onPressed,
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: Responsive.fontSize(context, 14),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.3),
                size: 16,
              ),
            ],
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Logout',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to logout?',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () async {
                await AuthService().logout();

                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/authSelection',
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
      return const GlassScaffold(
        onBack: null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Loading your dashboard...',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: GlassScaffold(
        onBack: () => _showLogoutDialog(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            vertical: 24,
            horizontal: Responsive.isMobile(context) ? 0.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 18),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _displayOwnerName,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 32),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Text(
                          'Site ID: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
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
                                  ? Colors.white
                                  : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Main Dashboard Buttons
            _dashboardButton(
              title: "Project Summary",
              subtitle: "View your project details and progress",
              icon: Icons.assignment_rounded,
              color: Colors.blueAccent,
              onPressed: () {
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
                    const SnackBar(content: Text('Project siteId not found')),
                  );
                }
              },
            ),
            _dashboardButton(
              title: "Workers List",
              subtitle: "Manage your workers and their details",
              icon: Icons.people_alt_rounded,
              color: Colors.greenAccent,
              onPressed: () {
                if (_siteId != null && _siteId!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerWorkerDetails(siteId: _siteId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project siteId not found')),
                  );
                }
              },
            ),
            _dashboardButton(
              title: "Workers Summary",
              subtitle: "View workers performance and attendance",
              icon: Icons.summarize_rounded,
              color: Colors.purpleAccent,
              onPressed: () {
                if (_siteId != null && _siteId!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerWorkersSummary(siteId: _siteId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project siteId not found')),
                  );
                }
              },
            ),
            _dashboardButton(
              title: "Expenses Summary",
              subtitle: "View workers performance and attendance",
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.orangeAccent,
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
                    const SnackBar(content: Text('Project siteId not found')),
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
