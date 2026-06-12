import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class OrganisationLandingPage extends StatefulWidget {
  const OrganisationLandingPage({super.key});

  @override
  State<OrganisationLandingPage> createState() =>
      _OrganisationLandingPageState();
}

class _OrganisationLandingPageState extends State<OrganisationLandingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (_tabController.index != _selectedIndex) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // RECTANGULAR TOP BAR (NO CURVES) - Includes back button, optional title, and tab bar
          _buildRectangularTopBar(theme, colorScheme),
          // Scrollable Main Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Brand Logo with soft glow
                    _buildBrandLogo(theme),
                    const SizedBox(height: 24),
                    // App Name (Dynamic)
                    ValueListenableBuilder<String>(
                      valueListenable: AppTheme.appName,
                      builder: (context, name, _) {
                        return Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                            color: textColor,
                            letterSpacing: 0.8,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Streamlining Construction Excellence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: secondaryTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Dynamic action area based on selected tab
                    _buildDynamicActionArea(theme, colorScheme),
                    const SizedBox(height: 32),
                    // Referral link (visible on both tabs)
                    _buildReferralLink(textColor),
                    const SizedBox(height: 40),
                    // Version info
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // RECTANGULAR TOP BAR: No curves, sharp edges as requested
  Widget _buildRectangularTopBar(ThemeData theme, ColorScheme colorScheme) {
    final textColor = colorScheme.onSurface;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.zero, // Explicitly no curves
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row with back button and optional title/spacer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: textColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                  ),
                  const Spacer(),
                  Text(
                    'Organization Portal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button width
                ],
              ),
            ),
            // Rectangular Tab Bar (no curves)
            TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              indicatorWeight: 3,
              labelColor: theme.primaryColor,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
              tabs: const [
                Tab(text: 'LOGIN'),
                Tab(text: 'REGISTER'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandLogo(ThemeData theme) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/images/logo_main.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.business_center_rounded,
          size: 90,
          color: theme.primaryColor.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildDynamicActionArea(ThemeData theme, ColorScheme colorScheme) {
    if (_selectedIndex == 0) {
      // LOGIN TAB: Show login button with supporting card
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lock_open_rounded,
                  size: 36,
                  color: theme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage projects, team, and organization details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/orgLogin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                shadowColor: theme.primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'LOGIN TO DASHBOARD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // REGISTER TAB: Show organization registration button + info card
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  size: 36,
                  color: theme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Set Up Your Organization',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register your company to start managing construction projects and teams.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/orgRegistrationForm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                shadowColor: theme.primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'REGISTER ORGANIZATION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildReferralLink(Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/joinByReferral'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 22,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(width: 10),
            Text(
              'Join using referral code',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.8),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: textColor.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}
