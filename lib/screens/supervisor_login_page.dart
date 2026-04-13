import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'contractor_entry_page.dart';
import 'supervisor_dashboard.dart';
import '../services/firestore_service.dart';
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
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
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
                        fillColor: const Color(0xFFF8FAFC),
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
        final String resolvedPath = 'organisation/$orgId/admin/data';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header or Org Logo
              if (_tempLogoUrl != null && _tempLogoUrl!.isNotEmpty)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: DecorationImage(
                      image: NetworkImage(_tempLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.supervisor_account_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _tempOrgName ?? 'Supervisor Login',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              if (_tempOrgName != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Supervisor Account',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Sign in to your dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _referralController,
                        readOnly: _referralController.text.isNotEmpty,
                        decoration: InputDecoration(
                          labelText: 'Referral Code',
                          prefixIcon: Icon(
                            Icons.business_outlined,
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Referral Code is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
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
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'UserName is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'Is Contractor',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: _isContractor,
                          activeColor: colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _isContractor = val ?? false;
                              if (!_isContractor) {
                                _selectedSupervisorName = null;
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_isContractor) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Contractor Name',
                            prefixIcon: Icon(
                              Icons.supervisor_account_outlined,
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
                          validator: (value) => _isContractor && value == null
                              ? 'Required'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
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
