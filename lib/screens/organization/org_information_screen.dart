import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';

class OrgInformationScreen extends StatefulWidget {
  const OrgInformationScreen({super.key});

  @override
  State<OrgInformationScreen> createState() => _OrgInformationScreenState();
}

class _OrgInformationScreenState extends State<OrgInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _orgPhoneController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchInformation();
  }

  Future<void> _fetchInformation() async {
    try {
      var doc = await FirestoreService.orgDataDoc.get();

      if (!doc.exists) {
        debugPrint('OrgInformationScreen: Data doc not found in admin, falling back to root.');
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _addressController.text = data?['address'] ?? '';
          _orgPhoneController.text = data?['phone'] ?? data?['orgPhone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching org information: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to load organisation info');
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirestoreService.orgDataDoc.set({
        'address': _addressController.text.trim(),
        'phone': _orgPhoneController.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) {
        AppTheme.showSuccessToast(context, 'Organisation information updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving org information: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Error updating information: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _orgPhoneController.dispose();
    super.dispose();
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
                    'Organisation Info',
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
                  child: _isFetching
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Main Card Container (Clean White Reference Theme)
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
                                              Icons.business_rounded,
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
                                                  'Update Information',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0A183D),
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Update your organisation address and contact number.',
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

                                      // Address Field
                                      _buildInputField(
                                        theme: theme,
                                        controller: _addressController,
                                        label: 'Organisation Address',
                                        hint: 'Enter Organisation Address',
                                        icon: Icons.location_on_rounded,
                                        maxLines: 3,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Please enter the address';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Phone Field
                                      _buildInputField(
                                        theme: theme,
                                        controller: _orgPhoneController,
                                        label: 'Organisation Phone Number',
                                        hint: 'Enter 10-digit Phone Number',
                                        icon: Icons.phone_rounded,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Please enter the phone number';
                                          }
                                          if (val.trim().length != 10) {
                                            return 'Phone number must be 10 digits';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Save CTA Button
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveInformation,
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
                                            'SAVE CHANGES',
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

  Widget _buildInputField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 10 : 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
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
