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
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

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
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
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
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main Section Container Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: darkCardBg,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: darkCardBg.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Icon Circle Badge
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Change Your Password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter your old password and a new one to update your credentials.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFCBD5E1),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Old Password
                                _buildPasswordField(
                                  controller: _oldPasswordController,
                                  label: 'Old Password',
                                  hint: 'Enter your Old Password',
                                  icon: Icons.lock_outline_rounded,
                                  isVisible: _isOldPasswordVisible,
                                  onToggleVisibility: () => setState(() => _isOldPasswordVisible = !_isOldPasswordVisible),
                                  validator: (v) => v == null || v.isEmpty ? 'Old password required' : null,
                                ),

                                const SizedBox(height: 18),

                                // New Password
                                _buildPasswordField(
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

                                const SizedBox(height: 18),

                                // Confirm Password
                                _buildPasswordField(
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

                          const SizedBox(height: 32),

                          // Save CTA Button
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkCardBg,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: darkCardBg.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'UPDATE PASSWORD',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: !isVisible,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E88E5),
                  size: 22,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
