import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/notification_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/services/subscription_limit_service.dart';

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

  // Real-time debounced validation states
  Timer? _usernameDebounceTimer;
  Timer? _contactNoDebounceTimer;
  Timer? _emailDebounceTimer;
  Timer? _fullNameDebounceTimer;

  bool _isCheckingUsername = false;
  String? _usernameError;

  bool _isCheckingContactNo = false;
  String? _contactNoError;

  bool _isCheckingEmail = false;
  String? _emailError;

  bool _isCheckingFullName = false;
  String? _fullNameError;

  int _supervisorInfoCurrentPage = 1;
  final int _supervisorInfoItemsPerPage = 10;
  String _supervisorSearchQuery = '';

  final ImagePicker _picker = ImagePicker();

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
  }

  // ── UNIQUENESS CHECKS AGAINST BACKEND/DATABASE ─────────────────────────

  Future<bool> _isUsernameUnique(String username, {String? excludeDocId}) async {
    if (username.trim().isEmpty) return true;
    return await FirestoreService.isGlobalSupervisorUsernameUnique(
      username,
      excludeDocId: excludeDocId,
    );
  }

  Future<bool> _isContactNoUnique(String contactNo, {String? excludeDocId}) async {
    if (contactNo.trim().isEmpty) return true;
    return await FirestoreService.isGlobalPhoneUnique(
      contactNo,
      excludeDocId: excludeDocId,
    );
  }

  Future<bool> _isEmailUnique(String email, {String? excludeDocId}) async {
    if (email.trim().isEmpty) return true;
    return await FirestoreService.isGlobalEmailUnique(
      email,
      excludeDocId: excludeDocId,
    );
  }

  Future<bool> _isFullNameUnique(String fullName, {String? excludeDocId}) async {
    final cleanInput = fullName.trim().toLowerCase();
    if (cleanInput.isEmpty) return true;
    try {
      final snapshot = await FirestoreService.getCollection('supervisor').get();
      for (var doc in snapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final existing = (data['FullName'] ?? data['fullName'] ?? data['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (existing.isNotEmpty && existing == cleanInput) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking supervisor fullName uniqueness: $e');
      return true;
    }
  }

  // ── REAL-TIME DEBOUNCED INPUT HANDLERS ─────────────────────────────────

  void _onFullNameChanged(String value) {
    _fullNameDebounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingFullName = false;
        _fullNameError = null;
      });
      return;
    }

    setState(() {
      _isCheckingFullName = true;
      _fullNameError = null;
    });

    _fullNameDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final isUnique = await _isFullNameUnique(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingFullName = false;
        if (!isUnique) {
          _fullNameError = 'Full name already exists. Please use a unique name.';
        } else {
          _fullNameError = null;
        }
      });
    });
  }

  void _onUsernameChanged(String value) {
    _usernameDebounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _usernameError = null;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final isUnique = await _isUsernameUnique(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        if (!isUnique) {
          _usernameError = 'Username already exists. Please choose another username.';
        } else {
          _usernameError = null;
        }
      });
    });
  }

  void _onContactNoChanged(String value) {
    _contactNoDebounceTimer?.cancel();
    final trimmed = value.trim().replaceAll(RegExp(r'\D'), '');
    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingContactNo = false;
        _contactNoError = null;
      });
      return;
    }

    if (trimmed.length != 10) {
      setState(() {
        _isCheckingContactNo = false;
        _contactNoError = 'Phone number must be exactly 10 digits';
      });
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
      setState(() {
        _isCheckingContactNo = false;
        _contactNoError = 'Enter a valid 10-digit phone number (starts with 6-9)';
      });
      return;
    }

    setState(() {
      _isCheckingContactNo = true;
      _contactNoError = null;
    });

    _contactNoDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final isUnique = await _isContactNoUnique(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingContactNo = false;
        if (!isUnique) {
          _contactNoError = 'Phone number already registered. Please use another number.';
        } else {
          _contactNoError = null;
        }
      });
    });
  }

  void _onEmailChanged(String value) {
    _emailDebounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingEmail = false;
        _emailError = null;
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmed)) {
      setState(() {
        _isCheckingEmail = false;
        _emailError = 'Enter a valid email address (e.g. name@domain.com)';
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });

    _emailDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final isUnique = await _isEmailUnique(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        if (!isUnique) {
          _emailError = 'Email address already registered. Please use another email address.';
        } else {
          _emailError = null;
        }
      });
    });
  }

  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting) return;

    if (_fullNameError != null ||
        _usernameError != null ||
        _contactNoError != null ||
        _emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please resolve duplicate or invalid field errors before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fullName = _fullNameController.text.trim();
      final username = _userNameController.text.trim();
      final contactNo = _contactNoController.text.trim().replaceAll(RegExp(r'\D'), '');
      final email = _emailController.text.trim();

      if (contactNo.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(contactNo)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 10-digit phone number (starts with 6-9).'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (email.isNotEmpty && !RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address (e.g. name@domain.com).'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      bool isFullNameUniqueVal = await _isFullNameUnique(fullName);
      if (!isFullNameUniqueVal) {
        if (!mounted) return;
        setState(() => _fullNameError = 'Full name already exists. Please use a unique name.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Full name "$fullName" already exists. Please use a unique name.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      bool isUsernameUniqueVal = await _isUsernameUnique(username);
      if (!isUsernameUniqueVal) {
        if (!mounted) return;
        setState(() => _usernameError = 'Username already exists. Please choose another username.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Username already exists. Please choose another username.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      bool isContactNoUniqueVal = await _isContactNoUnique(contactNo);
      if (!isContactNoUniqueVal) {
        if (!mounted) return;
        setState(() => _contactNoError = 'Phone number already registered. Please use another number.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone number already registered. Please use another number.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      if (email.isNotEmpty) {
        bool isEmailUniqueVal = await _isEmailUnique(email);
        if (!isEmailUniqueVal) {
          if (!mounted) return;
          setState(() => _emailError = 'Email address already registered. Please use another email address.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email address already registered. Please use another email address.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
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
                        } catch (e) {
                          debugPrint('Error picking supervisor photo: $e');
                        }
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
                    _buildDialogField(
                      label: 'Full Name *',
                      child: TextFormField(
                        controller: fullNameCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration('Full Name', Icons.person_rounded),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      label: 'User Name *',
                      child: TextFormField(
                        controller: userNameCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration('User Name', Icons.account_circle_rounded),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      label: 'Password *',
                      child: TextFormField(
                        controller: passwordCtrl,
                        obscureText: !isPasswordVisible,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration(
                          'Password',
                          Icons.lock_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: primaryColor,
                              size: 18,
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
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      label: 'Designation *',
                      child: TextFormField(
                        controller: designationCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration('Designation', Icons.badge_rounded),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      label: 'Contact No *',
                      child: TextFormField(
                        controller: contactNoCtrl,
                        keyboardType: TextInputType.phone,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration('Contact No', Icons.phone_rounded),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Contact number is required';
                          final clean = v.trim().replaceAll(RegExp(r'\D'), '');
                          if (clean.length != 10) return 'Phone number must be exactly 10 digits';
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                            return 'Enter a valid 10-digit phone number (starts with 6-9)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      label: 'Email (Optional)',
                      child: TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: _buildDialogInputDecoration('Email (Optional)', Icons.email_rounded),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                              return 'Enter a valid email address (e.g. name@domain.com)';
                            }
                          }
                          return null;
                        },
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
                        final editUsername = userNameCtrl.text.trim();
                        final editContactNo = contactNoCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
                        final editEmail = emailCtrl.text.trim();

                        if (editContactNo.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(editContactNo)) {
                          setDialogState(() => isSubmittingEdit = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid 10-digit phone number (starts with 6-9).'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (editEmail.isNotEmpty && !RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(editEmail)) {
                          setDialogState(() => isSubmittingEdit = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email address (e.g. name@domain.com).'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!(await _isUsernameUnique(editUsername, excludeDocId: documentId))) {
                          setDialogState(() => isSubmittingEdit = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Username already exists. Please choose another username.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!(await _isContactNoUnique(editContactNo, excludeDocId: documentId))) {
                          setDialogState(() => isSubmittingEdit = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Phone number already registered. Please use another number.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (editEmail.isNotEmpty && !(await _isEmailUnique(editEmail, excludeDocId: documentId))) {
                          setDialogState(() => isSubmittingEdit = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email address already registered. Please use another email address.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

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
                          'UserName': editUsername,
                          'Password': passwordCtrl.text.trim(),
                          'Designation': designationCtrl.text.trim(),
                          'ContactNo': editContactNo,
                          'Email': editEmail,
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

      // Trigger real-time push and in-app notification for Supervisor creation
      try {
        await NotificationService.notifySupervisorAccountCreated(
          supervisorName: _fullNameController.text.trim(),
          supervisorId: newSupervisorId,
          username: _userNameController.text.trim(),
          designation: _designationController.text.trim(),
        );
      } catch (notifErr) {
        debugPrint('Error triggering supervisor creation notification: $notifErr');
      }

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
    _usernameDebounceTimer?.cancel();
    _contactNoDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _fullNameDebounceTimer?.cancel();
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
      _usernameError = null;
      _contactNoError = null;
      _emailError = null;
      _fullNameError = null;
      _isCheckingUsername = false;
      _isCheckingContactNo = false;
      _isCheckingEmail = false;
      _isCheckingFullName = false;
    });
  }

  @override
  void dispose() {
    _usernameDebounceTimer?.cancel();
    _contactNoDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _fullNameDebounceTimer?.cancel();
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
                    onChanged: _onFullNameChanged,
                    isChecking: _isCheckingFullName,
                    checkingText: 'Checking name availability...',
                    errorText: _fullNameError,
                    successText: 'Full name is available ✓',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'User Name',
                    _userNameController,
                    isRequired: true,
                    icon: Icons.account_circle_rounded,
                    onChanged: _onUsernameChanged,
                    isChecking: _isCheckingUsername,
                    checkingText: 'Checking username...',
                    errorText: _usernameError,
                    successText: 'Username is available ✓',
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
                    onChanged: _onContactNoChanged,
                    isChecking: _isCheckingContactNo,
                    checkingText: 'Checking phone number...',
                    errorText: _contactNoError,
                    successText: 'Phone number is available ✓',
                    customValidator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Contact number is required';
                      }
                      final clean = val.trim();
                      if (clean.length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                        return 'Enter a valid 10-digit phone number (starts with 6-9)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Email',
                    _emailController,
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_rounded,
                    onChanged: _onEmailChanged,
                    isChecking: _isCheckingEmail,
                    checkingText: 'Checking email...',
                    errorText: _emailError,
                    successText: 'Mail ID is available ✓',
                    customValidator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final clean = val.trim();
                        if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) {
                          return 'Enter a valid email address (e.g. name@domain.com)';
                        }
                      }
                      return null;
                    },
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

  Widget _buildDialogField({required String label, required Widget child}) {
    final isRequired = label.contains('*');
    final cleanText = label.replaceAll('*', '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              text: cleanText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A183D),
                letterSpacing: -0.1,
              ),
              children: isRequired
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        child,
      ],
    );
  }

  InputDecoration _buildDialogInputDecoration(
    String hintText,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: primaryColor, size: 18),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
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
    ValueChanged<String>? onChanged,
    bool isChecking = false,
    String checkingText = 'Checking availability...',
    String? errorText,
    String? successText,
    String? Function(String?)? customValidator,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
    final hasValue = controller.text.trim().isNotEmpty;
    final hasError = errorText != null && errorText.isNotEmpty;
    final isSuccess = hasValue && !isChecking && !hasError && successText != null;

    final activeBorderColor = hasError
        ? const Color(0xFFEF4444)
        : (isSuccess ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A183D),
                letterSpacing: -0.1,
              ),
              children: isRequired
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !_isPasswordVisible : false,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      icon,
                      color: hasError
                          ? const Color(0xFFEF4444)
                          : (isSuccess ? const Color(0xFF16A34A) : brandIconColor),
                      size: 18,
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: brandIconColor,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : (isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(11.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : (hasError
                        ? const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18)
                        : (isSuccess
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18)
                            : null))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12.5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: activeBorderColor,
                width: (hasError || isSuccess) ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFEF4444) : brandIconColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            if (customValidator != null) {
              final customErr = customValidator(value);
              if (customErr != null) return customErr;
            }
            if (errorText != null) {
              return errorText;
            }
            return null;
          },
        ),
        if (hasValue && (isChecking || hasError || isSuccess))
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                if (isChecking) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    checkingText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (hasError) ...[
                  const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isSuccess) ...[
                  const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    successText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
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
            fontSize: 13,
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
              TextField(
                onChanged: (val) {
                  setState(() {
                    _supervisorSearchQuery = val;
                    _supervisorInfoCurrentPage = 1;
                  });
                },
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A183D),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search supervisors by name, ID, phone, designation...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
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
