import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'contractor_entry_page.dart';
import 'supervisor_dashboard.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/firestore_error_handler.dart';

class SupervisorLoginPage extends StatefulWidget {
  const SupervisorLoginPage({super.key});

  @override
  _SupervisorLoginPageState createState() => _SupervisorLoginPageState();
}

class _SupervisorLoginPageState extends State<SupervisorLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  bool _isLoading = false;

  bool _isContractor = false;
  List<String> _supervisorNames = [];
  String? _selectedSupervisorName;
  String? _tempOrgName;
  String? _tempLogoUrl;
  String? _actualReferralCode;

  @override
  void initState() {
    super.initState();
    _fetchContractorNames();
    _checkLoginStatus();
  }

  // Check if user is already logged in
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Fetch org details if available
      setState(() {
        _tempOrgName = prefs.getString('temp_org_name');
        _tempLogoUrl = prefs.getString('temp_logo_url');
        _actualReferralCode = prefs.getString('temp_referral_code');

        if (_tempOrgName != null) {
          _referralController.text = _tempOrgName!;
        } else if (_actualReferralCode != null) {
          _referralController.text = _actualReferralCode!;
        }
      });

      final auth = AuthService();
      if (auth.isLoggedIn && auth.userRole == UserRole.supervisor) {
        final data = auth.userData;
        final username = data['username'] ?? '';
        final supervisorId = data['supervisorId'] ?? '';
        final supervisorName = data['supervisorName'] ?? '';
        final isContractor = data['isContractor'] ?? false;

        if (isContractor) {
          final contractorName = data['contractorName'] ?? '';
          final contractorField = data['contractorField'] ?? '';

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorEntryPage(
                  userName: username,
                  userDetails: {
                    'supervisorId': supervisorId,
                    'contractorName': contractorName,
                    'contractorField': contractorField,
                  },
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorDashboard(
                  supervisorId: supervisorId,
                  supervisorName: supervisorName,
                  username: username,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }
  }

  // Save login data to AuthService
  Future<void> _saveLoginData({
    required String username,
    required String supervisorId,
    required String supervisorName,
    required bool isContractor,
    required String orgId,
    required String resolvedPath,
    String? contractorName,
    String? contractorField,
  }) async {
    try {
      await AuthService().login(UserRole.supervisor, {
        'username': username,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'isContractor': isContractor,
        'userType': isContractor ? 'contractor' : 'supervisor',
        'contractorName': contractorName,
        'contractorField': contractorField,
        'orgId': orgId,
        'sup_org_doc_path': resolvedPath,
      });
    } catch (e) {
      debugPrint('Error saving login data: $e');
    }
  }

  // Clear login data (for logout)
  static Future<void> clearLoginData() async {
    await AuthService().logout();
  }

  Future<void> _fetchContractorNames() async {
    try {
      final contractorsCollection = await FirestoreService.contractors;
      final querySnapshot = await contractorsCollection.get();
      final names = querySnapshot.docs
          .map((doc) => doc.data()['contractorName'] as String?)
          .where((name) => name != null)
          .cast<String>()
          .toList();
      if (mounted) {
        setState(() {
          _supervisorNames = names;
        });
      }
    } catch (e) {
      debugPrint('Error fetching contractor names: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Login Failed'),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _showSuccessDialog(String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Success'),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _showForgotPasswordDialog() {
    final usernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(
                          Icons.lock_reset_rounded,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    if (newPasswordController.text !=
                                        confirmPasswordController.text) {
                                      if (context.mounted)
                                        _showErrorDialog(
                                          'Passwords do not match',
                                        );
                                      return;
                                    }
                                    setState(() => isUpdating = true);
                                    try {
                                      final supervisorCollection =
                                          await FirestoreService.supervisors;
                                      final querySnapshot =
                                          await supervisorCollection
                                              .where(
                                                'UserName',
                                                isEqualTo: usernameController
                                                    .text
                                                    .trim(),
                                              )
                                              .get();
                                      if (querySnapshot.docs.isNotEmpty) {
                                        final docId =
                                            querySnapshot.docs.first.id;
                                        await supervisorCollection
                                            .doc(docId)
                                            .update({
                                              'Password': newPasswordController
                                                  .text
                                                  .trim(),
                                            });
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          _showSuccessDialog(
                                            'Password updated successfully',
                                          );
                                        }
                                      } else {
                                        if (context.mounted)
                                          _showErrorDialog(
                                            'Username not found',
                                          );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        FirestoreErrorHandler.handleError(
                                          context,
                                          e,
                                          title: 'Password Reset Error',
                                        );
                                      }
                                    } finally {
                                      if (context.mounted)
                                        setState(() => isUpdating = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final referralCode =
            _actualReferralCode ?? _referralController.text.trim();

        // 1. Validate Referral Code by searching across all admin/referal documents
        final orgId = await FirestoreService.findOrgIdByReferralCode(
          referralCode,
        );

        if (orgId == null) {
          if (context.mounted) _showErrorDialog('Invalid Referral Code');
          return;
        }

        // 2. Save org path temporarily for FirestoreService
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sup_org_path', orgId);
        // Default relative path for organization details
        final String resolvedPath = 'organisation/$orgId/data/admin';
        await prefs.setString('sup_org_doc_path', resolvedPath);

        // Refresh FirestoreService cache
        await FirestoreService.initialize();

        // 3. Authenticate within organization
        final supervisorCollection = await FirestoreService.supervisors;
        final querySnapshot = await supervisorCollection
            .where('UserName', isEqualTo: _usernameController.text.trim())
            .where('Password', isEqualTo: _passwordController.text.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final supervisorId = doc.id;
          final supervisorName =
              doc.data()['Name'] ?? _usernameController.text.trim();

          if (_isContractor && _selectedSupervisorName != null) {
            final contractorsCollection = await FirestoreService.contractors;
            final contractorQuery = await contractorsCollection
                .where('contractorName', isEqualTo: _selectedSupervisorName)
                .limit(1)
                .get();
            String? contractorField;
            if (contractorQuery.docs.isNotEmpty) {
              contractorField =
                  contractorQuery.docs.first.data()['contractorField']
                      as String?;
            }

            // Save login data
            await _saveLoginData(
              username: _usernameController.text.trim(),
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              isContractor: true,
              contractorName: _selectedSupervisorName!,
              contractorField: contractorField ?? '',
              orgId: orgId,
              resolvedPath: resolvedPath,
            );

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => ContractorEntryPage(
                    userName: _usernameController.text.trim(),
                    userDetails: {
                      'supervisorId': supervisorId,
                      'contractorName': _selectedSupervisorName!,
                      'contractorField': contractorField ?? '',
                    },
                  ),
                ),
                (route) => false,
              );
            }
          } else {
            // Save login data
            await _saveLoginData(
              username: _usernameController.text.trim(),
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              isContractor: false,
              orgId: orgId,
              resolvedPath: resolvedPath,
            );

            // Save FCM token for push notifications
            await NotificationService.saveToken(
              userId: supervisorId,
              userType: 'supervisor',
              userName: supervisorName,
            );

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => SupervisorDashboard(
                    supervisorId: supervisorId,
                    supervisorName: supervisorName,
                    username: _usernameController.text.trim(),
                  ),
                ),
                (route) => false,
              );
            }
          }
        } else {
          if (context.mounted) _showErrorDialog('Invalid username or password');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        if (context.mounted) {
          FirestoreErrorHandler.handleError(context, e, title: 'Login Error');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      onBack: () => Navigator.pop(context),
      body: Center(        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header or Org Logo
              if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: colorScheme.outline, width: 2),
                  ),
                  child: Image.network(
                    _tempLogoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.engineering_rounded,
                      size: 60,
                      color: colorScheme.primary,
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.engineering_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _tempOrgName ?? 'Supervisor Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GlassTextField(
                        controller: _referralController,
                        label: 'Referral Code / Org Name',
                        icon: Icons.business_rounded,
                        enabled: _actualReferralCode == null && _tempOrgName == null,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          label: 'LOGIN',
                          isLoading: _isLoading,
                          onPressed: _login,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
