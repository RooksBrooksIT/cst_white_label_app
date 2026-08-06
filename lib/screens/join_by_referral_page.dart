import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';

class JoinByReferralPage extends StatefulWidget {
  const JoinByReferralPage({super.key});

  @override
  State<JoinByReferralPage> createState() => _JoinByReferralPageState();
}

class _JoinByReferralPageState extends State<JoinByReferralPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Search for organization ID across all admin/referal documents
      final orgId = await FirestoreService.findOrgIdByReferralCode(code);

      if (orgId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_org_path', orgId);
        await prefs.setString('temp_referral_role', 'organization');
        await prefs.setString('temp_referral_code', code);
        await prefs.setBool(
          'is_join_with_code',
          true,
        ); // Flag for restricted flow

        // Sync branding immediately after joining
        await AppTheme.syncWithFirestore(orgId);

        if (mounted) {
          // Navigate to main role selection dashboard
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/authSelection',
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid referral code'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final primaryColor = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 24.0);
    final maxContentWidth = 800.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Join Organization',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isDesktop ? 40.0 : 24.0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: isDesktop ? 40 : 20),
                Icon(
                  Icons.card_giftcard_rounded,
                  size: isDesktop ? 100 : 80,
                  color: primaryColor,
                ),
                SizedBox(height: isDesktop ? 40 : 32),
                Text(
                  'Enter Referral Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 32 : 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Text(
                  'Enter the referral code provided by your organization administrator to join and start configuring your dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 17 : 15,
                    color: secondaryTextColor,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isDesktop ? 56 : 48),
                TextFormField(
                  controller: _codeController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'CODE123',
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 24 : 20,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  onFieldSubmitted: (_) => _handleJoin(),
                ),
                SizedBox(height: isDesktop ? 48 : 40),
                SizedBox(
                  height: isDesktop ? 64 : 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: isDesktop ? 32 : 24,
                            width: isDesktop ? 32 : 24,
                            child: CircularProgressIndicator(
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            'JOIN ORGANIZATION',
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
