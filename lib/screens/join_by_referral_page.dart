import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final referralDoc = await FirebaseFirestore.instance
          .collection('referralCodes')
          .doc(code)
          .get();

      if (referralDoc.exists) {
        final dynamicPath = referralDoc.data()?['dynamicPath'] as String?;
        if (dynamicPath != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_org_path', dynamicPath);

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/authSelection',
              (route) => route.settings.name == '/landing',
            );
          }
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
    const textColor = Color(0xFF0F172A);
    const secondaryTextColor = Color(0xFF64748B);
    const primaryColor = Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
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
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 80,
              color: primaryColor,
            ),
            const SizedBox(height: 32),
            const Text(
              'Enter Referral Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'CODE123',
                hintStyle: TextStyle(
                  color: secondaryTextColor.withOpacity(0.3),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
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
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
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
