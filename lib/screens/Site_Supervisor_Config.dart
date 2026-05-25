import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/dialog_utils.dart';

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
  File? _imageFile;

  final ImagePicker _picker = ImagePicker();

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

  Future<void> _editSupervisorInfo(
    String documentId,
    Map<String, dynamic> currentData,
  ) async {
    final _editFormKey = GlobalKey<FormState>();
    TextEditingController fullNameCtrl = TextEditingController(text: currentData['FullName'] ?? '');
    TextEditingController userNameCtrl = TextEditingController(text: currentData['UserName'] ?? '');
    TextEditingController passwordCtrl = TextEditingController(text: currentData['Password'] ?? '');
    TextEditingController designationCtrl = TextEditingController(text: currentData['Designation'] ?? '');
    TextEditingController contactNoCtrl = TextEditingController(text: currentData['ContactNo'] ?? '');
    TextEditingController emailCtrl = TextEditingController(text: currentData['Email'] ?? '');
    
    bool isPasswordVisible = false;
    File? newImageFile;
    String existingPhotoUrl = currentData['Photo'] ?? '';
    bool isSubmittingEdit = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Supervisor',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: _editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo Upload
                    GestureDetector(
                      onTap: () async {
                        try {
                          final XFile? pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (pickedFile != null) {
                            setDialogState(() {
                              newImageFile = File(pickedFile.path);
                            });
                          }
                        } catch (e) {
                          // Ignore error
                        }
                      },
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: primaryColor),
                          image: newImageFile != null
                              ? DecorationImage(image: FileImage(newImageFile!), fit: BoxFit.cover)
                              : (existingPhotoUrl.isNotEmpty && existingPhotoUrl != 'Photo URL or Placeholder'
                                  ? DecorationImage(image: NetworkImage(existingPhotoUrl), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: newImageFile == null && (existingPhotoUrl.isEmpty || existingPhotoUrl == 'Photo URL or Placeholder')
                            ? Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: userNameCtrl,
                      decoration: InputDecoration(labelText: 'User Name', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: primaryColor),
                          onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designationCtrl,
                      decoration: InputDecoration(labelText: 'Designation', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactNoCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Contact No',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (val.length != 10) return 'Must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmittingEdit ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            ElevatedButton(
              onPressed: isSubmittingEdit ? null : () async {
                if (_editFormKey.currentState!.validate()) {
                  setDialogState(() => isSubmittingEdit = true);
                  try {
                    String photoUrl = existingPhotoUrl;
                    if (newImageFile != null) {
                      final storageRef = FirebaseStorage.instance
                          .ref()
                          .child('supervisor_photos')
                          .child('$documentId.jpg');
                      await storageRef.putFile(newImageFile!);
                      photoUrl = await storageRef.getDownloadURL();
                    }

                    final updatedData = {
                      'FullName': fullNameCtrl.text.trim(),
                      'UserName': userNameCtrl.text.trim(),
                      'Password': passwordCtrl.text.trim(),
                      'Designation': designationCtrl.text.trim(),
                      'ContactNo': contactNoCtrl.text.trim(),
                      'Email': emailCtrl.text.trim(),
                      'Photo': photoUrl.isNotEmpty ? photoUrl : 'Photo URL or Placeholder',
                    };

                    await FirestoreService.getCollection('supervisor')
                        .doc(documentId)
                        .update(updatedData);

                    Navigator.of(context).pop(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    setDialogState(() => isSubmittingEdit = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmittingEdit ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result == true) {
        if (mounted) {
          DialogUtils.showSuccessDialog(
            context,
            message: 'Supervisor updated successfully!',
          );
        }
        setState(() {}); // Refresh list
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

      String photoUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('supervisor_photos')
              .child('$documentId.jpg');
          
          await storageRef.putFile(_imageFile!);
          photoUrl = await storageRef.getDownloadURL();
        } catch (e) {
          print('Error uploading photo: $e');
        }
      }

      final supervisorData = {
        'SupervisorId': supervisorId,
        'FullName': _fullNameController.text.trim(),
        'UserName': username,
        'Password': _passwordController.text.trim(),
        'Designation': _designationController.text.trim(),
        'ContactNo': _contactNoController.text.trim(),
        'Email': _emailController.text.trim(),
        'Photo': photoUrl.isNotEmpty ? photoUrl : 'Photo URL or Placeholder',
        'CreatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection(
        'supervisor',
      ).doc(documentId).set(supervisorData);

      // Show success dialog
      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Your supervisor details have been saved successfully.',
        );
      }

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
            child: SingleChildScrollView(
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
    setState(() {
      _imageFile = null;
    });
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
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
    List<TextInputFormatter>? inputFormatters,
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
          inputFormatters: inputFormatters,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (label == 'Contact No' && value != null && value.isNotEmpty) {
              if (value.length != 10) {
                return 'Phone number must be 10 digits';
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
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
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imageFile == null
                ? Center(
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
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.cancel, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                      onPressed: () {
                        setState(() {
                          _imageFile = null;
                        });
                      },
                    ),
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
                      Icon(Icons.people, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Supervisors Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create your first supervisor account',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              final supervisors = data.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                itemCount: supervisors.length,
                itemBuilder: (context, index) {
                  final doc = supervisors[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final photoUrl = data['Photo'] ?? '';
                  final supervisorName = data['FullName'] ?? '';
                  final supervisorId = data['SupervisorId'] ?? '';
                  final password = data['Password'] ?? '';
                  final designation = data['Designation'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Photo
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withOpacity(0.1),
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      photoUrl.toString().isNotEmpty &&
                                          photoUrl != 'Photo URL or Placeholder'
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.person,
                                                    color: primaryColor,
                                                  ),
                                        )
                                      : Icon(Icons.person, color: primaryColor),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      supervisorName.isNotEmpty
                                          ? supervisorName
                                          : 'No Name',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (designation.isNotEmpty)
                                      Text(
                                        designation,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        supervisorId,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Action
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _editSupervisorInfo(
                                      doc.id,
                                      data,
                                    );
                                  },
                                  tooltip: 'Edit Info',
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1, thickness: 1),
                          ),
                          // Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Password:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                password,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Monospace',
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
