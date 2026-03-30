import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

class SiteSupervisorConfig extends StatefulWidget {
  const SiteSupervisorConfig({super.key});
  @override
  _SiteSupervisorConfigState createState() => _SiteSupervisorConfigState();
}

class _SiteSupervisorConfigState extends State<SiteSupervisorConfig> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isPasswordVisible = false;
  int _selectedTab = 0; // 0: Create, 1: Info
  bool _isSubmitting = false;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
  }

  // Function to check if username already exists
  Future<bool> _isUsernameUnique(String username) async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'supervisor',
      ).where('UserName', isEqualTo: username.trim()).get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // Function to check if contact number already exists
  Future<bool> _isContactNoUnique(String contactNo) async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'supervisor',
      ).where('ContactNo', isEqualTo: contactNo.trim()).get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // Function to validate unique fields and submit form
  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final username = _userNameController.text.trim();
      final contactNo = _contactNoController.text.trim();

      // Check for unique username
      bool isUsernameUnique = await _isUsernameUnique(username);
      if (!isUsernameUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Username "$username" is already taken. Please choose a different one.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Check for unique contact number
      bool isContactNoUnique = await _isContactNoUnique(contactNo);
      if (!isContactNoUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contact number "$contactNo" is already registered. Please use a different one.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // If both are unique, proceed with saving
      await _createSupervisorAccount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking uniqueness: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _editSupervisorPassword(
    String documentId,
    String supervisorName,
    String currentPassword,
  ) async {
    TextEditingController newPasswordController = TextEditingController(
      text: currentPassword,
    );
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Password',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editing password for "$supervisorName"',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(newPasswordController.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Save', style: TextStyle()),
            ),
          ],
        ),
      ),
    ).then((newPassword) async {
      if (newPassword != null && newPassword.isNotEmpty) {
        try {
          // Show loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Updating password...'),
                ],
              ),
              backgroundColor: Colors.blue,
            ),
          );

          // Update the Password field in Firestore
          await FirestoreService.getCollection(
            'supervisor',
          ).doc(documentId).update({'Password': newPassword});

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text('Password updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Refresh the UI by triggering rebuild
          setState(() {});
        } catch (e) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, size: 20),
                  SizedBox(width: 8),
                  Text('Failed to update password: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  // Function to create supervisor account
  Future<void> _createSupervisorAccount() async {
    try {
      final snapshot = await FirestoreService.getCollection('supervisor').get();
      int maxNumber = 0;
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final match = RegExp(r'SP(\d+)_').firstMatch(id);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxNumber) {
            maxNumber = num;
          }
        }
      }
      final nextNumber = maxNumber + 1;
      final supervisorNumber = nextNumber.toString().padLeft(3, '0');
      final username = _userNameController.text.trim();
      final supervisorId = 'SP${supervisorNumber}_$username';
      final documentId = supervisorId;

      final supervisorData = {
        'SupervisorId': supervisorId,
        'FullName': _fullNameController.text.trim(),
        'UserName': username,
        'Password': _passwordController.text.trim(),
        'Designation': _designationController.text.trim(),
        'ContactNo': _contactNoController.text.trim(),
        'Email': _emailController.text.trim(),
        'Photo': 'Photo URL or Placeholder',
        'CreatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection(
        'supervisor',
      ).doc(documentId).set(supervisorData);

      // Show success dialog
      _showSuccessDialog();

      // Clear form
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, size: 20),
              SizedBox(width: 8),
              Text('Failed to create supervisor account: $e'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: 100,
                  height: 100,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your supervisor details have been saved successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _fullNameController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _contactNoController.clear();
    _emailController.clear();
    _designationController.clear();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _designationController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Site Supervisor Configuration',
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Top Two Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedTab = 0;
                          });
                        },
                        child: Text(
                          'Create Supervisor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedTab == 0
                                ? Colors.white
                                : primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                        child: Text(
                          'Supervisors Info',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedTab == 1
                                ? Colors.white
                                : primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _selectedTab == 0 ? _buildCreateForm() : _buildInfoTable(),
          ),
        ],
      ),
    );
  }

  // ----------------------- CREATE TAB CONTENT -----------------------
  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTextField('Full Name', _fullNameController, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField('User Name', _userNameController, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField(
              'Password',
              _passwordController,
              isRequired: true,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Designation',
              _designationController,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Contact No',
              _contactNoController,
              keyboardType: TextInputType.phone,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Email',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildPhotoUpload(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.person_add_alt_1, size: 40, color: primaryColor),
              const SizedBox(height: 8),
              Text(
                'Create Supervisor Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Please fill in all required fields (*)',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(),
            filled: true,
            fillColor: Colors.grey[50],
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
          ),
          obscureText: isPassword ? !_isPasswordVisible : false,
          keyboardType: keyboardType,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (label == 'Contact No' && value != null && value.isNotEmpty) {
              if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                return 'Please enter a valid contact number';
              }
            }
            if (label == 'Email' && value != null && value.isNotEmpty) {
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email address';
              }
            }
            return null;
          },
          cursorColor: primaryColor,
          style: TextStyle(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supervisor Photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 40),
                const SizedBox(height: 8),
                Text('Upload Supervisor Photo', style: TextStyle()),
                const SizedBox(height: 4),
                Text('(Optional)', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text('Create Account', style: TextStyle(fontSize: 16)),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 40),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _resetForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: primaryColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 20, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  'Reset',
                  style: TextStyle(fontSize: 16, color: primaryColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------- INFO TAB CONTENT -----------------------
  Widget _buildInfoTable() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info, color: primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Supervisors Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirestoreService.getCollection('supervisor').get(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      '$count supervisors',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: FirestoreService.getCollection('supervisor').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading supervisors...',
                        style: TextStyle(fontSize: 16, color: primaryColor),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 50, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load supervisors',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null || data.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 60),
                      SizedBox(height: 16),
                      Text(
                        'No Supervisors Found',
                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create your first supervisor account',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              final supervisors = data.docs;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Supervisor ID
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'SUPERVISOR ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Photo
                              SizedBox(
                                width: 70,
                                child: Text(
                                  'PHOTO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Name
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'NAME',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Password
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'PASSWORD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Edit
                              SizedBox(
                                width: 60,
                                child: Text(
                                  'ACTION',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Table rows
                        ...supervisors.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final photoUrl = data['Photo'] ?? '';
                          final supervisorName = data['FullName'] ?? '';
                          final supervisorId = data['SupervisorId'] ?? '';
                          final password = data['Password'] ?? '';
                          final designation = data['Designation'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(blurRadius: 2, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Supervisor ID
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supervisorId,
                                        style: const TextStyle(
                                          fontSize: 13,

                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (designation.isNotEmpty)
                                        Text(
                                          designation,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                // Photo
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: ClipOval(
                                    child:
                                        photoUrl.toString().isNotEmpty &&
                                            photoUrl !=
                                                'Photo URL or Placeholder'
                                        ? Image.network(
                                            photoUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 60,
                                                      height: 60,

                                                      child: Icon(
                                                        Icons.person,
                                                        size: 30,
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,

                                            child: Icon(Icons.person, size: 30),
                                          ),
                                  ),
                                ),
                                // Name
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    supervisorName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Password
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    password,
                                    style: TextStyle(
                                      fontSize: 13,

                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Monospace',
                                    ),
                                  ),
                                ),
                                // Edit Icon
                                SizedBox(
                                  width: 60,
                                  child: IconButton(
                                    onPressed: () {
                                      _editSupervisorPassword(
                                        doc.id,
                                        supervisorName,
                                        password,
                                      );
                                    },
                                    icon: Icon(
                                      Icons.edit,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit Password',
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
