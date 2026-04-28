import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

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

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/authSelection',
            (route) => route.settings.name == '/landing',
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
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.qr_code_scanner_rounded, size: 80, color: primaryColor),
            const SizedBox(height: 32),
            Text(
              'Enter Referral Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the referral code provided by your organization administrator to join and start configuring your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: secondaryTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            TextFormField(
              controller: _codeController,
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
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
            const SizedBox(height: 40),
            SizedBox(
              height: 56,
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
                    ? CircularProgressIndicator(color: colorScheme.onPrimary)
                    : const Text(
                        'JOIN ORGANIZATION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
