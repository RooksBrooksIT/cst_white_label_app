import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Customer_insight_dashboard.dart';
import 'customer_project_details.dart';
import 'customer_worker_details.dart';
import 'customer_workers_summary.dart';
import '../widgets/glass_scaffold.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

import 'org_sub_menu_screen.dart';

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

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<SubMenuItem> items;

  _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.items,
  });
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  final ScrollController _scrollController = ScrollController();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredUserInfo() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    final auth = AuthService();
    if (auth.isLoggedIn && auth.userRole == UserRole.customer) {
      final data = auth.userData;
      setState(() {
        _storedOwnerName = data['ownerName'] ?? widget.ownerName;
        _storedOwnerPhoneNumber =
            data['ownerPhoneNumber'] ?? widget.ownerPhoneNumber;
        _siteId = data['siteId'] ?? _siteId;
      });
    }

    // Always try to fetch latest siteId from Firestore, but don't clear existing one
    await _fetchSiteId();
  }

  Future<void> _fetchSiteId() async {
    try {
      if (!FirestoreService.isReady) await FirestoreService.initialize();

      final String ownerNameToUse = _storedOwnerName ?? widget.ownerName;
      final String ownerPhoneToUse =
          _storedOwnerPhoneNumber ?? widget.ownerPhoneNumber;

      final querySnapshot = await FirestoreService.getCollection('Site')
          .where('ownerName', isEqualTo: ownerNameToUse)
          .where('ownerPhoneNumber', isEqualTo: ownerPhoneToUse)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final newSiteId = doc['siteId']?.toString() ?? '';

        if (newSiteId.isNotEmpty) {
          await AuthService().updateUserData({'siteId': newSiteId});

          setState(() {
            _siteId = newSiteId;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[300], size: 28),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/authSelection',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
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
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Loading your dashboard...',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final categories = [
      _CategoryData(
        title: "Project Details",
        subtitle: "View your site and project information",
        icon: Icons.location_city_rounded,
        color: colorScheme.primary,
        gradientColors: [
          colorScheme.primary,
          colorScheme.primary.withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: 'Project Information',
            subtitle: 'Detailed site and project specifications',
            icon: Icons.info_rounded,
            color: colorScheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetailsPage(
                  ownerName: _displayOwnerName,
                  ownerPhoneNumber: _displayOwnerPhoneNumber,
                  siteId: _siteId ?? '',
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Site Workers',
            subtitle: 'Real-time worker attendance at your site',
            icon: Icons.people_rounded,
            color: colorScheme.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CustomerWorkerDetails(siteId: _siteId ?? ''),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Reports & Insights",
        subtitle: "Financial reports and project analytics",
        icon: Icons.bar_chart_rounded,
        color: Colors.orange,
        gradientColors: [Colors.orange, Colors.orange.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: 'Project Analytics',
            subtitle: 'Advanced insights and progress tracking',
            icon: Icons.insights_rounded,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerWorkProgress(
                  ownername: _displayOwnerName,
                  ownerphonenumber: _displayOwnerPhoneNumber,
                  siteId: _siteId ?? '',
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Workers Summary',
            subtitle: 'Consolidated report of site workforce',
            icon: Icons.assignment_ind_rounded,
            color: Colors.orangeAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CustomerWorkersSummary(siteId: _siteId ?? ''),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Support",
        subtitle: "Get help and view policies",
        icon: Icons.support_agent_rounded,
        color: Colors.teal,
        gradientColors: [Colors.teal, Colors.teal.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: 'Privacy Policy',
            subtitle: 'Read our data protection guidelines',
            icon: Icons.privacy_tip_rounded,
            color: Colors.teal,
            onTap: () async {
              final Uri url = Uri.parse(
                'https://sites.google.com/view/cst-whitelabel-app/home',
              );
              if (!await launchUrl(url)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open privacy policy'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : (screenWidth < 900 ? 4 : 6);

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
        title: 'Customer Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
        padding: EdgeInsets.zero,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                ..._buildGridSections(context, theme, categories, crossAxisCount),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGridSections(
    BuildContext context,
    ThemeData theme,
    List<_CategoryData> categories,
    int crossAxisCount,
  ) {
    List<Widget> slivers = [];

    for (var category in categories) {
      if (category.items.isEmpty) continue;

      // Section Header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [category.color, category.color.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${category.items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Items Grid for this section
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = category.items[index];
              return _buildGridItem(context, item);
            }, childCount: category.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildGridItem(BuildContext context, SubMenuItem item) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.cardColor,
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [item.color, item.color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
