import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/subscription_limit_service.dart';

class ManagerConfigScreen extends StatefulWidget {
  const ManagerConfigScreen({super.key});

  @override
  State<ManagerConfigScreen> createState() => _ManagerConfigScreenState();
}

class _ManagerConfigScreenState extends State<ManagerConfigScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _formKey = GlobalKey<FormState>();

  String? _selectedDesignation;
  String? _selectedDepartment;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<String> _designationList = [
    'Project Manager',
    'Site Manager',
    'Regional Manager',
    'General Manager',
    'Operations Manager',
  ];
  List<String> _departmentList = [
    'Operations',
    'Finance',
    'Execution',
    'Logistics',
    'Planning',
    'Engineering',
  ];

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

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

  // Directory Search & Filter
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive'
  int _currentPage = 1;
  final int _itemsPerPage = 8;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchConfigData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _currentPage = 1;
      });
    });
  }

  Future<void> _fetchConfigData() async {
    try {
      final desigSnapshot = await FirestoreService.getCollection(
        'managerDesignation',
      ).get();
      if (desigSnapshot.docs.isNotEmpty) {
        final fetchedDesigs = desigSnapshot.docs
            .map((doc) => doc['Designation'] as String)
            .where((d) => d.isNotEmpty)
            .toList();
        if (fetchedDesigs.isNotEmpty) {
          _designationList = fetchedDesigs;
        }
      }

      final deptSnapshot = await FirestoreService.getCollection(
        'managerDepartment',
      ).get();
      if (deptSnapshot.docs.isNotEmpty) {
        final fetchedDepts = deptSnapshot.docs
            .map((doc) => doc['Department'] as String)
            .where((d) => d.isNotEmpty)
            .toList();
        if (fetchedDepts.isNotEmpty) {
          _departmentList = fetchedDepts;
        }
      }
    } catch (e) {
      debugPrint('Error fetching config data: $e');
    }
  }

  // ── UNIQUENESS CHECKS AGAINST BACKEND/DATABASE ─────────────────────────

  Future<bool> _isUsernameUnique(String username, {String? excludeDocId}) async {
    if (username.trim().isEmpty) return true;
    try {
      final snapshot = await FirestoreService.getCollection('manager').get();
      final cleanInput = username.trim().toLowerCase();
      for (var doc in snapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final existing = (data['UserName'] ?? data['username'] ?? '').toString().trim().toLowerCase();
        if (existing.isNotEmpty && existing == cleanInput) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking username uniqueness: $e');
      return true;
    }
  }

  Future<bool> _isContactNoUnique(String contactNo, {String? excludeDocId}) async {
    if (contactNo.trim().isEmpty) return true;
    try {
      final snapshot = await FirestoreService.getCollection('manager').get();
      final cleanInput = contactNo.trim().replaceAll(RegExp(r'\D'), '');
      for (var doc in snapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final existing = (data['ContactNo'] ?? data['contactNo'] ?? data['phone'] ?? '').toString().trim().replaceAll(RegExp(r'\D'), '');
        if (existing.isNotEmpty && cleanInput.isNotEmpty && existing == cleanInput) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking contactNo uniqueness: $e');
      return true;
    }
  }

  Future<bool> _isEmailUnique(String email, {String? excludeDocId}) async {
    if (email.trim().isEmpty) return true;
    try {
      final snapshot = await FirestoreService.getCollection('manager').get();
      final cleanInput = email.trim().toLowerCase();
      for (var doc in snapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final existing = (data['Email'] ?? data['email'] ?? '').toString().trim().toLowerCase();
        if (existing.isNotEmpty && cleanInput.isNotEmpty && existing == cleanInput) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking email uniqueness: $e');
      return true;
    }
  }

  Future<bool> _isFullNameUnique(String fullName, {String? excludeDocId}) async {
    if (fullName.trim().isEmpty) return true;
    try {
      final snapshot = await FirestoreService.getCollection('manager').get();
      final cleanInput = fullName.trim().toLowerCase();
      for (var doc in snapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final existing = (data['FullName'] ?? data['fullName'] ?? data['name'] ?? '').toString().trim().toLowerCase();
        if (existing.isNotEmpty && existing == cleanInput) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking fullName uniqueness: $e');
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
          _usernameError = 'Username already exists. Please use a different name.';
        } else {
          _usernameError = null;
        }
      });
    });
  }

  void _onContactNoChanged(String value) {
    _contactNoDebounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingContactNo = false;
        _contactNoError = null;
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
          _contactNoError = 'Phone number already exists. Please use another phone number.';
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
          _emailError = 'Mail ID already exists. Please use another mail.';
        } else {
          _emailError = null;
        }
      });
    });
  }

  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    if (_fullNameError != null || _usernameError != null || _contactNoError != null || _emailError != null) {
      _showErrorSnackBar('Please resolve duplicate field errors before saving.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Validate active subscription manager limit
      final subValidation = await SubscriptionLimitService.canCreateManager();
      if (!subValidation.isAllowed) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          await SubscriptionLimitService.showLimitReachedDialog(
            context,
            title: 'Manager Limit Reached',
            message: subValidation.errorMessage ??
                'You have reached your subscription plan limit for managers.',
          );
        }
        return;
      }

      final fullName = _fullNameController.text.trim();
      final username = _userNameController.text.trim();
      final contactNo = _contactNoController.text.trim();
      final email = _emailController.text.trim();

      if (!(await _isFullNameUnique(fullName))) {
        setState(() => _fullNameError = 'Full name already exists. Please use a unique name.');
        _showErrorSnackBar('Full name "$fullName" already exists. Please use a unique name.');
        setState(() => _isSubmitting = false);
        return;
      }

      if (!(await _isUsernameUnique(username))) {
        setState(() => _usernameError = 'Username already exists. Please use a different name.');
        _showErrorSnackBar('Username "$username" already exists. Please use a different name.');
        setState(() => _isSubmitting = false);
        return;
      }

      if (!(await _isContactNoUnique(contactNo))) {
        setState(() => _contactNoError = 'Phone number already exists. Please use another phone number.');
        _showErrorSnackBar('Phone number "$contactNo" already exists. Please use another phone number.');
        setState(() => _isSubmitting = false);
        return;
      }

      if (email.isNotEmpty && !(await _isEmailUnique(email))) {
        setState(() => _emailError = 'Mail ID already exists. Please use another mail.');
        _showErrorSnackBar('Mail ID "$email" already exists. Please use another mail.');
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: Container(
          width: isDesktop ? 400 : 320,
          padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animation/success.json',
                width: isDesktop ? 120.0 : 100.0,
                height: isDesktop ? 120.0 : 100.0,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Account Created!',
                style: TextStyle(
                  fontSize: isDesktop ? 22.0 : 20.0,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A183D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manager details have been saved successfully to the system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _tabController?.animateTo(1); // Switch to Directory view
                  },
                  child: const Text(
                    'View Manager Directory',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _contactNoController.clear();
    _emailController.clear();
    setState(() {
      _selectedDesignation = null;
      _selectedDepartment = null;
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

  Future<void> _toggleManagerStatus(String docId, String currentStatus) async {
    final newStatus = (currentStatus == 'Active') ? 'Inactive' : 'Active';
    try {
      await FirestoreService.getCollection('manager').doc(docId).update({
        'Status': newStatus,
      });
      _showSuccessSnackBar('Manager status set to $newStatus');
    } catch (e) {
      _showErrorSnackBar('Failed to update status: $e');
    }
  }

  Future<void> _confirmDeleteManager(String docId, String managerName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text('Delete Account'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete manager account "$managerName"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService.getCollection('manager').doc(docId).delete();
                _showSuccessSnackBar('Manager account deleted successfully.');
              } catch (e) {
                _showErrorSnackBar('Failed to delete manager: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditManagerModal(Map<String, dynamic> data, String docId) {
    final editFullNameController = TextEditingController(text: data['FullName'] ?? '');
    final editContactNoController = TextEditingController(text: data['ContactNo'] ?? '');
    final editEmailController = TextEditingController(text: data['Email'] ?? '');
    String? editDesignation = data['Designation'];
    String? editDepartment = data['Department'];
    String editStatus = data['Status'] ?? 'Active';
    final editFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: editFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Manager Profile',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${data['ManagerId'] ?? docId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 24),
                      
                      // Full Name
                      _buildModalFieldLabel('Full Name *'),
                      TextFormField(
                        controller: editFullNameController,
                        style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        decoration: _getInputDecoration('Full Name', Icons.person),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Designation
                      _buildModalFieldLabel('Designation *'),
                      DropdownButtonFormField<String>(
                        initialValue: _designationList.contains(editDesignation) ? editDesignation : null,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        decoration: _getInputDecoration('Select Designation', Icons.badge),
                        items: _designationList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setModalState(() => editDesignation = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Department
                      _buildModalFieldLabel('Department *'),
                      DropdownButtonFormField<String>(
                        initialValue: _departmentList.contains(editDepartment) ? editDepartment : null,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        decoration: _getInputDecoration('Select Department', Icons.business),
                        items: _departmentList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setModalState(() => editDepartment = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Contact No
                      _buildModalFieldLabel('Contact Number *'),
                      TextFormField(
                        controller: editContactNoController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        decoration: _getInputDecoration('Contact Number', Icons.phone),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _buildModalFieldLabel('Email Address'),
                      TextFormField(
                        controller: editEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        decoration: _getInputDecoration('Email Address', Icons.email),
                      ),
                      const SizedBox(height: 14),

                      // Status Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Account Status',
                            style: TextStyle(
                              color: Color(0xFF0A183D),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: editStatus == 'Active'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  editStatus,
                                  style: TextStyle(
                                    color: editStatus == 'Active'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Switch(
                                  value: editStatus == 'Active',
                                  activeTrackColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setModalState(() {
                                      editStatus = val ? 'Active' : 'Inactive';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!editFormKey.currentState!.validate()) return;
                                  setModalState(() => isSaving = true);
                                  try {
                                    final editContact = editContactNoController.text.trim();
                                    final editEmail = editEmailController.text.trim();
                                    final editName = editFullNameController.text.trim();

                                    if (editName.isNotEmpty && !(await _isFullNameUnique(editName, excludeDocId: docId))) {
                                      setModalState(() => isSaving = false);
                                      _showErrorSnackBar('Full name "$editName" already exists. Please use a unique name.');
                                      return;
                                    }

                                    if (!(await _isContactNoUnique(editContact, excludeDocId: docId))) {
                                      setModalState(() => isSaving = false);
                                      _showErrorSnackBar('Phone number "$editContact" already exists. Please use another phone number.');
                                      return;
                                    }

                                    if (editEmail.isNotEmpty && !(await _isEmailUnique(editEmail, excludeDocId: docId))) {
                                      setModalState(() => isSaving = false);
                                      _showErrorSnackBar('Mail ID "$editEmail" already exists. Please use another mail.');
                                      return;
                                    }

                                    await FirestoreService.getCollection('manager').doc(docId).update({
                                      'FullName': editName,
                                      'Designation': editDesignation,
                                      'Department': editDepartment,
                                      'ContactNo': editContact,
                                      'Email': editEmail,
                                      'Status': editStatus,
                                    });
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _showSuccessSnackBar('Manager profile updated successfully.');
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    _showErrorSnackBar('Failed to update manager: $e');
                                  }
                                },
                          child: isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
        },
      ),
    );
  }

  Widget _buildModalFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  @override
  void dispose() {
    _usernameDebounceTimer?.cancel();
    _contactNoDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _fullNameDebounceTimer?.cancel();
    _tabController?.dispose();
    _fullNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manager Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.getDarkAccent(primaryColor),
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  AppTheme.getDarkAccent(primaryColor),
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'New Setup'),
            Tab(text: 'Manager Directory'),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 960.0 : (isTablet ? 720.0 : double.infinity),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateForm(isDesktop, isTablet, isMobile),
                _buildInfoTable(isDesktop, isTablet, isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── METRICS OVERVIEW ───────────────────────────────────────────────────────
  Widget _buildMetricsOverview(bool isDesktop, bool isTablet, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('manager').snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        int active = 0;
        Set<String> depts = {};

        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['Status'] == 'Active') active++;
            if (data['Department'] != null && data['Department'].toString().isNotEmpty) {
              depts.add(data['Department'].toString());
            }
          }
        }

        return Row(
          children: [
            _buildMetricTile(
              title: 'Total Managers',
              value: '$total',
              icon: Icons.people_alt_rounded,
              iconColor: primaryColor,
              isDesktop: isDesktop,
            ),
            const SizedBox(width: 10),
            _buildMetricTile(
              title: 'Active Accounts',
              value: '$active',
              icon: Icons.verified_user_rounded,
              iconColor: const Color(0xFF10B981),
              isDesktop: isDesktop,
            ),
            const SizedBox(width: 10),
            _buildMetricTile(
              title: 'Departments',
              value: '${depts.length}',
              icon: Icons.business_rounded,
              iconColor: const Color(0xFFF59E0B),
              isDesktop: isDesktop,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDesktop,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 14.0 : 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
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
            Container(
              padding: EdgeInsets.all(isDesktop ? 10.0 : 8.0),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isDesktop ? 22.0 : 18.0,
              ),
            ),
            SizedBox(width: isDesktop ? 10.0 : 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isDesktop ? 20.0 : 17.0,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A183D),
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isDesktop ? 11.5 : 10.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CREATE FORM ───────────────────────────────────────────────────────────
  Widget _buildCreateForm(bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28.0 : 16.0),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Metrics Row
            _buildMetricsOverview(isDesktop, isTablet, isMobile),
            const SizedBox(height: 20),

            // SECTION 1: ACCOUNT CREDENTIALS
            _buildSectionHeader(
              title: '1. Account Credentials',
              subtitle: 'Basic login, full name & password credentials',
              icon: Icons.person_rounded,
              color: primaryColor,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Full Name *',
              controller: _fullNameController,
              isRequired: true,
              icon: Icons.person_outline_rounded,
              hint: 'e.g. John Doe',
              isDesktop: isDesktop,
              onChanged: _onFullNameChanged,
              isChecking: _isCheckingFullName,
              checkingText: 'Checking name availability...',
              errorText: _fullNameError,
              successText: 'Full name is available ✓',
            ),
            SizedBox(height: isDesktop ? 16.0 : 14.0),
            _buildTextField(
              label: 'User Name *',
              controller: _userNameController,
              isRequired: true,
              icon: Icons.alternate_email_rounded,
              hint: 'e.g. johndoe01',
              isDesktop: isDesktop,
              onChanged: _onUsernameChanged,
              isChecking: _isCheckingUsername,
              checkingText: 'Checking username...',
              errorText: _usernameError,
              successText: 'Username is available ✓',
            ),
            SizedBox(height: isDesktop ? 16.0 : 14.0),
            _buildTextField(
              label: 'Password *',
              controller: _passwordController,
              isRequired: true,
              isPassword: true,
              icon: Icons.lock_outline_rounded,
              hint: 'Enter secure password',
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            
            // SECTION 2: ROLE & ORGANIZATIONAL UNIT
            _buildSectionHeader(
              title: '2. Role & Organizational Unit',
              subtitle: 'Designation role & department assignment',
              icon: Icons.badge_rounded,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Designation *',
              value: _selectedDesignation,
              items: _designationList,
              onChanged: (val) => setState(() => _selectedDesignation = val),
              icon: Icons.work_outline_rounded,
              isDesktop: isDesktop,
            ),
            SizedBox(height: isDesktop ? 16.0 : 14.0),
            _buildDropdown(
              label: 'Department *',
              value: _selectedDepartment,
              items: _departmentList,
              onChanged: (val) => setState(() => _selectedDepartment = val),
              icon: Icons.business_outlined,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // SECTION 3: CONTACT INFORMATION
            _buildSectionHeader(
              title: '3. Contact Information',
              subtitle: 'Phone & email communication details',
              icon: Icons.contact_phone_rounded,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Contact No *',
              controller: _contactNoController,
              isRequired: true,
              keyboardType: TextInputType.phone,
              icon: Icons.phone_android_rounded,
              hint: 'e.g. 9876543210',
              isDesktop: isDesktop,
              onChanged: _onContactNoChanged,
              isChecking: _isCheckingContactNo,
              checkingText: 'Checking phone number...',
              errorText: _contactNoError,
              successText: 'Phone number is available ✓',
            ),
            SizedBox(height: isDesktop ? 16.0 : 14.0),
            _buildTextField(
              label: 'Email Address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_outlined,
              hint: 'e.g. manager@company.com',
              isDesktop: isDesktop,
              onChanged: _onEmailChanged,
              isChecking: _isCheckingEmail,
              checkingText: 'Checking email...',
              errorText: _emailError,
              successText: 'Mail ID is available ✓',
            ),
            SizedBox(height: isDesktop ? 28.0 : 22.0),
            _buildActionButtons(isDesktop, isTablet, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    IconData? icon,
    String? hint,
    required bool isDesktop,
    ValueChanged<String>? onChanged,
    bool isChecking = false,
    String checkingText = 'Checking availability...',
    String? errorText,
    String? successText,
  }) {
    final hasValue = controller.text.trim().isNotEmpty;
    final hasError = errorText != null && errorText.isNotEmpty;
    final isSuccess = hasValue && !isChecking && !hasError && successText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: hasError
                  ? const Color(0xFFDC2626)
                  : (isSuccess ? const Color(0xFF16A34A) : primaryColor),
              size: 20.0,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  )
                : (isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
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
                        ? const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20)
                        : (isSuccess
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                            : null))),
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : (isSuccess ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                width: (hasError || isSuccess) ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFDC2626) : primaryColor,
                width: 1.8,
              ),
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return '$label is required';
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
                  const Icon(
                    Icons.cancel_rounded,
                    size: 13,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isSuccess) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Color(0xFF16A34A),
                  ),
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: primaryColor,
              size: 20.0,
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Select $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
          validator: (val) => val == null ? 'Please select $label' : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDesktop, bool isTablet, bool isMobile) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: primaryColor.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22.0,
                      width: 22.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_add_alt_1_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _resetForm,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A183D),
                side: const BorderSide(
                  color: Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MANAGER DIRECTORY ─────────────────────────────────────────────────────
  Widget _buildInfoTable(bool isDesktop, bool isTablet, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 14.0,
      ),
      child: Column(
        children: [
          // Search Input Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.0, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, username, phone or email...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.0),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status Filter Chips
          Row(
            children: [
              const Text(
                'Status:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip('All', _statusFilter == 'All', () {
                setState(() {
                  _statusFilter = 'All';
                  _currentPage = 1;
                });
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Active', _statusFilter == 'Active', () {
                setState(() {
                  _statusFilter = 'Active';
                  _currentPage = 1;
                });
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Inactive', _statusFilter == 'Inactive', () {
                setState(() {
                  _statusFilter = 'Inactive';
                  _currentPage = 1;
                });
              }),
            ],
          ),
          const SizedBox(height: 12),

          // List View of Managers
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.getCollection('manager').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading managers: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFF0A183D)),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var docs = snapshot.data!.docs;

                // Filter by Search Query & Status
                var filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['FullName'] ?? '').toString().toLowerCase();
                  final managerId = (data['ManagerId'] ?? '').toString().toLowerCase();
                  final userName = (data['UserName'] ?? '').toString().toLowerCase();
                  final designation = (data['Designation'] ?? '').toString().toLowerCase();
                  final department = (data['Department'] ?? '').toString().toLowerCase();
                  final contact = (data['ContactNo'] ?? '').toString().toLowerCase();
                  final email = (data['Email'] ?? '').toString().toLowerCase();
                  final status = (data['Status'] ?? 'Active').toString();

                  final matchesSearch = _searchQuery.isEmpty ||
                      fullName.contains(_searchQuery) ||
                      managerId.contains(_searchQuery) ||
                      userName.contains(_searchQuery) ||
                      designation.contains(_searchQuery) ||
                      department.contains(_searchQuery) ||
                      contact.contains(_searchQuery) ||
                      email.contains(_searchQuery);

                  final matchesStatus = _statusFilter == 'All' || status == _statusFilter;

                  return matchesSearch && matchesStatus;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No managers matching "$_searchQuery"'
                              : 'No managers found in system.',
                          style: const TextStyle(
                            fontSize: 15.0,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Pagination Calculations
                final totalItems = filteredDocs.length;
                final totalPages = (totalItems / _itemsPerPage).ceil();
                if (_currentPage > totalPages && totalPages > 0) {
                  _currentPage = totalPages;
                }
                final startIndex = (_currentPage - 1) * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
                final pageDocs = filteredDocs.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: pageDocs.length,
                        itemBuilder: (context, index) {
                          final doc = pageDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildManagerCard(data, doc.id, isDesktop);
                        },
                      ),
                    ),
                    // Pagination Footer
                    _buildPaginationFooter(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      totalItems: totalItems,
                      itemsPerPage: _itemsPerPage,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : const Color(0xFFCBD5E1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF0A183D),
          ),
        ),
      ),
    );
  }

  Widget _buildManagerCard(
    Map<String, dynamic> data,
    String docId,
    bool isDesktop,
  ) {
    final fullName = data['FullName'] ?? 'Unnamed Manager';
    final designation = data['Designation'] ?? 'Unassigned';
    final department = data['Department'] ?? 'General';
    final contactNo = data['ContactNo'] ?? 'No Contact';
    final email = data['Email'] ?? '';
    final status = data['Status'] ?? 'Active';
    final managerId = data['ManagerId'] ?? docId;

    // Get Initials for Avatar
    String initials = 'MG';
    final nameParts = fullName.trim().split(RegExp(r'\s+'));
    if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      if (nameParts.length > 1 && nameParts.last.isNotEmpty) {
        initials = '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
      } else {
        initials = nameParts.first[0].toUpperCase();
      }
    }

    final isActive = status == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Avatar Circle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Main Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            fontSize: 15.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ID Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.getDarkAccent(primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          managerId,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Designation & Department pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildMiniBadge(designation, Icons.badge_outlined, const Color(0xFF2563EB)),
                      _buildMiniBadge(department, Icons.business_outlined, const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Contact details
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        contactNo,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.email_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Action Buttons Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status Switch Toggle
                GestureDetector(
                  onTap: () => _toggleManagerStatus(docId, status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Edit & Delete Icons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _showEditManagerModal(data, docId),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _confirmDeleteManager(docId, fullName),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGINATION FOOTER ─────────────────────────────────────────────────────
  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required bool isDesktop,
    required bool isTablet,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage).clamp(1, totalItems);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
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
            child: Text(
              'Showing $startItem–$endItem of $totalItems managers',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            icon: Icon(
              Icons.first_page_rounded,
              size: 20,
              color: currentPage > 1 ? const Color(0xFF0A183D) : Colors.grey.shade300,
            ),
            onPressed: currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
            tooltip: 'First Page',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: currentPage > 1 ? const Color(0xFF0A183D) : Colors.grey.shade300,
            ),
            onPressed: currentPage > 1 ? () => setState(() => _currentPage--) : null,
            tooltip: 'Previous Page',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppTheme.getDarkAccent(primaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$currentPage / ${totalPages == 0 ? 1 : totalPages}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: currentPage < totalPages ? const Color(0xFF0A183D) : Colors.grey.shade300,
            ),
            onPressed: currentPage < totalPages ? () => setState(() => _currentPage++) : null,
            tooltip: 'Next Page',
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            icon: Icon(
              Icons.last_page_rounded,
              size: 20,
              color: currentPage < totalPages ? const Color(0xFF0A183D) : Colors.grey.shade300,
            ),
            onPressed: currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
            tooltip: 'Last Page',
          ),
        ],
      ),
    );
  }
}
