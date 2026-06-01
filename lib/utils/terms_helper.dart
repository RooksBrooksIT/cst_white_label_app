import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

class TermsHelper {
  static const String _termsKey = 'has_accepted_terms';

  static Future<bool> hasAcceptedTerms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_termsKey) ?? false;
  }

  static Future<void> acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsKey, true);
  }

  static void showTermsDialog(
    BuildContext context, {
    required VoidCallback onAccepted,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TermsDialog(onAccepted: onAccepted),
    );
  }
}

class _TermsDialog extends StatefulWidget {
  final VoidCallback onAccepted;

  const _TermsDialog({required this.onAccepted});

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final maxHeight = size.height * 0.75; // Use slightly less to be safe
    final maxWidth = size.width > 600 ? 500.0 : size.width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min, // This allows the dialog to shrink
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      color: theme.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content - This is the flexible part that scrolls
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          theme,
                          '1. ACCEPTANCE OF TERMS',
                          'By accessing and using this application ("CST Whitelabel"), you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the application.',
                        ),
                        _buildSection(
                          theme,
                          '2. DESCRIPTION OF SERVICE',
                          'CST Whitelabel provides construction site management tools, including financial tracking, reporting, and resource management. We reserve the right to modify or discontinue any part of the service at any time without prior notice.',
                        ),
                        _buildSection(
                          theme,
                          '3. USER OBLIGATIONS',
                          'You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. You agree to provide accurate, current, and complete information and to use the service only for lawful business purposes.',
                        ),
                        _buildSection(
                          theme,
                          '4. DATA PRIVACY & SECURITY',
                          'Your privacy is paramount. We implement industry-standard security measures to protect your data. By using the service, you consent to the collection and processing of data as described in our Privacy Policy, ensuring compliance with relevant data protection regulations.',
                        ),
                        _buildSection(
                          theme,
                          '5. INTELLECTUAL PROPERTY',
                          'The application, its original content, features, and functionality are and will remain the exclusive property of CST Whitelabel and its licensors. Unauthorized use, reproduction, or distribution of any materials is strictly prohibited.',
                        ),
                        _buildSection(
                          theme,
                          '6. DISCLAIMER OF WARRANTIES',
                          'The service is provided on an "AS IS" and "AS AVAILABLE" basis. CST Whitelabel makes no warranties, expressed or implied, regarding the reliability, accuracy, or availability of the application or the data contained therein.',
                        ),
                        _buildSection(
                          theme,
                          '7. LIMITATION OF LIABILITY',
                          'In no event shall CST Whitelabel be liable for any indirect, incidental, special, or consequential damages resulting from the use or inability to use the service, including loss of profits, data, or business opportunities.',
                        ),
                        _buildSection(
                          theme,
                          '8. GOVERNING LAW',
                          'These Terms shall be governed and construed in accordance with the laws of the jurisdiction in which the company is registered, without regard to its conflict of law provisions.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last Updated: May 28, 2026',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _isAccepted,
                        onChanged: (value) {
                          setState(() {
                            _isAccepted = value ?? false;
                          });
                        },
                        title: Text(
                          'I agree to the Terms & Conditions',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'CONTINUE',
                      onPressed: _isAccepted
                          ? () async {
                              await TermsHelper.acceptTerms();
                              if (mounted) {
                                Navigator.pop(context);
                                widget.onAccepted();
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
