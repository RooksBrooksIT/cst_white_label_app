import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

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
          title: Text(
            'Edit Supervisor',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: _editFormKey,
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
                        height: 100,
                        width: 100,
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
                            ? Icon(Icons.add_a_photo, size: 40, color: primaryColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: userNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'User Name',
                        prefixIcon: Icon(Icons.account_circle),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
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
                      decoration: const InputDecoration(
                        labelText: 'Designation',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactNoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact No',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmittingEdit
                  ? null
                  : () async {
                      if (!_editFormKey.currentState!.validate()) return;
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Supervisor Account Created!\nID: $supervisorId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF0A183D),
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
    final Color darkCardBg = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Site Supervisor Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Dark Pill Mode Switcher ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                          color: _selectedTab == 0
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 16,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CREATE SUPERVISOR',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
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
                          color: _selectedTab == 1
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.supervisor_account_rounded,
                              size: 16,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SUPERVISORS INFO',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: _selectedTab == 1
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
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

            // ── Tab Content ─────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: _selectedTab == 0
                      ? _buildCreateForm(darkCardBg, primaryColor)
                      : _buildInfoTable(darkCardBg, primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CREATE TAB CONTENT ──────────────────────────────────────────────────
  Widget _buildCreateForm(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header Note
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Supervisor Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Please fill in all required fields (*)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

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

                  _buildPhotoUpload(primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildActionButtons(primaryColor),
            const SizedBox(height: 24),
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
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword ? !_isPasswordVisible : false,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Widget _buildPhotoUpload(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor Photo',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                style: BorderStyle.solid,
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
                          size: 36,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload Supervisor Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCBD5E1),
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
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
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

  Widget _buildActionButtons(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0A183D)),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_rounded,
                          size: 20,
                          color: Color(0xFF0A183D),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CREATE SUPERVISOR',
                          style: TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _resetForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

  // ── SUPERVISORS INFO TAB CONTENT ─────────────────────────────────────────
  Widget _buildInfoTable(Color darkCardBg, Color primaryColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: darkCardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirestoreService.getCollection('supervisor').get(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      '$count supervisors',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
              final data = snapshot.data;
              if (data == null || data.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Supervisors Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create your first supervisor account',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final supervisors = data.docs;
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                itemCount: supervisors.length,
                itemBuilder: (context, index) {
                  final doc = supervisors[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final photoUrl = data['Photo'] ?? '';
                  final supervisorName = data['FullName'] ?? '';
                  final supervisorId = data['SupervisorId'] ?? '';
                  final password = data['Password'] ?? '';
                  final designation = data['Designation'] ?? '';
                  final contactNo = data['ContactNo'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: darkCardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: darkCardBg.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withValues(alpha: 0.18),
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
                            const SizedBox(width: 14),

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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (designation.isNotEmpty)
                                    Text(
                                      designation,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      supervisorId,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Edit Action
                            IconButton(
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: Color(0xFF60A5FA),
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
                              const Icon(Icons.phone_rounded,
                                  size: 14, color: Color(0xFFCBD5E1)),
                              const SizedBox(width: 6),
                              Text(
                                contactNo,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Divider(
                            height: 1,
                            color: Color(0xFF334155),
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
                                  color: Color(0xFFCBD5E1),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Password:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              password,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Monospace',
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
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
