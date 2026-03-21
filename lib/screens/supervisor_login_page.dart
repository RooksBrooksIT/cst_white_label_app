import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/supervisor_dashboard.dart';

// Supervisor teal accent
const _kAccent = Color(0xFF00897B);

class Supervisor_LoginPage extends StatefulWidget {
  const Supervisor_LoginPage({super.key});

  @override
  _Supervisor_LoginPageState createState() => _Supervisor_LoginPageState();

  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_userTypeKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_supervisorIdKey);
    await prefs.remove(_supervisorNameKey);
    await prefs.remove(_isContractorKey);
    await prefs.remove(_contractorNameKey);
    await prefs.remove(_contractorFieldKey);
  }

  static const String _isLoggedInKey = 'sup_isLoggedIn';
  static const String _userTypeKey = 'sup_userType';
  static const String _usernameKey = 'sup_username';
  static const String _supervisorIdKey = 'sup_supervisorId';
  static const String _supervisorNameKey = 'sup_supervisorName';
  static const String _contractorNameKey = 'sup_contractorName';
  static const String _contractorFieldKey = 'sup_contractorField';
  static const String _isContractorKey = 'sup_isContractor';
}

class _Supervisor_LoginPageState extends State<Supervisor_LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  bool _isContractor = false;
  List<String> _supervisorNames = [];
  String? _selectedSupervisorName;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fetchContractorNames();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(Supervisor_LoginPage._isLoggedInKey) ?? false;
      if (isLoggedIn && mounted) {
        final username = prefs.getString(Supervisor_LoginPage._usernameKey) ?? '';
        final supervisorId = prefs.getString(Supervisor_LoginPage._supervisorIdKey) ?? '';
        final supervisorName = prefs.getString(Supervisor_LoginPage._supervisorNameKey) ?? '';
        final isContractor = prefs.getBool(Supervisor_LoginPage._isContractorKey) ?? false;
        if (isContractor) {
          final contractorName = prefs.getString(Supervisor_LoginPage._contractorNameKey) ?? '';
          final contractorField = prefs.getString(Supervisor_LoginPage._contractorFieldKey) ?? '';
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ContractorEntryPage(userName: username, userDetails: {'supervisorId': supervisorId, 'contractorName': contractorName, 'contractorField': contractorField})));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SupervisorDashboard(supervisorId: supervisorId, supervisorName: supervisorName, username: username)));
        }
      } else {
        _controller.forward();
      }
    } catch (e) { debugPrint('Error checking login status: $e'); }
  }

  Future<void> _saveLoginData({required String username, required String supervisorId, required String supervisorName, required bool isContractor, String? contractorName, String? contractorField}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Supervisor_LoginPage._isLoggedInKey, true);
    await prefs.setString(Supervisor_LoginPage._userTypeKey, isContractor ? 'contractor' : 'supervisor');
    await prefs.setString(Supervisor_LoginPage._usernameKey, username);
    await prefs.setString(Supervisor_LoginPage._supervisorIdKey, supervisorId);
    await prefs.setString(Supervisor_LoginPage._supervisorNameKey, supervisorName);
    await prefs.setBool(Supervisor_LoginPage._isContractorKey, isContractor);
    if (isContractor && contractorName != null) {
      await prefs.setString(Supervisor_LoginPage._contractorNameKey, contractorName);
      await prefs.setString(Supervisor_LoginPage._contractorFieldKey, contractorField ?? '');
    }
  }

  Future<void> _fetchContractorNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('contractors').get();
      final names = snapshot.docs.map((d) => d.data()['contractorName'] as String?).where((n) => n != null).cast<String>().toList();
      setState(() => _supervisorNames = names);
    } catch (e) { debugPrint('Error fetching contractor names: $e'); }
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('supervisor').where('UserName', isEqualTo: _usernameController.text.trim()).where('Password', isEqualTo: _passwordController.text.trim()).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final supervisorId = doc.id;
          final supervisorName = doc.data()['Name'] ?? _usernameController.text.trim();
          if (_isContractor && _selectedSupervisorName != null) {
            final contractorQuery = await FirebaseFirestore.instance.collection('contractors').where('contractorName', isEqualTo: _selectedSupervisorName).limit(1).get();
            String? contractorField;
            if (contractorQuery.docs.isNotEmpty) contractorField = contractorQuery.docs.first.data()['contractorField'] as String?;
            await _saveLoginData(username: _usernameController.text.trim(), supervisorId: supervisorId, supervisorName: supervisorName, isContractor: true, contractorName: _selectedSupervisorName!, contractorField: contractorField ?? '');
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ContractorEntryPage(userName: _usernameController.text.trim(), userDetails: {'supervisorId': supervisorId, 'contractorName': _selectedSupervisorName!, 'contractorField': contractorField ?? ''})));
          } else {
            await _saveLoginData(username: _usernameController.text.trim(), supervisorId: supervisorId, supervisorName: supervisorName, isContractor: false);
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SupervisorDashboard(supervisorId: supervisorId, supervisorName: supervisorName, username: _usernameController.text.trim())));
          }
        } else { _showError('Invalid username or password'); }
      } catch (e) { debugPrint('Login error: $e'); _showError('An error occurred. Please try again.'); }
      finally { if (mounted) setState(() => _isLoading = false); }
    }
  }

  void _showForgotPasswordDialog() {
    final usernameCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isUpdating = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, color: _kAccent)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(controller: usernameCtrl, label: 'Username', icon: Icons.person),
            const SizedBox(height: 12),
            _dialogField(controller: newPassCtrl, label: 'New Password', icon: Icons.lock_outline, obscure: true),
            const SizedBox(height: 12),
            _dialogField(controller: confirmPassCtrl, label: 'Confirm Password', icon: Icons.lock_reset, obscure: true),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isUpdating ? null : () async {
                if (newPassCtrl.text != confirmPassCtrl.text) { _showError('Passwords do not match'); return; }
                setD(() => isUpdating = true);
                try {
                  final q = await FirebaseFirestore.instance.collection('supervisor').where('UserName', isEqualTo: usernameCtrl.text.trim()).get();
                  if (q.docs.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('supervisor').doc(q.docs.first.id).update({'Password': newPassCtrl.text.trim()});
                    Navigator.pop(ctx);
                    _showSuccess('Password updated!');
                  } else { _showError('Username not found'); }
                } catch (_) { _showError('Failed to update password.'); }
                finally { setD(() => isUpdating = false); }
              },
              child: isUpdating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField({required TextEditingController controller, required String label, required IconData icon, bool obscure = false}) {
    return TextField(
      controller: controller, obscureText: obscure,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: _kAccent, size: 20), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00574B), Color(0xFF00897B), Color(0xFF26A69A)]),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
                    const SizedBox(height: 28),
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.2))), child: const Icon(Icons.supervisor_account_rounded, color: Colors.white, size: 32)),
                    const SizedBox(height: 16),
                    const Text('Supervisor Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Sign in to manage site activities', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                  ]),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Form(
                          key: _formKey,
                          child: Column(children: [
                            _buildField(controller: _usernameController, label: 'Username', icon: Icons.person_outline_rounded, validator: (v) => (v == null || v.isEmpty) ? 'Username is required' : null),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            const SizedBox(height: 12),

                            // Is Contractor toggle (styled)
                            Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: CheckboxListTile(
                                title: const Text('Log in as Contractor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                                value: _isContractor,
                                activeColor: _kAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onChanged: (val) => setState(() { _isContractor = val ?? false; if (!_isContractor) _selectedSupervisorName = null; }),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),

                            if (_isContractor) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Contractor Name',
                                  prefixIcon: const Icon(Icons.engineering_rounded, color: _kAccent, size: 22),
                                  filled: true, fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                ),
                                items: _supervisorNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                value: _selectedSupervisorName,
                                onChanged: (val) => setState(() => _selectedSupervisorName = val),
                                validator: (val) => _isContractor && (val == null || val.isEmpty) ? 'Please select a contractor' : null,
                              ),
                            ],

                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _showForgotPasswordDialog, child: const Text('Forgot Password?', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w600)))),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00574B), Color(0xFF26A69A)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))]),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, required String? Function(String?) validator}) {
    return TextFormField(
      controller: controller, validator: validator,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF64748B)), prefixIcon: Icon(icon, color: _kAccent, size: 22), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController, obscureText: !_showPassword,
      validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
      decoration: InputDecoration(labelText: 'Password', labelStyle: const TextStyle(color: Color(0xFF64748B)), prefixIcon: const Icon(Icons.lock_outline_rounded, color: _kAccent, size: 22), suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _kAccent, size: 20), onPressed: () => setState(() => _showPassword = !_showPassword)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
    );
  }
}
