import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';

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

  List<String> _designationList = [
    'Project Manager',
    'Site Manager',
    'Regional Manager',
    'General Manager',
  ];
  List<String> _departmentList = [
    'Operations',
    'Finance',
    'Execution',
    'Logistics',
    'Planning',
  ];

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
      final desigSnapshot = await FirestoreService.getCollection(
        'managerDesignation',
      ).get();
      if (desigSnapshot.docs.isNotEmpty) {
        _designationList = desigSnapshot.docs
            .map((doc) => doc['Designation'] as String)
            .toList();
      }

      // Try to fetch departments
      final deptSnapshot = await FirestoreService.getCollection(
        'managerDepartment',
      ).get();
      if (deptSnapshot.docs.isNotEmpty) {
        _departmentList = deptSnapshot.docs
            .map((doc) => doc['Department'] as String)
            .toList();
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
      final querySnapshot = await FirestoreService.getCollection(
        'manager',
      ).where('UserName', isEqualTo: username.trim()).get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isContactNoUnique(String contactNo) async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'manager',
      ).where('ContactNo', isEqualTo: contactNo.trim()).get();
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
        _showErrorSnackBar(
          'Contact number "$contactNo" is already registered.',
        );
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

      await FirestoreService.getCollection(
        'manager',
      ).doc(managerId).set(managerData);

      _showSuccessDialog();
      _resetForm();
    } catch (e) {
      _showErrorSnackBar('Failed to create manager account: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: isDesktop ? 120.0 : 100.0,
                  height: isDesktop ? 120.0 : 100.0,
                  repeat: false,
                ),
                SizedBox(height: isDesktop ? 20.0 : 16.0),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: isDesktop ? 22.0 : 20.0,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: isDesktop ? 12.0 : 8.0),
                Text(
                  'Manager details have been saved successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
                ),
                SizedBox(height: isDesktop ? 32.0 : 24.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40.0 : 32.0,
                      vertical: isDesktop ? 16.0 : 12.0,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: TextStyle(fontSize: isDesktop ? 16.0 : 14.0),
                  ),
                ),
              ],
            ),
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
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      title: 'Manager Configuration',
      onBack: () => Navigator.pop(context),
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: Column(
              children: [
                SizedBox(height: isDesktop ? 24.0 : 16.0),
                _buildTabToggle(isDesktop, isTablet, isMobile),
                SizedBox(height: isDesktop ? 24.0 : 16.0),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 900.0 : double.infinity,
                      ),
                      child: _selectedTab == 0
                          ? _buildCreateForm(isDesktop, isTablet, isMobile)
                          : _buildInfoTable(isDesktop, isTablet, isMobile),
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

  Widget _buildTabToggle(bool isDesktop, bool isTablet, bool isMobile) {
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: darkCardBg,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: darkCardBg.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildTabButton('Create Manager', 0, isDesktop, isTablet, isMobile),
            _buildTabButton('Managers Info', 1, isDesktop, isTablet, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String title,
    int index,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 16.0 : 12.0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 16.0 : 14.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF0A183D) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm(bool isDesktop, bool isTablet, bool isMobile) {
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0)),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
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
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                'Full Name',
                _fullNameController,
                isRequired: true,
                icon: Icons.person,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildTextField(
                'User Name',
                _userNameController,
                isRequired: true,
                icon: Icons.alternate_email,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildTextField(
                'Password',
                _passwordController,
                isRequired: true,
                isPassword: true,
                icon: Icons.lock,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildDropdown(
                'Designation',
                _selectedDesignation,
                _designationList,
                (val) => setState(() => _selectedDesignation = val),
                icon: Icons.badge,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildDropdown(
                'Department',
                _selectedDepartment,
                _departmentList,
                (val) => setState(() => _selectedDepartment = val),
                icon: Icons.business,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildTextField(
                'Contact No',
                _contactNoController,
                isRequired: true,
                keyboardType: TextInputType.phone,
                icon: Icons.phone,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              _buildTextField(
                'Email',
                _emailController,
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              SizedBox(height: isDesktop ? 36.0 : 28.0),
              _buildActionButtons(isDesktop, isTablet, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    IconData? icon,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? ' *' : ''}',
          style: TextStyle(
            fontSize: isDesktop ? 15.0 : 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFCBD5E1),
          ),
        ),
        SizedBox(height: isDesktop ? 10.0 : 8.0),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: primaryColor,
              size: isDesktop ? 22.0 : 20.0,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF5A759E),
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  )
                : null,
            hintText: 'Enter $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
          validator: (value) => (isRequired && (value == null || value.isEmpty))
              ? 'Field required'
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    IconData? icon,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(
            fontSize: isDesktop ? 15.0 : 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFCBD5E1),
          ),
        ),
        SizedBox(height: isDesktop ? 10.0 : 8.0),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: primaryColor,
              size: isDesktop ? 22.0 : 20.0,
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Select $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
          validator: (val) => val == null ? 'Please select $label' : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDesktop, bool isTablet, bool isMobile) {
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkCardBg,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: darkCardBg.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: isDesktop ? 24.0 : 20.0,
                      width: isDesktop ? 24.0 : 20.0,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: isDesktop ? 16.0 : 15.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 16.0 : 12.0),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _resetForm,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: Text(
                'Reset',
                style: TextStyle(
                  fontSize: isDesktop ? 16.0 : 15.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTable(bool isDesktop, bool isTablet, bool isMobile) {
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('manager').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final managers = snapshot.data!.docs;
        if (managers.isEmpty) {
          return Center(
            child: Text(
              'No managers found.',
              style: TextStyle(
                fontSize: isDesktop ? 16.0 : 14.0,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 32.0 : 16.0)),
          itemCount: managers.length,
          itemBuilder: (context, index) {
            final data = managers[index].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.only(bottom: isDesktop ? 16.0 : 12.0),
              color: darkCardBg,
              elevation: 4,
              shadowColor: darkCardBg.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  data['FullName'] ?? 'No Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: isDesktop ? 16.0 : 14.0,
                  ),
                ),
                subtitle: Text(
                  '${data['Designation']} • ${data['Department']}',
                  style: TextStyle(
                    color: const Color(0xFFCBD5E1),
                    fontSize: isDesktop ? 14.0 : 12.0,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (data['Status'] == 'Active')
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['Status'] ?? 'Active',
                    style: TextStyle(
                      color: (data['Status'] == 'Active')
                          ? const Color(0xFF10B981)
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 13.0 : 11.5,
                    ),
                  ),
                ),
                onTap: () =>
                    _showManagerDetails(data, isDesktop, isTablet, isMobile),
              ),
            );
          },
        );
      },
    );
  }

  void _showManagerDetails(
    Map<String, dynamic> data,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['FullName'],
              style: TextStyle(
                fontSize: isDesktop ? 26.0 : 24.0,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            Divider(height: isDesktop ? 40.0 : 32.0),
            _buildDetailRow(
              'Manager ID',
              data['ManagerId'],
              isDesktop,
              isTablet,
              isMobile,
            ),
            _buildDetailRow(
              'Username',
              data['UserName'],
              isDesktop,
              isTablet,
              isMobile,
            ),
            _buildDetailRow(
              'Designation',
              data['Designation'],
              isDesktop,
              isTablet,
              isMobile,
            ),
            _buildDetailRow(
              'Department',
              data['Department'],
              isDesktop,
              isTablet,
              isMobile,
            ),
            _buildDetailRow(
              'Contact',
              data['ContactNo'],
              isDesktop,
              isTablet,
              isMobile,
            ),
            _buildDetailRow(
              'Email',
              data['Email'] ?? 'N/A',
              isDesktop,
              isTablet,
              isMobile,
            ),
            SizedBox(height: isDesktop ? 24.0 : 16.0),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 12.0 : 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: isDesktop ? 15.0 : 13.0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 15.0 : 13.0,
            ),
          ),
        ],
      ),
    );
  }
}
