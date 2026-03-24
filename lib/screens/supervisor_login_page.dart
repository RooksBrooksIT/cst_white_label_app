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
            final theme = Theme.of(context);
            final primary = theme.primaryColor;

            return Container(
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
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
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_reset,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: const BorderSide(color: Colors.white54),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Flexible(
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update',
                                    style: TextStyle(color: Colors.white),
                                  ),
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
    final primary = Theme.of(context).primaryColor;

    return GlassScaffold(
      onBack: () => Navigator.pushReplacementNamed(context, '/authSelection'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.supervisor_account_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Supervisor Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your dashboard',
                style: TextStyle(
                  fontSize: 16,
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
                          activeColor: primary,
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
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Contractor Name',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(
                              Icons.supervisor_account,
                              color: Colors.white70,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          value: _selectedSupervisorName,
                          items: _supervisorNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
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
