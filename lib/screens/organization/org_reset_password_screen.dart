import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/firestore_error_handler.dart';
import 'package:demo_cst/utils/app_theme.dart';

class OrgResetPasswordScreen extends StatefulWidget {
  const OrgResetPasswordScreen({super.key});

  @override
  State<OrgResetPasswordScreen> createState() => _OrgResetPasswordScreenState();
}

class _OrgResetPasswordScreenState extends State<OrgResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    AppTheme.showErrorToast(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppTheme.showSuccessToast(context, message);
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('New passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('org_username');

      if (username == null || username.isEmpty) {
        _showError('Session expired. Please login again.');
        setState(() => _isLoading = false);
        return;
      }

      final oldPassword = _oldPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      final userQuery = await FirebaseFirestore.instance
          .collectionGroup('admin')
          .where('username', isEqualTo: username)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? dataDoc;
      for (var doc in userQuery.docs) {
        if (doc.id == 'data') {
          dataDoc = doc;
          break;
        }
      }

      if (dataDoc == null || dataDoc.data()?['password'] != oldPassword) {
        _showError('Incorrect old password');
      } else {
        await dataDoc.reference.update({'password': newPassword});

        _showSuccess('Password updated successfully');
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Reset password error: $e');
      if (mounted) {
        FirestoreErrorHandler.handleError(context, e, title: 'Reset Error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1942),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B1942).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main Section Container Card (Clean White Reference Theme)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.lock_reset_rounded,
                                        color: theme.primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Change Your Password',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A183D),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Enter your old and new password.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                                ),

                                // Old Password
                                _buildPasswordField(
                                  theme: theme,
                                  controller: _oldPasswordController,
                                  label: 'Old Password',
                                  hint: 'Enter your Old Password',
                                  icon: Icons.lock_outline_rounded,
                                  isVisible: _isOldPasswordVisible,
                                  onToggleVisibility: () => setState(() => _isOldPasswordVisible = !_isOldPasswordVisible),
                                  validator: (v) => v == null || v.isEmpty ? 'Old password required' : null,
                                ),

                                const SizedBox(height: 16),

                                // New Password
                                _buildPasswordField(
                                  theme: theme,
                                  controller: _newPasswordController,
                                  label: 'New Password',
                                  hint: 'Enter your New Password',
                                  icon: Icons.lock_clock_outlined,
                                  isVisible: _isNewPasswordVisible,
                                  onToggleVisibility: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'New password required'
                                      : (v.length < 6 ? 'Minimum 6 characters' : null),
                                ),

                                const SizedBox(height: 16),

                                // Confirm Password
                                _buildPasswordField(
                                  theme: theme,
                                  controller: _confirmPasswordController,
                                  label: 'Confirm New Password',
                                  hint: 'Confirm your New Password',
                                  icon: Icons.lock_reset_rounded,
                                  isVisible: _isConfirmPasswordVisible,
                                  onToggleVisibility: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                  validator: (v) => v == null || v.isEmpty ? 'Confirm password required' : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Save CTA Button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: theme.primaryColor.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'UPDATE PASSWORD',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: !isVisible,
              validator: validator,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Icon(
                    icon,
                    color: theme.primaryColor,
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                suffixIcon: InkWell(
                  onTap: onToggleVisibility,
                  child: Icon(
                    isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: const Color(0xFF64748B),
                    size: 18,
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
