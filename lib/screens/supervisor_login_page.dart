import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contractor_entry_page.dart';
import 'supervisor_dashboard.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

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

  // SharedPreferences keys - SUPERVISOR specific
  static const String _isLoggedInKey = 'sup_isLoggedIn';
  static const String _userTypeKey = 'sup_userType';
  static const String _usernameKey = 'sup_username';
  static const String _supervisorIdKey = 'sup_supervisorId';
  static const String _supervisorNameKey = 'sup_supervisorName';
  static const String _contractorNameKey = 'sup_contractorName';
  static const String _contractorFieldKey = 'sup_contractorField';
  static const String _isContractorKey = 'sup_isContractor';
  static const String _orgPathKey = 'sup_org_path';

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
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final username = prefs.getString(_usernameKey) ?? '';
        final supervisorId = prefs.getString(_supervisorIdKey) ?? '';
        final supervisorName = prefs.getString(_supervisorNameKey) ?? '';
        final isContractor = prefs.getBool(_isContractorKey) ?? false;

        if (isContractor) {
          final contractorName = prefs.getString(_contractorNameKey) ?? '';
          final contractorField = prefs.getString(_contractorFieldKey) ?? '';

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

  // Save login data to SharedPreferences
  Future<void> _saveLoginData({
    required String username,
    required String supervisorId,
    required String supervisorName,
    required bool isContractor,
    String? contractorName,
    String? contractorField,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(
        _userTypeKey,
        isContractor ? 'contractor' : 'supervisor',
      );
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_supervisorIdKey, supervisorId);
      await prefs.setString(_supervisorNameKey, supervisorName);
      await prefs.setBool(_isContractorKey, isContractor);

      if (isContractor && contractorName != null) {
        await prefs.setString(_contractorNameKey, contractorName);
        await prefs.setString(_contractorFieldKey, contractorField ?? '');
      }
    } catch (e) {
      debugPrint('Error saving login data: $e');
    }
  }

  // Clear login data (for logout)
  static Future<void> clearLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      await prefs.remove(_userTypeKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_supervisorIdKey);
      await prefs.remove(_supervisorNameKey);
      await prefs.remove(_isContractorKey);
      await prefs.remove(_contractorNameKey);
      await prefs.remove(_contractorFieldKey);
      await prefs.remove(_orgPathKey);
    } catch (e) {
      debugPrint('Error clearing login data: $e');
    }
  }

  Future<void> _fetchContractorNames() async {
    try {
      final contractorsCollection = await FirestoreService.contractors;
      final querySnapshot = await contractorsCollection.get();
      final names = querySnapshot.docs
          .map(
            (doc) =>
                doc.data()['contractorName'] as String?,
          )
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
            return GlassCard(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    GlassTextField(
                      controller: usernameController,
                      label: 'Username',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 16.0),
                    GlassTextField(
                      controller: newPasswordController,
                      label: 'New Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16.0),
                    GlassTextField(
                      controller: confirmPasswordController,
                      label: 'Confirm New Password',
                      icon: Icons.lock_reset,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: GlassButton(
                            label: 'Cancel',
                            isSecondary: true,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Flexible(
                          child: GlassButton(
                            label: 'Update',
                            isLoading: isUpdating,
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    if (newPasswordController.text !=
                                        confirmPasswordController.text) {
                                      if (context.mounted) _showErrorDialog(
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
                                        final supervisorCollection =
                                            await FirestoreService.supervisors;
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
                                        if (context.mounted) _showErrorDialog('Username not found');
                                      }
                                    } catch (e) {
                                      if (context.mounted) _showErrorDialog(
                                        'Failed to update password. Please try again.',
                                      );
                                    } finally {
                                      if (context.mounted) setState(() => isUpdating = false);
                                    }
                                  },
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
        final referralCode = _referralController.text.trim();
        
        // 1. Validate Referral Code
        final referralDoc = await FirebaseFirestore.instance
            .collection('referralCodes')
            .doc(referralCode)
            .get();

        if (!referralDoc.exists) {
          if (context.mounted) _showErrorDialog('Invalid Referral Code');
          return;
        }

        final orgId = referralDoc.data()?['dynamicPath'] as String?;
        final fullConfigPath = referralDoc.data()?['fullConfigPath'] as String?;
        if (orgId == null) {
          if (context.mounted) _showErrorDialog('Organization configuration error');
          return;
        }

        // 2. Save org path temporarily for FirestoreService
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_orgPathKey, orgId);
        final String resolvedPath = fullConfigPath ?? 'organisation/$orgId/admin/data';
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
              doc.data()['Name'] ??
              _usernameController.text.trim();

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
            );

            if (context.mounted) {
              Navigator.pushReplacement(
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
              );
            }
          } else {
            // Save login data
            await _saveLoginData(
              username: _usernameController.text.trim(),
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              isContractor: false,
            );

            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SupervisorDashboard(
                    supervisorId: supervisorId,
                    supervisorName: supervisorName,
                    username: _usernameController.text.trim(),
                  ),
                ),
              );
            }
          }
        } else {
          if (context.mounted) _showErrorDialog('Invalid username or password');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        if (context.mounted) _showErrorDialog('An error occurred. Please try again.');
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
    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      onBack: () => Navigator.pushReplacementNamed(context, '/authSelection'),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.supervisor_account_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Supervisor Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GlassTextField(
                        controller: _referralController,
                        label: 'Referral Code',
                        icon: Icons.business_rounded,
                        validator: (value) =>
                            (value == null || value.isEmpty)
                            ? 'Referral Code is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_rounded,
                        validator: (value) =>
                            (value == null || value.isEmpty)
                            ? 'UserName is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_rounded,
                        isPassword: true,
                        validator: (value) =>
                            (value == null || value.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      
                      Theme(
                        data: Theme.of(context).copyWith(
                          unselectedWidgetColor: Colors.white70,
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'Is Contractor',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: _isContractor,
                          activeColor: colorScheme.primary,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              _isContractor = val ?? false;
                              if (!_isContractor) {
                                _selectedSupervisorName = null;
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      if (_isContractor) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          dropdownColor: Colors.blueGrey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Contractor Name',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.supervisor_account, color: Theme.of(context).primaryColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                          ),
                          value: _selectedSupervisorName,
                          items: _supervisorNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSupervisorName = val);
                          },
                          validator: (value) =>
                              _isContractor && value == null ? 'Required' : null,
                        ),
                      ],

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        label: 'LOGIN',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _login,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
