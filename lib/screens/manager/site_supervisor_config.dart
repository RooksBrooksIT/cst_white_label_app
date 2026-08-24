import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/subscription_limit_service.dart';

class SiteSupervisorConfig extends StatefulWidget {
  const SiteSupervisorConfig({super.key});
  @override
  State<SiteSupervisorConfig> createState() => _SiteSupervisorConfigState();
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

  int _supervisorInfoCurrentPage = 1;
  final int _supervisorInfoItemsPerPage = 10;
  String _supervisorSearchQuery = '';

  final ImagePicker _picker = ImagePicker();

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
  }

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

      bool isUsernameUnique = await _isUsernameUnique(username);
      if (!isUsernameUnique) {
        if (!mounted) return;
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

      bool isContactNoUnique = await _isContactNoUnique(contactNo);
      if (!isContactNoUnique) {
        if (!mounted) return;
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

      await _createSupervisorAccount();
    } catch (e) {
      if (!mounted) return;
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
    final editFormKey = GlobalKey<FormState>();
    TextEditingController fullNameCtrl = TextEditingController(
      text: currentData['FullName'] ?? '',
    );
    TextEditingController userNameCtrl = TextEditingController(
      text: currentData['UserName'] ?? '',
    );
    TextEditingController passwordCtrl = TextEditingController(
      text: currentData['Password'] ?? '',
    );
    TextEditingController designationCtrl = TextEditingController(
      text: currentData['Designation'] ?? '',
    );
    TextEditingController contactNoCtrl = TextEditingController(
      text: currentData['ContactNo'] ?? '',
    );
    TextEditingController emailCtrl = TextEditingController(
      text: currentData['Email'] ?? '',
    );

    bool isPasswordVisible = false;
    File? newImageFile;
    String existingPhotoUrl = currentData['Photo'] ?? '';
    bool isSubmittingEdit = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Supervisor',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        } catch (e) {}
                      },
                      child: Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.1),
                          border: Border.all(color: primaryColor, width: 2),
                          image: newImageFile != null
                              ? DecorationImage(
                                  image: FileImage(newImageFile!),
                                  fit: BoxFit.cover,
                                )
                              : existingPhotoUrl.isNotEmpty &&
                                      existingPhotoUrl != 'Photo URL or Placeholder'
                                  ? DecorationImage(
                                      image: NetworkImage(existingPhotoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (newImageFile == null &&
                                (existingPhotoUrl.isEmpty ||
                                    existingPhotoUrl == 'Photo URL or Placeholder'))
                            ? Icon(Icons.add_a_photo, size: 36, color: primaryColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: fullNameCtrl,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: userNameCtrl,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'User Name',
                        prefixIcon: Icon(Icons.account_circle, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: !isPasswordVisible,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designationCtrl,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Designation',
                        prefixIcon: Icon(Icons.work, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactNoCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Contact No',
                        prefixIcon: Icon(Icons.phone, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length != 10) return 'Must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmittingEdit ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSubmittingEdit
                  ? null
                  : () async {
                      if (!editFormKey.currentState!.validate()) return;
                      setDialogState(() => isSubmittingEdit = true);

                      try {
                        String photoUrl = existingPhotoUrl;
                        if (newImageFile != null) {
                          try {
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('supervisor_photos')
                                .child('${documentId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                            await storageRef.putFile(newImageFile!);
                            photoUrl = await storageRef.getDownloadURL();
                          } catch (e) {
                            debugPrint('Photo upload failed: $e');
                          }
                        }

                        await FirestoreService.getCollection('supervisor').doc(documentId).update({
                          'FullName': fullNameCtrl.text.trim(),
                          'UserName': userNameCtrl.text.trim(),
                          'Password': passwordCtrl.text.trim(),
                          'Designation': designationCtrl.text.trim(),
                          'ContactNo': contactNoCtrl.text.trim(),
                          'Email': emailCtrl.text.trim(),
                          'Photo': photoUrl,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Supervisor updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        setDialogState(() => isSubmittingEdit = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmittingEdit
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSupervisorAccount() async {
    try {
      // Validate active subscription supervisor limit
      final subValidation = await SubscriptionLimitService.canCreateSupervisor();
      if (!subValidation.isAllowed) {
        if (mounted) {
          await SubscriptionLimitService.showLimitReachedDialog(
            context,
            title: 'Supervisor Limit Reached',
            message: subValidation.errorMessage ??
                'You have reached your subscription plan limit for supervisors.',
          );
        }
        return;
      }

      final snapshot = await FirestoreService.getCollection('supervisor')
          .orderBy('SupervisorId', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;
      if (snapshot.docs.isNotEmpty) {
        final lastId = snapshot.docs.first['SupervisorId'] as String? ?? 'SUP000';
        final numberStr = lastId.replaceAll(RegExp(r'[^0-9]'), '');
        nextNumber = (int.tryParse(numberStr) ?? 0) + 1;
      }
      final newSupervisorId = 'SUP${nextNumber.toString().padLeft(3, '0')}';

      String photoUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('supervisor_photos')
              .child('${newSupervisorId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await storageRef.putFile(_imageFile!);
          photoUrl = await storageRef.getDownloadURL();
        } catch (e) {
          debugPrint('Storage upload error: $e');
        }
      }

      final supervisorData = {
        'SupervisorId': newSupervisorId,
        'FullName': _fullNameController.text.trim(),
        'UserName': _userNameController.text.trim(),
        'Password': _passwordController.text.trim(),
        'Designation': _designationController.text.trim(),
        'ContactNo': _contactNoController.text.trim(),
        'Email': _emailController.text.trim(),
        'Photo': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('supervisor')
          .doc(newSupervisorId)
          .set(supervisorData);

      if (mounted) {
        _showSuccessDialog(newSupervisorId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create supervisor account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog(String supervisorId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Lottie.asset(
                      'assets/animation/success.json',
                      width: 120,
                      height: 120,
                      repeat: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Supervisor Account Created!\nID: $supervisorId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _resetForm();
                      setState(() {
                        _selectedTab = 1;
                      });
                    },
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _designationController.clear();
    _contactNoController.clear();
    _emailController.clear();
    setState(() {
      _imageFile = null;
      _isPasswordVisible = false;
    });
  }

  @override
  void dispose() {
    _designationController.dispose();
    _fullNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Supervisor Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 16,
                              color: _selectedTab == 0 ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CREATE SUPERVISOR',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: _selectedTab == 0 ? Colors.white : const Color(0xFF0A183D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.supervisor_account_rounded,
                              size: 16,
                              color: _selectedTab == 1 ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SUPERVISORS INFO',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: _selectedTab == 1 ? Colors.white : const Color(0xFF0A183D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: _selectedTab == 0
                      ? _buildCreateForm()
                      : _buildInfoTable(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Create Supervisor Account',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please fill in all required fields (*)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    'Full Name',
                    _fullNameController,
                    isRequired: true,
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'User Name',
                    _userNameController,
                    isRequired: true,
                    icon: Icons.account_circle_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Password',
                    _passwordController,
                    isRequired: true,
                    isPassword: true,
                    icon: Icons.lock_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Designation',
                    _designationController,
                    isRequired: true,
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Contact No',
                    _contactNoController,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                    icon: Icons.phone_rounded,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Email',
                    _emailController,
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 16),

                  _buildPhotoUpload(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildActionButtons(),
            const SizedBox(height: 80),
          ],
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
    List<TextInputFormatter>? inputFormatters,
    IconData? icon,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword ? !_isPasswordVisible : false,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 20),
                    )
                  : null,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: brandIconColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return 'This field is required';
              }
              if (label == 'Contact No' &&
                  value != null &&
                  value.trim().isNotEmpty) {
                if (value.trim().length != 10) {
                  return 'Phone number must be 10 digits';
                }
              }
              if (label == 'Email' && value != null && value.trim().isNotEmpty) {
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor Photo',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
              ),
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imageFile == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 32,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Upload Supervisor Photo',
                          style: TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.red,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
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
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CREATE SUPERVISOR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _resetForm,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A183D),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0A183D)),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTable() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.badge_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Supervisors Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.getCollection('supervisor').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '$count supervisors',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Search Bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _supervisorSearchQuery = val;
                      _supervisorInfoCurrentPage = 1;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A183D),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search supervisors by name, ID, phone, designation...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    suffixIcon: _supervisorSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              setState(() {
                                _supervisorSearchQuery = '';
                                _supervisorInfoCurrentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getCollection('supervisor').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load supervisors: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFF0A183D)),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final data = (doc.data() as Map<String, dynamic>?) ?? {};
                final name = (data['FullName'] ?? '').toString().toLowerCase();
                final id = (data['SupervisorId'] ?? doc.id).toString().toLowerCase();
                final phone = (data['ContactNo'] ?? '').toString().toLowerCase();
                final desig = (data['Designation'] ?? '').toString().toLowerCase();

                final query = _supervisorSearchQuery.trim().toLowerCase();
                return query.isEmpty ||
                    name.contains(query) ||
                    id.contains(query) ||
                    phone.contains(query) ||
                    desig.contains(query);
              }).toList();

              final totalItems = filteredDocs.length;
              final totalPages = (totalItems / _supervisorInfoItemsPerPage).ceil().clamp(1, 999999);
              if (_supervisorInfoCurrentPage > totalPages) {
                _supervisorInfoCurrentPage = totalPages;
              }
              final startIndex = (totalItems == 0) ? 0 : (_supervisorInfoCurrentPage - 1) * _supervisorInfoItemsPerPage;
              final endIndex = (startIndex + _supervisorInfoItemsPerPage).clamp(0, totalItems);
              final paginatedDocs = filteredDocs.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching supervisors found',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                            itemCount: paginatedDocs.length,
                            itemBuilder: (context, index) {
                              final doc = paginatedDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final photoUrl = data['Photo'] ?? '';
                              final supervisorName = data['FullName'] ?? '';
                              final supervisorId = data['SupervisorId'] ?? '';
                              final password = data['Password'] ?? '';
                              final designation = data['Designation'] ?? '';
                              final contactNo = data['ContactNo'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: primaryColor.withValues(alpha: 0.12),
                                          ),
                                          child: ClipOval(
                                            child: photoUrl.toString().isNotEmpty &&
                                                    photoUrl != 'Photo URL or Placeholder'
                                                ? Image.network(
                                                    photoUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (context, error, stackTrace) => Icon(
                                                      Icons.person_rounded,
                                                      color: primaryColor,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person_rounded,
                                                    color: primaryColor,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                supervisorName.isNotEmpty
                                                    ? supervisorName
                                                    : 'No Name',
                                                style: const TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0A183D),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              if (designation.isNotEmpty)
                                                Text(
                                                  designation,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: Text(
                                                  supervisorId,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: primaryColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_rounded,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _editSupervisorInfo(doc.id, data);
                                          },
                                          tooltip: 'Edit Info',
                                        ),
                                      ],
                                    ),
                                    if (contactNo.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_rounded,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            contactNo,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF0A183D),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Divider(
                                        height: 1,
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    // Password Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Password:',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          password,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Monospace',
                                            color: Color(0xFF0A183D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Pagination Controls Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6),
                    child: _buildPaginationControls(
                      currentPage: _supervisorInfoCurrentPage,
                      totalPages: totalPages,
                      totalItems: totalItems,
                      itemsPerPage: _supervisorInfoItemsPerPage,
                      onPageChanged: (newPage) {
                        setState(() => _supervisorInfoCurrentPage = newPage);
                      },
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required Function(int) onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$startItem–$endItem of $totalItems',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.first_page_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
                tooltip: 'First Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.last_page_rounded,
                  size: 18,
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
                tooltip: 'Last Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
