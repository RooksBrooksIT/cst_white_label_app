import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

class ManagerConfigScreen extends StatefulWidget {
  const ManagerConfigScreen({super.key});

  @override
  _ManagerConfigScreenState createState() => _ManagerConfigScreenState();
}

class _ManagerConfigScreenState extends State<ManagerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDesignation;
  String? _selectedDepartment;
  
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  List<String> _designationList = ['Project Manager', 'Site Manager', 'Regional Manager', 'General Manager'];
  List<String> _departmentList = ['Operations', 'Finance', 'Execution', 'Logistics', 'Planning'];
  
  bool _isLoadingDesignations = true;
  bool _isPasswordVisible = false;
  int _selectedTab = 0; // 0: Create, 1: Info
  bool _isSubmitting = false;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchConfigData();
  }

  Future<void> _fetchConfigData() async {
    try {
      // Try to fetch designations
      final desigSnapshot = await FirestoreService.getCollection('managerDesignation').get();
      if (desigSnapshot.docs.isNotEmpty) {
        _designationList = desigSnapshot.docs.map((doc) => doc['Designation'] as String).toList();
      }

      // Try to fetch departments
      final deptSnapshot = await FirestoreService.getCollection('managerDepartment').get();
      if (deptSnapshot.docs.isNotEmpty) {
        _departmentList = deptSnapshot.docs.map((doc) => doc['Department'] as String).toList();
      }

      setState(() {
        _isLoadingDesignations = false;
      });
    } catch (e) {
      debugPrint('Error fetching config data: $e');
      setState(() {
        _isLoadingDesignations = false;
      });
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    try {
      final querySnapshot = await FirestoreService.getCollection('manager')
          .where('UserName', isEqualTo: username.trim())
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isContactNoUnique(String contactNo) async {
    try {
      final querySnapshot = await FirestoreService.getCollection('manager')
          .where('ContactNo', isEqualTo: contactNo.trim())
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final username = _userNameController.text.trim();
      final contactNo = _contactNoController.text.trim();

      if (!(await _isUsernameUnique(username))) {
        _showErrorSnackBar('Username "$username" is already taken.');
        setState(() => _isSubmitting = false);
        return;
      }

      if (!(await _isContactNoUnique(contactNo))) {
        _showErrorSnackBar('Contact number "$contactNo" is already registered.');
        setState(() => _isSubmitting = false);
        return;
      }

      await _createManagerAccount();
    } catch (e) {
      _showErrorSnackBar('Error checking uniqueness: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _createManagerAccount() async {
    try {
      final snapshot = await FirestoreService.getCollection('manager').get();
      int maxNumber = 0;
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final match = RegExp(r'MG(\d+)_').firstMatch(id);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxNumber) maxNumber = num;
        }
      }
      
      final nextNumber = maxNumber + 1;
      final managerNumber = nextNumber.toString().padLeft(3, '0');
      final username = _userNameController.text.trim();
      final managerId = 'MG${managerNumber}_$username';

      final managerData = {
        'ManagerId': managerId,
        'FullName': _fullNameController.text.trim(),
        'UserName': username,
        'Password': _passwordController.text.trim(),
        'Designation': _selectedDesignation,
        'Department': _selectedDepartment,
        'ContactNo': _contactNoController.text.trim(),
        'Email': _emailController.text.trim(),
        'Status': 'Active',
        'CreatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('manager').doc(managerId).set(managerData);

      _showSuccessDialog();
      _resetForm();
    } catch (e) {
      _showErrorSnackBar('Failed to create manager account: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animation/success.json', width: 100, height: 100, repeat: false),
              const SizedBox(height: 16),
              Text('Success!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              const Text('Manager details have been saved successfully.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _fullNameController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _contactNoController.clear();
    _emailController.clear();
    setState(() {
      _selectedDesignation = null;
      _selectedDepartment = null;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Manager Configuration',
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildTabToggle(),
          const SizedBox(height: 16),
          Expanded(child: _selectedTab == 0 ? _buildCreateForm() : _buildInfoTable()),
        ],
      ),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            _buildTabButton('Create Manager', 0),
            _buildTabButton('Managers Info', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField('Full Name', _fullNameController, isRequired: true, icon: Icons.person),
            const SizedBox(height: 16),
            _buildTextField('User Name', _userNameController, isRequired: true, icon: Icons.alternate_email),
            const SizedBox(height: 16),
            _buildTextField('Password', _passwordController, isRequired: true, isPassword: true, icon: Icons.lock),
            const SizedBox(height: 16),
            _buildDropdown('Designation', _selectedDesignation, _designationList, (val) => setState(() => _selectedDesignation = val), icon: Icons.badge),
            const SizedBox(height: 16),
            _buildDropdown('Department', _selectedDepartment, _departmentList, (val) => setState(() => _selectedDepartment = val), icon: Icons.business),
            const SizedBox(height: 16),
            _buildTextField('Contact No', _contactNoController, isRequired: true, keyboardType: TextInputType.phone, icon: Icons.phone),
            const SizedBox(height: 16),
            _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress, icon: Icons.email),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, bool isPassword = false, TextInputType? keyboardType, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${isRequired ? ' *' : ''}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: primaryColor),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ) : null,
            hintText: 'Enter $label',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
          ),
          validator: (value) => (isRequired && (value == null || value.isEmpty)) ? 'Field required' : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
          ),
          validator: (val) => val == null ? 'Please select $label' : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _validateAndSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _resetForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: primaryColor),
            ),
            child: Text('Reset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('manager').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final managers = snapshot.data!.docs;
        if (managers.isEmpty) return const Center(child: Text('No managers found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: managers.length,
          itemBuilder: (context, index) {
            final data = managers[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.person, color: primaryColor)),
                title: Text(data['FullName'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${data['Designation']} • ${data['Department']}'),
                trailing: Text(data['Status'] ?? 'Active', style: TextStyle(color: (data['Status'] == 'Active') ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                onTap: () => _showManagerDetails(data),
              ),
            );
          },
        );
      },
    );
  }

  void _showManagerDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['FullName'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
            const Divider(height: 32),
            _buildDetailRow('Manager ID', data['ManagerId']),
            _buildDetailRow('Username', data['UserName']),
            _buildDetailRow('Designation', data['Designation']),
            _buildDetailRow('Department', data['Department']),
            _buildDetailRow('Contact', data['ContactNo']),
            _buildDetailRow('Email', data['Email'] ?? 'N/A'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
